package com.reactnativesharedelement.view

import android.content.Context
import android.graphics.*
import android.os.Build
import android.view.Choreographer
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import androidx.annotation.RequiresApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.facebook.react.bridge.ReactContext
import com.facebook.react.views.view.ReactViewGroup
import android.widget.FrameLayout
import android.util.AttributeSet

import android.graphics.Bitmap
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.PixelCopy
import android.app.Activity
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class RCTShareView : FrameLayout {
    private val pausedPlayers = mutableListOf<ExoPlayer>()
    private var snapshotView: ImageView? = null
    private var frozen = false

    var isDealloc = false
    var shareTagElement: String? = null
        set(value) {
            if (field == value) return
            field = value
        }

    var sharingAnimatedDuration: Double? = null
    val viewContainer: ReactViewGroup =
        ReactViewGroup(context).apply {
            clipChildren = true
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
    private fun configure() {
        clipChildren = true
        addView(viewContainer, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    }

    // ===================== FREEZE / UNFREEZE =====================
    private fun captureSnapshot(): Bitmap? {
        val activity = (context as? ReactContext)?.currentActivity ?: return null
        val w = width
        val h = height
        if (w <= 0 || h <= 0) return null

        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val location = IntArray(2)
        getLocationInWindow(location)
        val rect = Rect(location[0], location[1], location[0] + w, location[1] + h)

        val latch = CountDownLatch(1)
        val handler = Handler(Looper.getMainLooper())

        var success = false
        PixelCopy.request(
            activity.window,
            rect,
            bitmap,
            { result ->
                success = (result == PixelCopy.SUCCESS)
                latch.countDown()
            },
            handler
        )

        try {
            latch.await(200, TimeUnit.MILLISECONDS)
        } catch (e: InterruptedException) {
        }

        return if (success) bitmap else null
    }

    fun freeze() {
        if (frozen) return
        frozen = true
        pauseVideoPlayers(this)

        val snapshot = captureSnapshot()
        if (snapshot == null) {
            return
        }

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
                    } catch (_: Exception) {
                    }
                }
            }
        } else if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                pauseVideoPlayers(root.getChildAt(i))
            }
        }
    }

    private fun resumeVideoPlayers() {
        if (pausedPlayers.isEmpty()) return
        for ((index, player) in pausedPlayers.withIndex()) {
            try {
                player.prepare()
                player.playWhenReady = true

            } catch (e: Exception) {
            }
        }
        pausedPlayers.clear()
    }
    // ===================== LIFECYCLE / SHARED ELEMENT =====================

    fun initialize() {}

    @RequiresApi(Build.VERSION_CODES.P)
    fun prepareForRecycle() {
        performBackSharedElementIfPossible()
    }

    fun dealloc() {
        isDealloc = true
        cleanup()
    }

    private fun cleanup() {
        pausedPlayers.clear()
        snapshotView = null
        frozen = false
    }

    // ===================== SHARED ELEMENT PLACEHOLDER =====================

    @RequiresApi(Build.VERSION_CODES.P)
    private fun performBackSharedElementIfPossible() {
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun startSharedElementTransition() {
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