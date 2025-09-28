package com.reactnativesharedelement.video

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.util.AttributeSet
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.annotation.OptIn
import androidx.core.view.ViewCompat
import androidx.media3.common.*
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import com.facebook.react.bridge.ReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.views.view.ReactViewGroup
import com.reactnativesharedelement.video.helpers.*
import com.shareelement.video.helpers.RCTVideoOverlay
import kotlin.math.max

import java.net.URL
import kotlin.math.roundToInt

class RCTVideoView : FrameLayout {

    // ===== UI =====
    internal lateinit var playerView: PlayerView
    private lateinit var posterView: ImageView
    private val videoPoster = FrameLayout(context)
    val videoContainer: ReactViewGroup = ReactViewGroup(context).apply {
        clipChildren = true
        setBackgroundColor(android.graphics.Color.TRANSPARENT)
    }
    private var overlay: RCTVideoOverlay? = null
    private var otherView: RCTVideoView? = null

    // ===== Player =====
    internal var player: ExoPlayer? = null
    private var videoW = 0
    private var videoH = 0
    private var isLooping = false
    private var isSharing = false
    private var currentSource: String? = null

    // ===== State =====
    private var posterResizeMode: String = "cover"
    private var posterBitmap: Bitmap? = null
    private var isBlurWindow = false
    private var isFullscreen = false
    private var externallyPaused = false
    internal var resizeModeStr: String = "contain"
        private set
    private var isMuted = false
    private var rememberedVolume = 1f

    // ===== Events / Tickers =====
    private var lastIsBuffering: Boolean? = null
    private var progressIntervalMs = 250L
    private var isProgressEnabled = false
    private var isOnLoadEnabled = false
    private var didEmitLoadStartForCurrentItem = false
    private var shareTagElement: String? = null

    private var fullscreenDialog: FullscreenVideoDialog? = null

    private val tickers by lazy {
        RCTVideoTickers(
            hostView = this,
            getReactContext = { context as? ReactContext },
            getViewId = { id },
            getPlayer = { player },
            getIntervalMs = { progressIntervalMs },
            isProgressEnabled = { isProgressEnabled },
            isOnLoadEnabled = { isOnLoadEnabled }
        )
    }

