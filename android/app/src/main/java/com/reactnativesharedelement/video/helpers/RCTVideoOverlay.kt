package com.reactnativesharedelement.video.helpers

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.RectEvaluator
import android.animation.ValueAnimator
import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.graphics.Rect
import android.view.Choreographer
import android.view.View
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.facebook.react.bridge.ReactContext

class RCTVideoOverlay(context: Context) : FrameLayout(context) {

    var sharingAnimatedDurationMs: Long = 100L
    var resizeModeStr: String = "contain" // contain|cover|fill|center

    private var frameCallback: Choreographer.FrameCallback? = null

    // ===== Runtime state =====
    private var overlayPlayerView: PlayerView? = null
    var player: ExoPlayer? = null
    private var videoW = 0
    private var videoH = 0
    private var currentAnimator: ValueAnimator? = null

    init {
        clipToPadding = true
        clipChildren = true
        setBackgroundColor(Color.TRANSPARENT)
        isClickable = false
        isFocusable = false
        // đảm bảo mặc định cũng nổi trên hầu hết view
        elevation = DEFAULT_ELEV
        translationZ = DEFAULT_ELEV
    }
    // ---------- DisplayLink ----------
    fun startTicking() {
        if (frameCallback != null) return
        var cb: Choreographer.FrameCallback? = null
        cb =
            Choreographer.FrameCallback {
                onTick()
                if (frameCallback === cb) {
                    Choreographer.getInstance().postFrameCallback(cb)
                }
            }
        frameCallback = cb
        Choreographer.getInstance().postFrameCallback(cb)
    }

    fun stopTicking() {
        frameCallback?.let { Choreographer.getInstance().removeFrameCallback(it) }
        frameCallback = null
    }

    private fun onTick() {
        val w = width
        val h = height
        if (w <= 0 || h <= 0) return
        layoutChildByAspect(w, h)
    }

