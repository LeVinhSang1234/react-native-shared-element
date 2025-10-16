package com.reactnativesharedelement.view

import android.os.Build
import androidx.annotation.RequiresApi
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.bridge.ReadableArray

class RCTShareViewManager : ViewGroupManager<RCTShareView>() {
    override fun getName() = "ShareView"

    override fun createViewInstance(reactContext: ThemedReactContext) = RCTShareView(reactContext)

    @RequiresApi(Build.VERSION_CODES.P)
    override fun onDropViewInstance(view: RCTShareView) {
        super.onDropViewInstance(view)
        view.dealloc()
    }

    @ReactProp(name = "shareTagElement")
    fun setShareTagElement(view: RCTShareView, value: String?) { view.shareTagElement = value }

    @ReactProp(name = "sharingAnimatedDuration")
    fun setSharingAnimatedDuration(view: RCTShareView, value: Float) { view.sharingAnimatedDuration = value.toDouble() }

    @RequiresApi(Build.VERSION_CODES.P)
    override fun receiveCommand(view: RCTShareView, commandId: String, args: ReadableArray?) {
        when (commandId) {
            "initialize" -> view.initialize()
            "prepareForRecycle" -> view.prepareForRecycle()
        }
    }
}