    // ===== Constructors =====
    constructor(context: Context) : super(context) { configure() }
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) { configure() }
    constructor(context: Context, attrs: AttributeSet?, defStyleAttr: Int) :
            super(context, attrs, defStyleAttr) { configure() }

    // ===== Init =====
    @OptIn(UnstableApi::class)
    private fun configure() {
        clipChildren = true
        alpha = 0f
        setBackgroundColor(android.graphics.Color.BLACK)
        playerView = PlayerView(context, null, 0).apply {
            useController = false
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            setShutterBackgroundColor(android.graphics.Color.TRANSPARENT)
        }
        posterView = ImageView(context).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            visibility = GONE
            isClickable = false
            isFocusable = false
        }

        videoPoster.addView(playerView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        videoPoster.addView(posterView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))

        addView(videoPoster, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        addView(videoContainer, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))

        player = buildPlayer().also {
            playerView.player = it
            attachListeners(it)
        }
    }

    @OptIn(UnstableApi::class)
    private fun buildPlayer(): ExoPlayer {
        val upstream = OkHttpDataSource.Factory(HttpStack.get(context))
        return ExoPlayer.Builder(context)
            .setMediaSourceFactory(DefaultMediaSourceFactory(upstream))
            .build()
    }

    private fun attachListeners(p: ExoPlayer) {
        p.addListener(object : Player.Listener {
            override fun onVideoSizeChanged(size: VideoSize) {
                val w = size.width
                val h = (size.height * size.pixelWidthHeightRatio).roundToInt().coerceAtLeast(1)
                if (w > 0 && h > 0) {
                    videoW = w
                    videoH = h
                    applyAspectNow()
                }
            }

            override fun onPlaybackStateChanged(state: Int) {
                when (state) {
                    Player.STATE_BUFFERING -> maybeDispatchBuffering(true)
                    Player.STATE_READY -> {
                        maybeDispatchBuffering(false)
                        maybeEmitOnLoadStartOnce()
                        tickers.startProgressIfNeeded()
                        tickers.startOnLoadIfNeeded()
                    }
                    Player.STATE_ENDED -> {
                        dispatchEnd()
                        maybeDispatchBuffering(false)
                        if (isLooping) {
                            p.seekTo(0)
                            p.playWhenReady = !externallyPaused
                        } else {
                            tickers.stopProgress()
                            tickers.stopOnLoad()
                        }
                    }
                    Player.STATE_IDLE -> maybeDispatchBuffering(false)
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                tickers.stopProgress()
                tickers.stopOnLoad()
                maybeDispatchBuffering(false)
                dispatchError(error)
            }
        })
    }

    // ===== Public props =====
    fun setSource(url: String?) {
        exitFullscreen()
        val otherView = RCTVideoTag.getOtherViewForTag(this, shareTagElement)
        if(otherView !== null) return
        if (!url.isNullOrBlank() && url != currentSource) loadSource(url)
    }

    fun setPaused(paused: Boolean) {
        externallyPaused = paused
        if (!paused) posterView.visibility = GONE
        updatePlayState()
    }

    fun setLoop(loop: Boolean) {
        isLooping = loop
        player?.let { applyLoop(it) }
        if (loop && player?.playbackState == Player.STATE_ENDED) {
            player?.seekTo(0)
            player?.playWhenReady = true
        }
    }

    fun setMuted(muted: Boolean) {
        isMuted = muted
        player?.let { applyMuted(it) }
    }

    fun setVolume(vol: Double) {
        val v = vol.toFloat().coerceIn(0f, 1f)
        val p = player
        if (p == null) return
        rememberedVolume = v
        if (!isMuted) applyVolume(p, v)
    }

    fun setSeek(seconds: Double) {
        val ms = max(0L, (seconds * 1000.0).toLong())
        val p = player
        if (p == null || p.mediaItemCount == 0) return
        p.seekTo(ms)
    }

    fun setPoster(url: String?) {
        if (url.isNullOrBlank()) {
            posterView.setImageDrawable(null)
            posterView.visibility = GONE
            posterBitmap = null
            return
        }
        Thread {
            try {
                val bmp = BitmapFactory.decodeStream(URL(url).openStream())
                posterBitmap = bmp
                post {
                    posterView.setImageBitmap(bmp)
                    posterView.visibility = VISIBLE
                }
            } catch (_: Exception) {}
        }.start()

        applyPosterResizeMode(posterResizeMode)
        showPosterNeeded()
    }

    fun showPosterNeeded() {
        val neverPlayed = (player?.currentPosition ?: 0L) <= 50L
        val shouldShow = (externallyPaused && neverPlayed) || player == null
        posterView.visibility = if (shouldShow) VISIBLE else GONE
    }

    fun setPosterResizeMode(mode: String?) {
        val resizeMode = mode?.lowercase() ?: "cover"
        if (resizeMode == posterResizeMode) return
        posterResizeMode = resizeMode
        applyPosterResizeMode(posterResizeMode)
    }

    fun setResizeMode(mode: String?) {
        exitFullscreen()
        resizeModeStr = (mode ?: "contain").lowercase().trim()
        applyAspectNow()
    }

    fun setEnableProgress(value: Boolean) {
        isProgressEnabled = value
        if (value && player?.playbackState == Player.STATE_READY) tickers.startProgressIfNeeded()
        else tickers.stopProgress()
    }

    fun setEnableOnLoad(value: Boolean) {
        isOnLoadEnabled = value
        if (value && player?.playbackState == Player.STATE_READY) tickers.startOnLoadIfNeeded()
        else tickers.stopOnLoad()
    }

    fun setProgressInterval(ms: Double) {
        progressIntervalMs = ms.toLong().coerceAtLeast(50L)
        if (player?.playbackState == Player.STATE_READY && isProgressEnabled)
            tickers.startProgressIfNeeded()
        if (player?.playbackState == Player.STATE_READY && isOnLoadEnabled)
            tickers.startOnLoadIfNeeded()
    }

    fun setSeekFromCommand(seekSec: Double) {
        setSeek(seekSec)
    }
    fun setPausedFromCommand(paused: Boolean) {
        setPaused(paused)
    }
    fun setVolumeFromCommand(volume: Double) {
        val v = volume.coerceIn(0.0, 1.0)
        player?.let { applyVolume(it, v.toFloat()) } ?: run {}
    }

    fun setShareTagElement(tag: String?) {
        val newTag = tag?.trim()?.takeIf { it.isNotEmpty() }
        val oldTag = shareTagElement
        if (oldTag != null && oldTag != newTag) {
            RCTVideoTag.removeView(this, oldTag)
        }
        shareTagElement = newTag
        if (newTag != null) {
            RCTVideoTag.registerView(this, newTag)
        }
    }

    fun enterFullscreen() {
        if (fullscreenDialog != null || isFullscreen) return
        isFullscreen = true
        (playerView.parent as? FrameLayout)?.removeView(playerView)
        playerView.useController = true
        fullscreenDialog = FullscreenVideoDialog(context, playerView) { pv ->
            isFullscreen = false
            pv.useController = false
            videoPoster.addView(
                pv,
                0,
                LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            )
            showPosterNeeded()
            fullscreenDialog = null

            val reactCtx = context as? ReactContext ?: return@FullscreenVideoDialog
            if (!reactCtx.hasActiveCatalystInstance()) return@FullscreenVideoDialog
            val viewId = id.takeIf { it > 0 } ?: return@FullscreenVideoDialog
            UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId)
                ?.dispatchEvent(OnFullscreenPlayerDidDismiss(viewId))
        }
        fullscreenDialog?.show()
    }

    fun exitFullscreen() {
        fullscreenDialog?.dismiss() // callback sẽ tự handle attach lại
    }

    // ===== Helpers =====
    private fun loadSource(url: String) {
        val p = player ?: return
        currentSource = url
        videoW = 0
        videoH = 0
        didEmitLoadStartForCurrentItem = false
        lastIsBuffering = null
        tickers.resetOnLoadCache()

        p.setMediaItem(MediaItem.fromUri(url))
        post {
            p.prepare()
            p.playWhenReady = !externallyPaused
        }
    }

    private fun updatePlayState() {
        player?.playWhenReady = !externallyPaused
    }

    private fun applyLoop(p: ExoPlayer) {
        p.repeatMode = if (isLooping) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
    }

    private fun applyMuted(p: ExoPlayer) {
        if (isMuted) {
            if (p.volume > 0f) rememberedVolume = p.volume
            p.volume = 0f
        } else {
            applyVolume(p, rememberedVolume)
        }
    }

    private fun applyVolume(p: ExoPlayer, v: Float) {
        p.volume = v.coerceIn(0f, 1f)
    }

    private fun applyPosterResizeMode(mode: String) {
        posterView.scaleType = when (mode) {
            "cover" -> ImageView.ScaleType.CENTER_CROP
            "stretch", "fill" -> ImageView.ScaleType.FIT_XY
            "center" -> ImageView.ScaleType.CENTER
            else -> ImageView.ScaleType.FIT_CENTER
        }
    }

    // ===== Layout / aspect =====
    @OptIn(UnstableApi::class)
    private fun applyAspectNow() {
        if(isFullscreen) return;
        if (videoW <= 0 || videoH <= 0) {
            layoutChildToRect(Rect(0, 0, measuredWidth, measuredHeight))
            return
        }
        if (resizeModeStr == "stretch" || resizeModeStr == "fill") {
            try { playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FILL } catch (_: Throwable) {}
            val w = if (measuredWidth > 0) measuredWidth else width
            val h = if (measuredHeight > 0) measuredHeight else height
            if (w > 0 && h > 0) layoutChildToRect(Rect(0, 0, w, h))
            invalidate()
            return
        }
        val w = if (measuredWidth > 0) measuredWidth else width
        val h = if (measuredHeight > 0) measuredHeight else height
        if (w > 0 && h > 0) {
            val rect = RCTVideoLayoutUtils.computeChildRect(w, h, videoW, videoH, resizeModeStr)
            layoutChildToRect(rect)
            invalidate()
        }
        showPosterNeeded()
    }

    private fun layoutChildToRect(rect: Rect) {
        playerView.measure(
            MeasureSpec.makeMeasureSpec(rect.width(), MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(rect.height(), MeasureSpec.EXACTLY)
        )
        playerView.layout(rect.left, rect.top, rect.right, rect.bottom)
    }

    // ===== Events =====
    private fun maybeEmitOnLoadStartOnce() {
        if (didEmitLoadStartForCurrentItem) return
        val p = player ?: return
        if (p.playbackState != Player.STATE_READY) return

        val durSec = if (p.duration > 0) p.duration / 1000.0 else 0.0
        val bufferedSec = (p.bufferedPosition.coerceAtLeast(0L)) / 1000.0
        val playableSec = if (durSec > 0.0) kotlin.math.min(bufferedSec, durSec) else bufferedSec

        post {
            val reactCtx = context as? ReactContext ?: return@post
            if (!reactCtx.hasActiveCatalystInstance()) return@post
            if (!ViewCompat.isAttachedToWindow(this)) return@post
            val viewId = id.takeIf { it > 0 } ?: return@post
            UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId)
                ?.dispatchEvent(OnLoadStartEvent(viewId, durSec, playableSec, videoW, videoH))
            didEmitLoadStartForCurrentItem = true
        }
    }

    private fun maybeDispatchBuffering(isBuffering: Boolean) {
        if (lastIsBuffering == isBuffering) return
        lastIsBuffering = isBuffering
        val reactCtx = context as? ReactContext ?: return
        if (!reactCtx.hasActiveCatalystInstance()) return
        val viewId = id.takeIf { it > 0 } ?: return
        UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId)
            ?.dispatchEvent(OnBufferingEvent(viewId, isBuffering))
    }

    private fun dispatchEnd() {
        val reactCtx = context as? ReactContext ?: return
        if (!reactCtx.hasActiveCatalystInstance()) return
        val viewId = id.takeIf { it > 0 } ?: return
        UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId)
            ?.dispatchEvent(OnEndEvent(viewId))
    }

    private fun dispatchError(error: PlaybackException) {
        val reactCtx = context as? ReactContext ?: return
        if (!reactCtx.hasActiveCatalystInstance()) return
        val viewId = id.takeIf { it > 0 } ?: return
        UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId)
            ?.dispatchEvent(
                OnErrorEvent(
                    viewId,
                    RCTVideoErrorUtils.buildErrorMessage(error),
                    RCTVideoErrorUtils.buildErrorCode(error),
                    currentSource
                )
            )
    }

    // ===== Lifecycle =====
    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (isBlurWindow) {
            isBlurWindow = false
            alpha = 1f
            return
        }
        playerView.player = player
        if (videoW > 0 && videoH > 0) applyAspectNow()
        updatePlayState()
        if (shareTagElement != null) shareElement() else alpha = 1f
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        Log.d("RCTVideoView", "onDetachedFromWindow");

        if (isBlurWindow) cleanup()
        else if(!isSharing) revertShareElement()
    }

    fun dealloc() {
        if(!isSharing) revertShareElement()
    }

    fun cleanup() {
        RCTVideoTag.removeView(this, shareTagElement)
        exitFullscreen()

        tickers.stopProgress()
        tickers.stopOnLoad()
        player = null
        currentSource = null
        playerView.player = null
        player?.release()
        player = null
        videoW = 0
        videoH = 0
        didEmitLoadStartForCurrentItem = false
        lastIsBuffering = null
        overlay?.unmount()
        overlay = null
        posterBitmap = null
    }

    // ===== Share Element (Android version swap iOS) =====
    fun initialize() {}

    // ===== Share Element (Android version swap iOS) =====
    private fun shareElement() {
        val other = RCTVideoTag.getOtherViewForTag(this, shareTagElement)
        if (other == null) {
            alpha = 1f
            return
        }
        otherView = other
        playerView.player = null
        player?.release()
        player = null
        val movingPlayer = other.player ?: return
        val fromRect = rectForShare(other, 0)
        isSharing = true
        other.isSharing = true
        post {
            val toRect = rectForShare(this)
            alpha = 0f
            other.alpha = 0f
            other.playerView.player = null
            val ov = overlay ?: RCTVideoOverlay(context).also { overlay = it }
            val gravityAlias =
                when (resizeModeStr.lowercase()) {
                    "cover" -> "AVLayerVideoGravityResizeAspectFill"
                    "fill", "stretch" -> "AVLayerVideoGravityResize"
                    "center" -> "center"
                    else -> "AVLayerVideoGravityResizeAspect"
                }
            val bgColor =
                (other.background as? ColorDrawable)?.color
                    ?: android.graphics.Color.BLACK

            ov.applySharingAnimatedDuration(1000.0)
            ov.applyAVLayerVideoGravity(gravityAlias)
            ov.moveToOverlay(
                fromFrame = fromRect,
                targetFrame = toRect,
                player = movingPlayer,
                aVLayerVideoGravity = gravityAlias,
                bgColor = bgColor,
                onTarget = {
                    playerView.player = movingPlayer
                    player = movingPlayer
                    applyLoop(movingPlayer)
                    applyMuted(movingPlayer)
                    applyAspectNow()
                    setPaused(externallyPaused)
                    alpha = 1f

                    posterView.visibility = if(movingPlayer.currentPosition > 50L) GONE else VISIBLE
                },
                onCompleted = {
                    isSharing = false
                    other.isSharing = false
                    otherView?.showPosterNeeded()
                    overlay?.unmount()
                    overlay = null
                }
            )
        }
    }

    fun revertShareElement() {
        val other = otherView ?: run { cleanup(); return }
        val movingPlayer = player ?: run { cleanup(); return }
        val fromRect = rectForShare(this, 0)
        Log.d("RCTVideoView", fromRect.toString());
        alpha = 0f
        other.alpha = 0f

        val ov = other.overlay ?: RCTVideoOverlay(other.context).also { other.overlay = it }
        val gravityAlias =
            when (resizeModeStr.lowercase()) {
                "cover" -> "AVLayerVideoGravityResizeAspectFill"
                "fill", "stretch" -> "AVLayerVideoGravityResize"
                "center" -> "center"
                else -> "AVLayerVideoGravityResizeAspect"
            }
        val bgColor = (other.background as? ColorDrawable)?.color ?: android.graphics.Color.BLACK
        other.post {
            val toRect = other.rectForShare(other, 0)

            ov.applySharingAnimatedDuration(1000.0)
            ov.applyAVLayerVideoGravity(gravityAlias)

            ov.moveToOverlay(
                fromFrame = fromRect,
                targetFrame = toRect,
                player = movingPlayer,
                aVLayerVideoGravity = gravityAlias,
                bgColor = bgColor,
                onTarget = {
                    other.playerView.player = movingPlayer
                    other.player = movingPlayer
                    other.setPaused(other.externallyPaused)
                    other.applyLoop(other.player!!)
                    other.applyMuted(other.player!!)
                    other.alpha = 1f
                },
                onCompleted = {
                    other.overlay?.unmount()
                    other.overlay = null
                    cleanup()
                }
            )
        }
    }


    private fun findRoot(): ViewGroup? {
        val act = (context as? ReactContext)?.currentActivity ?: (context as? android.app.Activity)
        return act?.findViewById(android.R.id.content) ?: (act?.window?.decorView as? ViewGroup)
    }

    private fun rectForShare(v: View, extraTopPx: Int = 0): Rect {
        val root = findRoot() ?: return Rect(0, 0, 0, 0)
        val viewLoc = IntArray(2)
        val rootLoc = IntArray(2)
        v.getLocationOnScreen(viewLoc)
        root.getLocationOnScreen(rootLoc)
        val left = viewLoc[0] - rootLoc[0]
        val top = viewLoc[1] - rootLoc[1] + extraTopPx
        return Rect(left, top, left + v.width, top + v.height)
    }
}