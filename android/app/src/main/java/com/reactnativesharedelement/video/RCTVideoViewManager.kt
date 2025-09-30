package com.reactnativesharedelement.video

import android.graphics.Color
import android.view.View
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.annotations.ReactProp
import com.reactnativesharedelement.video.helpers.HttpStack
import androidx.core.graphics.toColorInt

class RCTVideoViewManager : ViewGroupManager<RCTVideoView>() {

    override fun getName() = "RCTVideo"

    private var lastCacheSizeMB: Int = 300

    // ===== Lifecycle =====
    override fun createViewInstance(reactContext: ThemedReactContext): RCTVideoView {
        return RCTVideoView(reactContext)
    }

    override fun onDropViewInstance(view: RCTVideoView) {
        super.onDropViewInstance(view)
        view.dealloc()
    }

    // ===== Children handling =====
    override fun addView(parent: RCTVideoView, child: View, index: Int) {
        parent.videoContainer.addView(child, index)
    }

    override fun removeViewAt(parent: RCTVideoView, index: Int) {
        parent.videoContainer.removeViewAt(index)
    }

    override fun getChildCount(parent: RCTVideoView): Int {
        return parent.videoContainer.childCount
    }

    override fun getChildAt(parent: RCTVideoView, index: Int): View {
        return parent.videoContainer.getChildAt(index)
    }

    // ===== Props =====
    @ReactProp(name = "source")
    fun setSource(view: RCTVideoView, value: String?) {
        view.setSource(value)
    }

    @ReactProp(name = "paused", defaultBoolean = false)
    fun setPaused(view: RCTVideoView, value: Boolean) {
        view.setPaused(value)
    }

    @ReactProp(name = "loop", defaultBoolean = false)
    fun setLoop(view: RCTVideoView, value: Boolean) {
        view.setLoop(value)
    }

    @ReactProp(name = "muted", defaultBoolean = false)
    fun setMuted(view: RCTVideoView, value: Boolean) {
        view.setMuted(value)
    }

    @ReactProp(name = "volume")
    fun setVolume(view: RCTVideoView, value: Double) = view.setVolume(value)

    @ReactProp(name = "seek") fun setSeek(view: RCTVideoView, value: Double) = view.setSeek(value)

    @ReactProp(name = "resizeMode")
    fun setResizeMode(view: RCTVideoView, value: String?) = view.setResizeMode(value)

    @ReactProp(name = "poster")
    fun setPoster(view: RCTVideoView, poster: String?) {
        view.setPoster(poster)
    }

    @ReactProp(name = "posterResizeMode")
    fun setPosterResizeMode(view: RCTVideoView, mode: String?) {
        view.setPosterResizeMode(mode)
    }

    @ReactProp(name = "enableProgress")
    fun setEnableProgress(view: RCTVideoView, value: Boolean) {
        view.setEnableProgress(value)
    }

    @ReactProp(name = "enableOnLoad")
    fun setEnableOnLoad(view: RCTVideoView, value: Boolean) {
        view.setEnableOnLoad(value)
    }

    @ReactProp(name = "progressInterval")
    fun setProgressInterval(view: RCTVideoView, ms: Double) {
        view.setProgressInterval(ms)
    }

    @ReactProp(name = "fullscreen", defaultBoolean = false)
    fun setFullscreen(view: RCTVideoView, value: Boolean) {
        if (value) view.enterFullscreen() else view.exitFullscreen()
    }

    @ReactProp(name = "shareTagElement")
    fun setShareTagElement(view: RCTVideoView, value: String?) {
        view.setShareTagElement(value) // sẽ auto register/unregister trong setter
    }

    @ReactProp(name = "sharingAnimatedDuration", defaultFloat = 0f)
    fun setSharingAnimatedDuration(view: RCTVideoView, value: Float) {
        view.setSharingAnimatedDuration(value)
    }

    @ReactProp(name = "backgroundColor", customType = "Color")
    fun setBackgroundColor(view: RCTVideoView, colorStr: String?) {
        if (!colorStr.isNullOrEmpty()) {
            try {
                val colorInt = colorStr.toColorInt()
                view.setVideoBackgroundColor(colorInt)
                view.setBackgroundColor(colorInt)
            } catch (_: IllegalArgumentException) {
                view.setVideoBackgroundColor(Color.BLACK)
                view.setBackgroundColor(Color.BLACK)
            }
        } else {
            view.setVideoBackgroundColor(Color.BLACK)
            view.setBackgroundColor(Color.BLACK)
        }
    }

    @ReactProp(name = "cacheMaxSize", defaultInt = 300)
    fun setCacheMaxSize(view: RCTVideoView, sizeMB: Int) {
        if (sizeMB != lastCacheSizeMB) {
            lastCacheSizeMB = sizeMB
            val ctx = view.context
            HttpStack.reset()
            HttpStack.get(
                ctx,
                HttpStack.Options(cacheSizeBytes = sizeMB.toLong() * 1024 * 1024)
            )
        }
    }

    override fun receiveCommand(view: RCTVideoView, commandId: String, args: ReadableArray?) {
        when (commandId) {
            "initialize" -> view.initialize()
            "setSeekCommand" -> {
                val sec = args?.getDouble(0) ?: 0.0
                view.setSeekFromCommand(sec)
            }
            "setPausedCommand" -> {
                val paused = args?.getBoolean(0) ?: false
                view.setPausedFromCommand(paused)
            }
            "setVolumeCommand" -> {
                val vol = args?.getDouble(0) ?: 1.0
                view.setVolumeFromCommand(vol)
            }
            "presentFullscreenPlayer" -> {
                view.enterFullscreen()
            }
            "dismissFullscreenPlayer" -> {
                view.exitFullscreen()
            }
        }
    }

    override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
        mutableMapOf(
            "onLoadStart" to mutableMapOf("registrationName" to "onLoadStart"),
            "onLoad" to mutableMapOf("registrationName" to "onLoad"),
            "onProgress" to mutableMapOf("registrationName" to "onProgress"),
            "onError" to mutableMapOf("registrationName" to "onError"),
            "onBuffering" to mutableMapOf("registrationName" to "onBuffering")
        )
}