    // ---------- Layout child theo aspect (KHÔNG dùng resizeMode của PlayerView) ----------
    private fun layoutChildByAspect(w: Int, h: Int) {
        val pv = overlayPlayerView ?: return
        val rect =
            if (videoW > 0 && videoH > 0)
                RCTVideoLayoutUtils.computeChildRect(w, h, videoW, videoH, resizeModeStr)
            else Rect(0, 0, w, h)

        pv.measure(
            MeasureSpec.makeMeasureSpec(rect.width(), MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(rect.height(), MeasureSpec.EXACTLY)
        )
        pv.layout(rect.left, rect.top, rect.right, rect.bottom)
    }

    // ================== API chính giống iOS ==================
    @OptIn(UnstableApi::class)
    fun moveToOverlay(
        fromFrame: Rect,
        targetFrame: Rect,
        player: ExoPlayer,
        bgColor: Int? = null,
        onTarget: (() -> Unit)? = null,
        onCompleted: (() -> Unit)? = null
    ) {
        val root = getTargetRoot() ?: return
        unmount()

        this.player = player

        val size = player.videoSize
        if (size.width > 0 && size.height > 0) {
            videoW = size.width
            videoH = size.height
        }

        val lp = LayoutParams(fromFrame.width(), fromFrame.height())
        layoutParams = lp
        x = fromFrame.left.toFloat()
        y = fromFrame.top.toFloat()
        setBackgroundColor(bgColor ?: Color.TRANSPARENT)
        clipChildren = true
        overlayPlayerView =
            PlayerView(context, null, 0).apply {
                useController = false
                setBackgroundColor(Color.TRANSPARENT)
                try {
                    setShutterBackgroundColor(Color.TRANSPARENT)
                } catch (_: Throwable) {}
                try {
                    setKeepContentOnPlayerReset(true)
                } catch (_: Throwable) {}
                elevation = DEFAULT_ELEV + 1f
                translationZ = DEFAULT_ELEV + 1f
                this.player = player
            }
        addView(
            overlayPlayerView,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        )

        if (parent == null) root.addView(this, lp)
        safeAddOrUpdate(root, this, lp)
        ensureOnTop(root, this)

        startTicking()
        onTick()
        animateRectViaLp(root, this, fromFrame, targetFrame, sharingAnimatedDurationMs) {
            onTick()
            stopTicking()
            ensureOnTop(root, this)
            onTarget?.invoke()

            postDelayed(
                {
                    onCompleted?.invoke()
                },
                10
            )
        }
    }

    private fun safeAddOrUpdate(root: ViewGroup?, view: View, lp: FrameLayout.LayoutParams) {
        try {
            if (root == null) return
            if (view.parent == null) {
                root.addView(view, lp)
            } else if (view.parent === root && view.isAttachedToWindow) {
                root.updateViewLayout(view, lp)
            }
        } catch (_: Exception) {
        }
    }

    fun unmount() {
        overlayPlayerView?.player = null
        overlayPlayerView?.let {
            try {
                removeView(it)
            } catch (_: Throwable) {}
        }
        overlayPlayerView = null

        (parent as? ViewGroup)?.let { vg ->
            try {
                vg.removeView(this)
            } catch (_: Throwable) {}
        }
        stopTicking()

        player = null
        videoW = 0
        videoH = 0
    }

    // ================== Helpers ==================
    private fun getTargetRoot(): ViewGroup? {
        val act: Activity? =
            when (val ctx = context) {
                is Activity -> ctx
                is ReactContext -> ctx.currentActivity
                else -> null
            }
        // Ưu tiên android.R.id.content để nằm trên ReactRootView; fallback decorView
        val content = act?.findViewById<ViewGroup>(android.R.id.content)
        return content ?: (act?.window?.decorView as? ViewGroup)
    }

    private fun ensureOnTop(root: ViewGroup, v: View) {
        v.elevation = DEFAULT_ELEV
        v.translationZ = DEFAULT_ELEV
        v.bringToFront()
        root.requestLayout()
        root.invalidate()
    }

    private fun animateRectViaLp(
        root: ViewGroup,
        overlay: View,
        from: Rect,
        to: Rect,
        durationMs: Long,
        onEnd: (() -> Unit)?
    ) {
        val lp =
            (overlay.layoutParams as? LayoutParams)
                ?: LayoutParams(from.width(), from.height()).also {
                    overlay.layoutParams = it
                    if (overlay.parent == null) root.addView(overlay, it)
                }

        // state đầu
        lp.width = from.width()
        lp.height = from.height()
        overlay.x = from.left.toFloat()
        overlay.y = from.top.toFloat()
        //root.updateViewLayout(overlay, lp)
        safeAddOrUpdate(root, overlay, lp)
        ensureOnTop(root, overlay)

        overlay.setLayerType(LAYER_TYPE_HARDWARE, null)

        val eval = RectEvaluator()
        currentAnimator?.cancel()

        currentAnimator = ValueAnimator.ofObject(eval, Rect(from), Rect(to))
            .apply {
                duration = durationMs
                interpolator = DecelerateInterpolator()
                addUpdateListener { va ->
                    val r = va.animatedValue as Rect
                    overlay.x = r.left.toFloat()
                    overlay.y = r.top.toFloat()
                    lp.width = r.width()
                    lp.height = r.height()
                    // root.updateViewLayout(overlay, lp)
                    safeAddOrUpdate(root, overlay, lp)
                    // đảm bảo nằm trên cùng trong suốt quá trình animate
                    ensureOnTop(root, overlay)
                }
                addListener(
                    object : AnimatorListenerAdapter() {
                        override fun onAnimationStart(animation: Animator) {
                            ensureOnTop(root, overlay)
                        }
                        override fun onAnimationEnd(animation: Animator) {
                            overlay.setLayerType(LAYER_TYPE_NONE, null)
                            ensureOnTop(root, overlay)
                            onEnd?.invoke()
                        }
                    }
                )
            }
        currentAnimator?.start()
    }

    // giữ aspect kể cả khi parent tự layout lại ngoài animation
    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        super.onLayout(changed, l, t, r, b)
        layoutChildByAspect(r - l, b - t)
    }

    companion object {
        private const val DEFAULT_ELEV = 100000f
    }
}