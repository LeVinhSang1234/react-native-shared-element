package com.reactnativesharedelement.view

import android.os.Build
import android.view.View
import androidx.annotation.RequiresApi
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.annotations.ReactProp

class RCTShareViewManager : ViewGroupManager<RCTShareView>() {
    override fun getName() = "ShareView"

    override fun createViewInstance(reactContext: ThemedReactContext): RCTShareView {
        return RCTShareView(reactContext)
    }

    @RequiresApi(Build.VERSION_CODES.P)
    override fun onDropViewInstance(view: RCTShareView) {
        super.onDropViewInstance(view)
        view.dealloc()
    }

    // ========= Children Handling =========
    override fun addView(parent: RCTShareView, child: View, index: Int) {
        parent.viewContainer.addView(child, index)
    }

    override fun removeViewAt(parent: RCTShareView, index: Int) {
        parent.viewContainer.removeViewAt(index)
    }

    override fun getChildCount(parent: RCTShareView): Int {
        return parent.viewContainer.childCount
    }

    override fun getChildAt(parent: RCTShareView, index: Int): View {
        return parent.viewContainer.getChildAt(index)
    }

    // ========= Props =========
    @ReactProp(name = "shareTagElement")
    fun setShareTagElement(view: RCTShareView, value: String?) {
        view.shareTagElement = value
    }

    @ReactProp(name = "sharingAnimatedDuration")
    fun setSharingAnimatedDuration(view: RCTShareView, value: Float) {
        view.sharingAnimatedDuration = value.toDouble()
    }

    // ========= Commands =========
    @RequiresApi(Build.VERSION_CODES.P)
    override fun receiveCommand(view: RCTShareView, commandId: String, args: ReadableArray?) {
        when (commandId) {
            "initialize" -> view.initialize()
            "prepareForRecycle" -> view.prepareForRecycle()
            "freeze" -> view.freeze()
            "unfreeze" -> view.unfreeze()
        }
    }
}