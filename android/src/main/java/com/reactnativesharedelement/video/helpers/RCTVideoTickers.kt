package com.reactnativesharedelement.video.helpers

import android.view.View
import androidx.core.view.ViewCompat
import androidx.media3.common.Player
import com.facebook.react.bridge.ReactContext
import com.facebook.react.uimanager.UIManagerHelper
import kotlin.math.abs

/**
 * Quản lý 2 ticker: onProgress và onLoad
 * - Tự kiểm tra ReactContext/dispatcher còn active không
 * - Tự đọc Player để tính current/buffered/duration
 * - Expose start/stop theo từng ticker + startIfNeeded tiện dùng
 */
class RCTVideoTickers(
        private val hostView: View,
        private val getReactContext: () -> ReactContext?,
        private val getViewId: () -> Int,
        private val getPlayer: () -> Player?,
        private val getIntervalMs: () -> Long,
        private val isProgressEnabled: () -> Boolean,
        private val isOnLoadEnabled: () -> Boolean
) {
    // cache lần cuối của onLoad để chỉ emit khi thay đổi
    private var lastOnLoadLoaded: Double? = null
    private var lastOnLoadDuration: Double? = null

    private fun logMemory(tag: String = "VideoPlayer") {
        val runtime = Runtime.getRuntime()
        val usedHeap = runtime.totalMemory() - runtime.freeMemory()
        val usedNative = android.os.Debug.getNativeHeapAllocatedSize()
        val totalUsed = usedHeap + usedNative

        android.util.Log.d(
            "RCTVideoView",
            "💾 [$tag] heap=${usedHeap / 1048576}MB, native=${usedNative / 1048576}MB, total=${totalUsed / 1048576}MB"
        )
    }

    // ====== progress ticker ======
    private val progressTick =
            object : Runnable {
                override fun run() {
                    if (!isProgressEnabled()) return
                    val p = getPlayer() ?: return reSchedule()
                    val react = getReactContext() ?: return reSchedule()
                    if (!react.hasActiveCatalystInstance() ||
                                    !ViewCompat.isAttachedToWindow(hostView)
                    )
                            return reSchedule()

                    val viewId = getViewId().takeIf { it > 0 } ?: return reSchedule()
                    val dispatcher =
                            UIManagerHelper.getEventDispatcherForReactTag(react, viewId)
                                    ?: return reSchedule()

                    val pos = (p.currentPosition.coerceAtLeast(0L)) / 1000.0
                    val dur = if (p.duration > 0) p.duration / 1000.0 else null
                    val buf = (p.bufferedPosition.coerceAtLeast(0L)) / 1000.0
                    val playable = dur?.let { minOf(buf, it) } ?: buf
                    // logMemory()
                    dispatcher.dispatchEvent(OnProgressEvent(viewId, pos, dur, playable))
                    reSchedule()
                }
                private fun reSchedule() {
                    hostView.postDelayed(this, getIntervalMs())
                }
            }

    fun startProgressIfNeeded() {
        stopProgress()
        if (!isProgressEnabled()) return
        hostView.postDelayed(progressTick, getIntervalMs())
    }

    fun stopProgress() {
        hostView.removeCallbacks(progressTick)
    }

    // ====== onLoad ticker ======
    private val onLoadTick =
            object : Runnable {
                override fun run() {
                    if (!isOnLoadEnabled()) return
                    val p = getPlayer() ?: return reSchedule()
                    if (p.playbackState != Player.STATE_READY) return reSchedule()

                    val react = getReactContext() ?: return reSchedule()
                    if (!react.hasActiveCatalystInstance() ||
                                    !ViewCompat.isAttachedToWindow(hostView)
                    )
                            return reSchedule()

                    val viewId = getViewId().takeIf { it > 0 } ?: return reSchedule()
                    val dispatcher =
                            UIManagerHelper.getEventDispatcherForReactTag(react, viewId)
                                    ?: return reSchedule()

                    val loaded = (p.bufferedPosition.coerceAtLeast(0L)) / 1000.0
                    val duration = if (p.duration > 0) p.duration / 1000.0 else 0.0

                    if (hasOnLoadChanged(loaded, duration)) {
                        dispatcher.dispatchEvent(OnLoadEvent(viewId, loaded, duration))
                        lastOnLoadLoaded = loaded
                        lastOnLoadDuration = duration
                    }
                    reSchedule()
                }
                private fun reSchedule() {
                    hostView.postDelayed(this, getIntervalMs())
                }
            }

    private fun hasOnLoadChanged(loaded: Double, duration: Double): Boolean {
        val prevL = lastOnLoadLoaded
        val prevD = lastOnLoadDuration
        val eps = 1e-3
        return prevL == null ||
                prevD == null ||
                abs(loaded - prevL) > eps ||
                abs(duration - prevD) > eps
    }

    fun startOnLoadIfNeeded() {
        stopOnLoad()
        if (!isOnLoadEnabled()) return
        lastOnLoadLoaded = null
        lastOnLoadDuration = null
        hostView.post(onLoadTick)
    }

    fun stopOnLoad() {
        hostView.removeCallbacks(onLoadTick)
    }

    fun resetOnLoadCache() {
        lastOnLoadLoaded = null
        lastOnLoadDuration = null
    }
}