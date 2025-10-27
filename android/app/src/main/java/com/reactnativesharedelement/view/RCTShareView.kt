package com.reactnativesharedelement.view

import android.content.Context
import android.graphics.*
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.widget.FrameLayout
import android.widget.ImageView
import android.view.View
import android.view.ViewGroup
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.facebook.react.bridge.ReactContext
import com.facebook.react.views.view.ReactViewGroup
import com.reactnativesharedelement.view.helpers.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class RCTShareView : FrameLayout, ShareViewContainerProvider {
    private val pausedPlayers = mutableListOf<ExoPlayer>()
    private var snapshotView: ImageView? = null
    private var frozen = false
    private var shareTagElement: String? = null
    private var otherView: RCTShareView? = null
    private var overlay: RCTShareViewOverlay? = null

    var isDealloc = false
    var isSharing = false
    var sharingAnimatedDuration: Double? = null
    val viewContainer = ReactViewGroup(context).apply { clipChildren = true }

    // ===== Constructors =====
    constructor(context: Context) : super(context) { configure() }
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) { configure() }
    constructor(context: Context, attrs: AttributeSet?, defStyleAttr: Int)
            : super(context, attrs, defStyleAttr) { configure() }

    override fun getShareViewContainer(): ViewGroup = viewContainer

    private fun configure() {
        clipChildren = true
        addView(viewContainer, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    }

     fun setShareTagElement(tag: String?) {
        val newTag = tag?.trim()?.takeIf { it.isNotEmpty() }
        val oldTag = shareTagElement
        if (oldTag != null && oldTag != newTag) {
            RCTShareViewTag.removeView(this, oldTag)
        }
        shareTagElement = newTag
        if (newTag != null) {
            RCTShareViewTag.registerView(this, newTag)
        }
    }

    // ===================== SNAPSHOT =====================
    private fun captureSnapshot(): Bitmap? {
        val w = viewContainer.width
        val h = viewContainer.height
        if (w <= 0 || h <= 0) return null

        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        viewContainer.layout(viewContainer.left, viewContainer.top, viewContainer.right, viewContainer.bottom)
        viewContainer.draw(canvas)
        return bitmap
    }

    // ===================== FREEZE / UNFREEZE =====================
    fun freeze() {
        if (frozen) return
        frozen = true
        pauseVideoPlayers(this)

        val snapshot = captureSnapshot() ?: return
        snapshotView = ImageView(context).apply {
            setImageBitmap(snapshot)
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            scaleType = ImageView.ScaleType.CENTER_CROP
        }

        viewContainer.visibility = INVISIBLE
        addView(snapshotView)
    }

    fun unfreeze() {
        if (!frozen) return
        frozen = false
        snapshotView?.let {
            removeView(it)
            it.setImageDrawable(null)
            it.setImageBitmap(null)
        }
        snapshotView = null
        viewContainer.visibility = VISIBLE
        resumeVideoPlayers()
    }

    private fun pauseVideoPlayers(root: View) {
        if (root is PlayerView) {
            val player = root.player
            if (player is ExoPlayer) {
                val isActuallyPlaying =
                    player.playWhenReady && player.playbackState == ExoPlayer.STATE_READY
                if (isActuallyPlaying) {
                    try {
                        player.playWhenReady = false
                        player.stop()
                        pausedPlayers.add(player)
                    } catch (_: Exception) { }
                }
            }
        } else if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                pauseVideoPlayers(root.getChildAt(i))
            }
        }
    }

    private fun resumeVideoPlayers() {
        pausedPlayers.forEach {
            try {
                it.prepare()
                it.playWhenReady = true
            } catch (_: Exception) { }
        }
        pausedPlayers.clear()
    }

    // ===================== LIFECYCLE =====================
    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (shareTagElement != null && !isSharing) shareElement() else alpha = 1f
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        android.util.Log.d("RCTShareView", "onDetachedFromWindow")
    }

    // ===================== SHARED ELEMENT PLACEHOLDER =====================
    fun initialize() {}
    fun prepareForRecycle() = revertShareElement()

    fun dealloc() {
        isDealloc = true
        RCTShareViewTag.removeView(this, shareTagElement)
        if (!isSharing) prepareForRecycle()
    }

    private fun cleanup() {
        pausedPlayers.clear()
        snapshotView?.let {
            it.setImageDrawable(null)
            it.setImageBitmap(null)
            removeView(it)
        }
        snapshotView = null
        frozen = false
        overlay?.didUnmount()
        overlay = null
        isSharing = false
        viewContainer.removeAllViews()
    }

    private fun revertShareElement() {
        val other = otherView ?: run { cleanup(); return }
        if (other.isDealloc) {
            cleanup()
            return
        }
        isSharing = true
        other.isSharing = true
        val duration = (sharingAnimatedDuration ?: 300.0).toLong()
        val ov = other.overlay ?: RCTShareViewOverlay(other.context).also { other.overlay = it }
        other.post {
            val fromRect = rectForShare(this)
            val toRect = rectForShare(other)
            ov.moveToOverlay(
                fromFrame = fromRect,
                toFrame = toRect,
                fromView = this,
                toView = other,
                duration = duration,
                onTarget = { other.alpha = 1f },
                onCompleted = {
                    cleanup()
                    other.isSharing = false
                }
            )
        }
    }

    private fun shareElement() {
        val other = RCTShareViewTag.getOtherViewForTag(this, shareTagElement)
        if (other == null || other.isDealloc) {
            alpha = 1.0f
            return
        }
        other.isSharing = true
        isSharing = true
        otherView = other
        post {
            postDelayed({
                val ov = overlay ?: RCTShareViewOverlay(context).also { overlay = it }
                val fromRect = rectForShare(other)
                val toRect = rectForShare(this)
                val duration = (sharingAnimatedDuration ?: 300.0).toLong()
                ov.moveToOverlay(
                    fromFrame = fromRect,
                    toFrame = toRect,
                    fromView = other,
                    toView = this,
                    duration = duration,
                    onTarget = {
                        other.alpha = 1f
                        alpha = 1f
                    },
                    onCompleted = {
                        overlay?.didUnmount()
                        overlay = null
                        isSharing = false
                        other.isSharing = false
                    }
                )
            }, 1)
        }
    }

    // ===================== HELPERS =====================
    private fun findRoot(): ViewGroup? {
        val act = (context as? ReactContext)?.currentActivity ?: (context as? android.app.Activity)
        return act?.findViewById(android.R.id.content)
            ?: (act?.window?.decorView as? ViewGroup)
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
