package com.reactnativesharedelement.video

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Rect
import android.util.AttributeSet
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
import java.net.URL
import kotlin.math.max
import kotlin.math.roundToInt
import androidx.media3.exoplayer.upstream.DefaultAllocator
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.datasource.DefaultHttpDataSource

class RCTVideoView : FrameLayout {

    // ===== UI =====
    internal lateinit var playerView: PlayerView
    private lateinit var posterView: ImageView
    private val videoPoster = FrameLayout(context)
    val videoContainer: ReactViewGroup =
        ReactViewGroup(context).apply {
            clipChildren = true
            setBackgroundColor(Color.TRANSPARENT)
        }
    private var overlay: RCTVideoOverlay? = null
    private var otherView: RCTVideoView? = null
    private var otherViewSameWindow: Boolean = false

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
    private var posterUrl: String? = null
    private var isDealloc = false
    private var isFullscreen = false
    private var externallyPaused = false
    internal var resizeModeStr: String = "contain"
        private set
    private var isMuted = false
    private var rememberedVolume = 1f

    // ===== Events / Tickers =====
    private var lastIsBuffering: Boolean? = null
    private var progressIntervalMs = 250L
    private var memoryDebugIntervalMs = 5000L
    private var isProgressEnabled = false
    private var isOnLoadEnabled = false
    private var isOnMemoryDebugEnabled = false
    private var didEmitLoadStartForCurrentItem = false
    private var didEmitLoadForCurrentItem = false
    private var shareTagElement: String? = null
    private var sharingAnimatedDuration: Double = 260.0
    private var fullscreenDialog: FullscreenVideoDialog? = null
    private var backgroundColor: Int = Color.BLACK

    private var bufferConfig: Map<String, Double>? = null
    private var maxBitRate: Int? = null
    private var playbackRate = 1.0
    private var keepScreenOnEnabled = false
    private var useOkHttp = true
    private var stopWhenPaused = false

    private val tickers by lazy {
        RCTVideoTickers(
            hostView = this,
            getReactContext = { context as? ReactContext },
            getViewId = { id },
            getPlayer = { player },
            getIntervalMs = { progressIntervalMs },
            getMemoryDebugIntervalMs = { memoryDebugIntervalMs },
            isProgressEnabled = { isProgressEnabled },
            isOnLoadEnabled = { isOnLoadEnabled },
            isMemoryDebugEnabled = { isOnMemoryDebugEnabled }
        )
    }

