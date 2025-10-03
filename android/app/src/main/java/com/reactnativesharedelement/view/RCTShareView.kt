package com.reactnativesharedelement.view


import android.content.Context
import android.graphics.Rect
import android.os.Build
import android.view.View
import android.view.ViewGroup
import androidx.annotation.RequiresApi
import com.facebook.react.views.view.ReactViewGroup
import com.facebook.react.bridge.ReactContext

class RCTShareView(context: Context) : ReactViewGroup(context) {
    var shareTagElement: String? = null
        set(value) {
            if (field == value) return
            field = value
        }

    var sharingAnimatedDuration: Double? = null
    var isBlurWindow: Boolean = false

    init {
        clipChildren = true
        // alpha = 0f
    }

    @RequiresApi(Build.VERSION_CODES.P)
    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (isBlurWindow) {
            isBlurWindow = false
            return
        }
        startSharedElementTransition()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
    }

    fun initialize() {}

    @RequiresApi(Build.VERSION_CODES.P)
    fun prepareForRecycle() {
        performBackSharedElementIfPossible()
    }

    fun dealloc() {
        isBlurWindow = true
    }

    private fun cleanup() {
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun performBackSharedElementIfPossible() {
    }


    @RequiresApi(Build.VERSION_CODES.P)
    private fun startSharedElementTransition() {
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