package com.reactnativesharedelement.video.ffmpeg

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider

class VideoThumbnailPackage : BaseReactPackage() {

    override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? =
        if (name == VideoThumbnailModule.NAME) {
            VideoThumbnailModule(reactContext)
        } else {
            null
        }

    override fun getReactModuleInfoProvider() = ReactModuleInfoProvider {
        mapOf(
            VideoThumbnailModule.NAME to ReactModuleInfo(
                name = VideoThumbnailModule.NAME,
                className = VideoThumbnailModule.NAME,
                canOverrideExistingModule = false,
                needsEagerInit = false,
                isCxxModule = false,
                isTurboModule = true
            )
        )
    }
}