    // ===== Constructors =====
    constructor(context: Context) : super(context) {
        configure()
    }

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) {
        configure()
    }

    constructor(
        context: Context,
        attrs: AttributeSet?,
        defStyleAttr: Int
    ) : super(context, attrs, defStyleAttr) {
        configure()
    }

    // ===== Init =====
    @OptIn(UnstableApi::class)
    private fun configure() {
        clipChildren = true
        alpha = 0f
        playerView =
            PlayerView(context, null, 0).apply {
                useController = false
                setBackgroundColor(Color.TRANSPARENT)
                setShutterBackgroundColor(Color.TRANSPARENT)
            }
        posterView =
            ImageView(context).apply {
                scaleType = ImageView.ScaleType.CENTER_CROP
                visibility = GONE
                isClickable = false
                isFocusable = false
            }
        videoPoster.addView(
            posterView,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        )
        addView(videoPoster, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        addView(videoContainer, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        setBackgroundColor(Color.BLACK)
    }

    @OptIn(UnstableApi::class)
    private fun buildPlayer(): ExoPlayer {
        val upstream = if (useOkHttp) {
            OkHttpDataSource.Factory(HttpStack.get(context))
        } else {
            DefaultHttpDataSource.Factory()
        }

        val defaultMin = 15000
        val defaultMax = 50000
        val defaultPlay = 2500
        val defaultRebuffer = 5000

        val minB = (bufferConfig?.get("min") ?: defaultMin.toDouble()).toInt()
        val maxB = (bufferConfig?.get("max") ?: defaultMax.toDouble()).toInt()
        val playB = (bufferConfig?.get("play") ?: defaultPlay.toDouble()).toInt()
        val rebB = (bufferConfig?.get("rebuffer") ?: defaultRebuffer.toDouble()).toInt()

        val safePlayB = playB.coerceAtMost(minB)
        val safeRebB = rebB.coerceAtMost(safePlayB)
        val safeMinB = minB.coerceAtMost(maxB)
        val heapPercent = (bufferConfig?.get("heapPercent") ?: 0.0).coerceIn(0.01, 1.0)
        val maxHeap = Runtime.getRuntime().maxMemory()
        val targetBufferBytes = (maxHeap * heapPercent).toInt()
        val allocator = DefaultAllocator(true, C.DEFAULT_BUFFER_SEGMENT_SIZE)

        val loadControl = DefaultLoadControl.Builder()
            .setAllocator(allocator)
            .setBufferDurationsMs(safeMinB, maxB, safePlayB, safeRebB)
            .setTargetBufferBytes(targetBufferBytes)
            .build()

        val trackSelector = DefaultTrackSelector(context).apply {
            val bitrate = maxBitRate
            if (bitrate != null && bitrate > 0) {
                setParameters(
                    buildUponParameters()
                        .setMaxVideoBitrate(bitrate)
                        .setForceLowestBitrate(false)
                        .setAllowVideoMixedMimeTypeAdaptiveness(true)
                )
            }
        }

        return ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .setTrackSelector(trackSelector)
            .setMediaSourceFactory(DefaultMediaSourceFactory(upstream))
            .build()
    }

    private fun attachListeners(p: ExoPlayer) {
        p.addListener(
            object : Player.Listener {
                override fun onVideoSizeChanged(size: VideoSize) {
                    val w = size.width
                    val h =
                        (size.height * size.pixelWidthHeightRatio)
                            .roundToInt()
                            .coerceAtLeast(1)
                    if (w > 0 && h > 0 && (videoW != w || videoH != h)) {
                        videoW = w
                        videoH = h
                        applyAspectNow()
                    }
                }

                override fun onPlaybackStateChanged(state: Int) {
                    when (state) {
                        Player.STATE_BUFFERING -> maybeDispatchBuffering(true)
                        Player.STATE_READY -> {
                            maybeEmitOnLoadStartOnce()
                            maybeDispatchBuffering(false)
                            maybeEmitOnLoadOnce()
                            tickers.startProgressIfNeeded()
                            updateKeepScreenOn()
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
                            updateKeepScreenOn()
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
            }
        )
    }

    // ===== Public props =====
    fun setSource(url: String?) {
        val other = RCTVideoTag.getOtherViewForTag(this, shareTagElement)
        if (isSharing || (other != null && !other.isDealloc)) {
            currentSource = url
            return
        }
        if (!url.isNullOrBlank() && url != currentSource) {
            setSourceFromCommand(url)
        } else if (url.isNullOrBlank()) {
            unmount()
            showPosterNeeded()
        }
    }

    fun setSourceFromCommand(url: String) {
        exitFullscreen()
        if (playerView.parent != null) {
            (playerView.parent as? ViewGroup)?.removeView(playerView)
        }
        player = try {
            buildPlayer().also {
                playerView.player = it
                attachListeners(it)
            }
        } catch (oom: OutOfMemoryError) {
            dispatchErrorSafe(oom.localizedMessage, "E_OOM_BUILD")
            null
        } catch (e: Exception) {
            dispatchErrorSafe(e.localizedMessage, "E_BUILD_FAIL")
            null
        }
        videoPoster.addView(
            playerView,
            0,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        )
        loadSource(url)
        showPosterNeeded()
        setRate(playbackRate)
    }

    fun setBgColor(color: Int) {
        backgroundColor = color
    }

    fun setPaused(paused: Boolean) {
        externallyPaused = paused
        if (!paused) {
            posterView.visibility = GONE
            tickers.startProgressIfNeeded()
        } else {
            tickers.stopProgress()
            updateKeepScreenOn()
        }
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
        val p = player ?: return
        rememberedVolume = v
        if (!isMuted) applyVolume(p, v)
    }

    fun setSeek(seconds: Double) {
        val ms = max(0L, (seconds * 1000.0).toLong())
        val p = player ?: return
        if (p.mediaItemCount == 0) return
        p.seekTo(ms)
    }

    fun showPosterNeeded() {
        if (!isSharing) return
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

    fun setSharingAnimatedDuration(value: Float) {
        sharingAnimatedDuration = value.toDouble()
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

    fun setUseOkHttp(enabled: Boolean) {
        useOkHttp = enabled
        rebuildPlayerIfNeeded()
    }

    fun setStopWhenPaused(value: Boolean) {
        stopWhenPaused = value
    }

    fun setEnableOnMemoryDebug(value: Boolean) {
        isOnMemoryDebugEnabled = value
        if (value) tickers.startOnMemoryDebugIfNeeded()
        else tickers.stopOnMemoryDebug()
    }

    fun setMemoryDebugInterval(ms: Double) {
        memoryDebugIntervalMs = ms.toLong().coerceAtLeast(50L)
        if (isOnMemoryDebugEnabled) tickers.startOnMemoryDebugIfNeeded()
    }

    fun setRate(rate: Double) {
        playbackRate = rate.coerceIn(0.1, 2.0)
        player?.let {
            try {
                val params = it.playbackParameters
                it.playbackParameters = PlaybackParameters(playbackRate.toFloat(), params.pitch)
            } catch (e: Exception) {
                dispatchErrorSafe(e.localizedMessage, "E_SET_RATE")
            }
        }
    }

    fun setPoster(url: String?) {
        if (posterUrl == url) return
        applyPoster()
    }

    private fun applyPoster() {
        posterView.setImageDrawable(null)
        posterBitmap?.recycle()
        posterBitmap = null
        if (posterUrl.isNullOrBlank()) {
            posterView.visibility = GONE
            return
        }
        posterView.visibility = VISIBLE
        post {
            Thread {
                try {
                    val bmp = decodeScaledBitmap(posterUrl!!, width, height)
                    posterBitmap = bmp
                    post {
                        posterView.setImageBitmap(bmp)
                    }
                } catch (_: Exception) {
                }
            }.start()
            showPosterNeeded()
        }
    }

    fun decodeScaledBitmap(url: String, reqW: Int, reqH: Int): Bitmap? {
        return try {
            val connection = URL(url).openConnection()
            connection.connect()
            val input = connection.getInputStream()

            val opts = BitmapFactory.Options()
            opts.inJustDecodeBounds = true
            BitmapFactory.decodeStream(input, null, opts)
            input.close()

            var inSampleSize = 1
            while (opts.outWidth / inSampleSize > reqW * 2 || opts.outHeight / inSampleSize > reqH * 2) {
                inSampleSize *= 2
            }

            val opts2 = BitmapFactory.Options().apply {
                inSampleSize = inSampleSize
                inPreferredConfig = Bitmap.Config.RGB_565 // giảm 50% RAM
            }

            val input2 = URL(url).openStream()
            val bmp = BitmapFactory.decodeStream(input2, null, opts2)
            input2.close()
            bmp
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    fun setKeepScreenOnEnabled(enabled: Boolean) {
        keepScreenOnEnabled = enabled
        updateKeepScreenOn()
    }

    private fun updateKeepScreenOn() {
        val shouldKeepOn = keepScreenOnEnabled && player?.playWhenReady == true
        this.keepScreenOn = shouldKeepOn
    }

    fun setShareTagElement(tag: String?) {
        val newTag = tag?.trim()?.takeIf { it.isNotEmpty() }
        val oldTag = shareTagElement
        if (oldTag != null && oldTag != newTag) {
            if (player !== null) returnOtherViewIfNeeded(player!!)
            RCTVideoTag.removeView(this, oldTag)
            if (newTag.isNullOrBlank()) {
                initializePlayerFromCurrentProps()
            }
        }
        shareTagElement = newTag
        if (newTag != null) {
            RCTVideoTag.registerView(this, newTag)
        }

    }

    fun initializePlayerFromCurrentProps() {
        if (!currentSource.isNullOrBlank()) {
            setSourceFromCommand(currentSource!!)
        }
        updatePlayState()
        setLoop(isLooping)
        setMuted(isMuted)
        setVolume(rememberedVolume.toDouble())
        setResizeMode(resizeModeStr)
    }

    fun enterFullscreen() {
        if (fullscreenDialog != null || isFullscreen) return
        isFullscreen = true
        (playerView.parent as? FrameLayout)?.removeView(playerView)
        playerView.useController = true
        fullscreenDialog =
            FullscreenVideoDialog(context, playerView) { pv ->
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
        tickers.resetOnLoadCache()

        p.setMediaItem(MediaItem.fromUri(url))
        post {
            p.prepare()
            p.playWhenReady = !externallyPaused
        }
    }

    private fun updatePlayState() {
        if (stopWhenPaused) {
            try {
                if (externallyPaused) player?.stop()
                else player?.prepare()
            } catch (e: Exception) {
                dispatchErrorSafe(e.localizedMessage, "E_STOP_WHEN_PAUSED")
            }
        }
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
        applyPoster()
    }

    fun dispatchErrorSafe(message: String?, code: String?) {
        try {
            val reactCtx = context as? ReactContext ?: return
            if (!reactCtx.hasActiveCatalystInstance()) return
            val viewId = id.takeIf { it > 0 } ?: return

            UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId)
                ?.dispatchEvent(
                    OnErrorEvent(
                        viewId,
                        message ?: "Unknown error",
                        code ?: "E_UNKNOWN",
                        currentSource
                    )
                )
        } catch (e: Exception) {
        }
    }

    fun setBufferConfig(config: Map<String, Any>?) {
        try {
            if (config == null) {
                bufferConfig = null
                return
            }

            val minBuffer = (config["minBufferMs"] as? Double)
            val maxBuffer = (config["maxBufferMs"] as? Double)
            val playBuffer = (config["bufferForPlaybackMs"] as? Double)
            val rebuffer = (config["bufferForPlaybackAfterRebufferMs"] as? Double)
            val heapPercent = (config["maxHeapAllocationPercent"] as? Double)

            bufferConfig = mutableMapOf<String, Double>().apply {
                minBuffer?.let { this["min"] = it }
                maxBuffer?.let { this["max"] = it }
                playBuffer?.let { this["play"] = it }
                rebuffer?.let { this["rebuffer"] = it }
                heapPercent?.let { this["heapPercent"] = it }
            }
            rebuildPlayerIfNeeded()
        } catch (e: Exception) {
            dispatchErrorSafe(e.localizedMessage, "E_INVALID_BUFFER_CONFIG")
        } catch (oom: OutOfMemoryError) {
            dispatchErrorSafe(oom.localizedMessage, "E_OOM_BUFFER")
        }
    }

    fun setMaxBitRate(value: Int) {
        if (value > 0) {
            maxBitRate = value
        } else {
            maxBitRate = null
        }
        rebuildPlayerIfNeeded()
    }

    private fun rebuildPlayerIfNeeded() {
        val src = currentSource ?: return
        if (player?.playbackState != Player.STATE_READY) return

        try {
            unmount()
            setSourceFromCommand(src)
        } catch (oom: OutOfMemoryError) {
            dispatchErrorSafe(
                "Out of memory while rebuilding player (${oom.localizedMessage})",
                "E_OOM_REBUILD_PLAYER"
            )
        } catch (e: Exception) {
            dispatchErrorSafe(
                "Failed to rebuild player: ${e.localizedMessage}",
                "E_REBUILD_PLAYER"
            )
        }
    }

    // ===== Layout / aspect =====
    @OptIn(UnstableApi::class)
    private fun applyAspectNow() {
        if (isFullscreen) return
        if (videoW <= 0 || videoH <= 0) {
            layoutChildToRect(Rect(0, 0, measuredWidth, measuredHeight))
            return
        }
        if (resizeModeStr == "stretch" || resizeModeStr == "fill") {
            try {
                playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FILL
            } catch (_: Throwable) {
            }
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

    private fun maybeEmitOnLoadOnce() {
        if (didEmitLoadForCurrentItem) return
        tickers.startOnLoadIfNeeded()
        didEmitLoadForCurrentItem = true
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
        playerView.player = player
        if (videoW > 0 && videoH > 0) applyAspectNow()
        updatePlayState()
        if (shareTagElement != null && !isSharing) shareElement() else alpha = 1f
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
    }

    fun dealloc() {
        isDealloc = true
        RCTVideoTag.removeView(this, shareTagElement)
        if (otherViewSameWindow && player !== null) returnOtherViewIfNeeded(player!!);
        else revertShareElement()
        otherViewSameWindow = false
    }

    fun unmount() {
        exitFullscreen()
        tickers.stopProgress()
        tickers.stopOnLoad()
        currentSource = null

        if (!isSharing && player != null) {
            player?.apply {
                if (playbackState != Player.STATE_IDLE && playbackState != Player.STATE_ENDED) {
                    try {
                        clearVideoSurface()
                    } catch (e: Exception) {
                        dispatchErrorSafe(e.localizedMessage, "E_CLEAR_VIDEO_SURFACE")
                    }
                }
                try {
                    stop()
                } catch (e: Exception) {
                    dispatchErrorSafe(e.localizedMessage, "E_STOP_PLAYER")
                }
                try {
                    release()
                } catch (e: Exception) {
                    dispatchErrorSafe(e.localizedMessage, "E_RELEASE_PLAYER")
                }
            }
        }
        playerView.player = null
        videoPoster.removeView(playerView)

        player = null
        videoW = 0
        videoH = 0
        lastIsBuffering = null
        didEmitLoadStartForCurrentItem = false
        didEmitLoadForCurrentItem = false

        posterBitmap?.recycle()
        posterBitmap = null

        System.runFinalization()
        System.gc()
        Runtime.getRuntime().gc()
    }

    fun cleanup() {
        RCTVideoTag.removeView(this, shareTagElement)
        unmount()
        overlay?.unmount()
        overlay = null
        posterBitmap = null
        isDealloc = false
        isSharing = false
    }

    // ===== Share Element (Android version swap iOS) =====
    fun initialize() {}

    fun returnOtherViewIfNeeded(movingPlayer: ExoPlayer) {
        val other = otherView
        if (other == null) return
        other.videoW = videoW
        other.videoH = videoH
        other.player = null
        other.playerView.player = null
        other.player = movingPlayer
        other.playerView.player = movingPlayer

        other.applyAspectNow()
        other.applyLoop(movingPlayer)
        other.applyMuted(movingPlayer)
        other.alpha = 1f
        otherView = null
    }

    // ===== Share Element (Android version swap iOS) =====
    private fun shareElement() {
        val other = RCTVideoTag.getOtherViewForTag(this, shareTagElement)
        if (other == null || other.isDealloc) {
            alpha = 1f
            return
        }
        otherViewSameWindow = other.parent === parent
        otherView = other
        post {
            postDelayed(
                {
                    val fromRect = other.rectForShare()
                    val toRect = rectForShare()
                    val bgColor = other.backgroundColor
                    val ov = overlay ?: RCTVideoOverlay(context).also { overlay = it }
                    if (sharingAnimatedDuration > 0) {
                        ov.sharingAnimatedDurationMs = sharingAnimatedDuration.toLong()
                    }
                    ov.resizeModeStr = other.resizeModeStr
                    alpha = 0f
                    other.alpha = 0f

                    ov.moveToOverlay(
                        fromFrame = fromRect,
                        targetFrame = toRect,
                        player = other.player!!,
                        bgColor = bgColor,
                        onTarget = { restorePlayerFromOther(other) },
                        onCompleted = {
                            isSharing = false
                            other.isSharing = false
                            showPosterNeeded()
                            ov.unmount()
                            overlay = null
                        }
                    )
                },
                1
            )
        }
    }

    fun revertShareElement() {
        val other = otherView ?: run { cleanup(); return }
        if (other.isDealloc) {
            cleanup(); return
        }
        other.isSharing = true
        isSharing = true
        other.post {
            alpha = 0f
            val fromRect = rectForShare()
            val toRect = other.rectForShare()
            val bgColor = backgroundColor
            val ov = other.overlay ?: RCTVideoOverlay(context).also { other.overlay = it }
            ov.sharingAnimatedDurationMs = sharingAnimatedDuration.toLong()
            ov.resizeModeStr = resizeModeStr
            other.alpha = 0f

            val movingPlayer = player ?: return@post

            ov.moveToOverlay(
                fromFrame = fromRect,
                targetFrame = toRect,
                player = movingPlayer,
                bgColor = bgColor,
                onTarget = { returnOtherViewIfNeeded(movingPlayer) },
                onCompleted = {
                    other.isSharing = false
                    other.overlay = null
                    other.showPosterNeeded()
                    ov.unmount()
                    cleanup()
                }
            )
        }
    }

    // ===== Helpers =====
    private fun triggerPlayerStateCallbacks(p: ExoPlayer) {
        if (videoW > 0 && videoH > 0) {
            applyAspectNow()
        }
        when (p.playbackState) {
            Player.STATE_BUFFERING -> maybeDispatchBuffering(true)
            Player.STATE_READY -> {
                maybeEmitOnLoadStartOnce()
                maybeDispatchBuffering(false)
                maybeEmitOnLoadOnce()
                tickers.startProgressIfNeeded()
                updateKeepScreenOn()
            }

            Player.STATE_ENDED -> {
                maybeDispatchBuffering(false)
                dispatchEnd()
            }

            Player.STATE_IDLE -> maybeDispatchBuffering(false)
        }

        val error = p.playerError
        if (error != null) {
            dispatchError(error)
        }
    }

    private fun attachPlayerToView(p: ExoPlayer) {
        playerView.player = p
        player = p
        attachListeners(p)
    }

    private fun applyAllPlayerProps(p: ExoPlayer) {
        applyAspectNow()
        applyLoop(p)
        applyMuted(p)
        updatePlayState()
        triggerPlayerStateCallbacks(p)
    }

    private fun syncPlayerFromOther(other: RCTVideoView) {
        videoW = other.videoW
        videoH = other.videoH
        currentSource = other.currentSource
        externallyPaused = other.externallyPaused
        isLooping = other.isLooping
        isMuted = other.isMuted
        rememberedVolume = other.rememberedVolume
        resizeModeStr = other.resizeModeStr
        shareTagElement = other.shareTagElement
    }

    fun restorePlayerFromOther(other: RCTVideoView) {
        val movingPlayer = other.player ?: return
        syncPlayerFromOther(other)
        attachPlayerToView(movingPlayer)
        videoPoster.addView(
            playerView,
            0,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        )
        applyAllPlayerProps(movingPlayer)
        alpha = 1f
    }

    private fun findRoot(): ViewGroup? {
        val act = (context as? ReactContext)?.currentActivity ?: (context as? android.app.Activity)
        return act?.findViewById(android.R.id.content) ?: (act?.window?.decorView as? ViewGroup)
    }

    private fun rectForShare(): Rect {
        val root = findRoot() ?: return Rect(0, 0, 0, 0)
        val viewLoc = IntArray(2)
        val rootLoc = IntArray(2)
        this.getLocationOnScreen(viewLoc)
        root.getLocationOnScreen(rootLoc)
        val left = viewLoc[0] - rootLoc[0]
        val top = viewLoc[1] - rootLoc[1]
        return Rect(left, top, left + width, top + height)
    }
}
