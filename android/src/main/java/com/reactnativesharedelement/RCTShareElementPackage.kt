package com.reactnativesharedelement

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager
import com.reactnativesharedelement.video.RCTVideoViewManager
import com.reactnativesharedelement.view.RCTShareViewManager
import com.reactnativesharedelement.video.ffmpeg.VideoThumbnailModule

class RCTVideoPackage : ReactPackage {
        override fun createNativeModules(
                reactContext: ReactApplicationContext
        ): List<NativeModule> = listOf(VideoThumbnailModule(reactContext))
        override fun createViewManagers(
                reactContext: ReactApplicationContext
        ): List<ViewManager<*, *>> = listOf(RCTVideoViewManager(), RCTShareViewManager())
}