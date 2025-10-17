package com.reactnativesharedelement.video.helpers

import com.facebook.react.bridge.Arguments
import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.RCTEventEmitter
import kotlin.math.round

class OnLoadStartEvent(
    viewId: Int,
    private val durationSec: Double,
    private val playableDurationSec: Double,
    private val widthPx: Int,
    private val heightPx: Int
) : Event<OnLoadStartEvent>(viewId) {
    override fun getEventName() = "onLoadStart"
    override fun canCoalesce() = false

    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val map =
            Arguments.createMap().apply {
                putDouble("duration", durationSec)
                putDouble("playableDuration", playableDurationSec)
                putDouble("width", widthPx.toDouble())
                putDouble("height", heightPx.toDouble())
            }
        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}

class OnProgressEvent(
    viewId: Int,
    private val positionSec: Double,
    private val durationSec: Double?,
    private val playableDurationSec: Double
) : Event<OnProgressEvent>(viewId) {
    override fun getEventName() = "onProgress"
    override fun canCoalesce() = true
    override fun getCoalescingKey(): Short = (positionSec * 10).toInt().toShort()

    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val map =
            Arguments.createMap().apply {
                putDouble("currentTime", positionSec)
                durationSec?.let { putDouble("duration", it) }
                putDouble("playableDuration", playableDurationSec)
            }
        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}

class OnLoadEvent(
    viewId: Int,
    private val loadedDurationSec: Double,
    private val durationSec: Double
) : Event<OnLoadEvent>(viewId) {
    override fun getEventName() = "onLoad"
    override fun canCoalesce() = false

    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val map =
            Arguments.createMap().apply {
                putDouble("loadedDuration", loadedDurationSec)
                putDouble("duration", durationSec)
            }
        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}

class OnBufferingEvent(viewId: Int, private val isBuffering: Boolean) :
    Event<OnBufferingEvent>(viewId) {
    override fun getEventName() = "onBuffering"
    override fun canCoalesce() = false

    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val map = Arguments.createMap().apply { putBoolean("isBuffering", isBuffering) }
        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}

class OnEndEvent(viewId: Int) : Event<OnEndEvent>(viewId) {
    override fun getEventName() = "onEnd"
    override fun canCoalesce() = false

    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val map = Arguments.createMap()
        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}

class OnErrorEvent(
    viewId: Int,
    private val message: String,
    private val code: String?,
    private val track: String?
) : Event<OnErrorEvent>(viewId) {
    override fun getEventName() = "onError"
    override fun canCoalesce() = false

    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val map = Arguments.createMap().apply {
            putString("message", message)
            code?.let { putString("code", it) }
            track?.let { putString("track", it) }
        }
        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}

class OnFullscreenPlayerDidDismiss(
    viewId: Int,
) : Event<OnFullscreenPlayerDidDismiss>(viewId) {
    override fun getEventName() = "onFullscreenPlayerDidDismiss"
    override fun canCoalesce() = false

    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val map = Arguments.createMap().apply {}
        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}

class OnMemoryDebugEvent(
    viewId: Int,
    private val heapMB: Double,
    private val nativeMB: Double,
) : Event<OnMemoryDebugEvent>(viewId) {
    override fun getEventName() = "onMemoryDebug"
    override fun canCoalesce() = false

    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val heap = round(heapMB)
        val native = round(nativeMB)
        val total = round(heapMB + nativeMB)

        val maxHeapMB = round(Runtime.getRuntime().maxMemory() / 1048576.0 * 10) / 10.0
        val percent = round(total / maxHeapMB * 1000) / 10.0

        val map = Arguments.createMap().apply {
            putDouble("heapMB", heap)
            putDouble("nativeMB", native)
            putString(
                "message",
                "💾 Memory usage — Heap: ${heap} MB | Native: ${native} MB | " +
                        "(~${percent}% of ${maxHeapMB} MB limit)"
            )
        }

        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}