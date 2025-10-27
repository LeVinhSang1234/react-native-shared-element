package com.reactnativesharedelement.video.ffmpeg

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.util.Base64
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import com.reactnativesharedelement.NativeVideoThumbnailSpec
import android.app.ActivityManager
import android.content.Context
import android.os.Debug
import android.util.Log
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

@ReactModule(name = VideoThumbnailModule.NAME)
class VideoThumbnailModule(private val reactContext: ReactApplicationContext) :
    NativeVideoThumbnailSpec(reactContext) {

    companion object {
        const val NAME = "VideoThumbnail"
    }

    override fun getName() = NAME

    override fun getThumbnail(url: String, timeMs: Double, promise: Promise) {
        CoroutineScope(Dispatchers.IO).launch {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(url, HashMap())

                // ⚡ Lấy keyframe gần nhất cho tốc độ cao
                val frame = retriever.getFrameAtTime(
                    (timeMs * 1000).toLong(),
                    MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                )

                if (frame == null) {
                    promise.reject("NO_FRAME", "Cannot extract frame at ${timeMs}ms")
                    return@launch
                }

                val targetWidth = 160
                val scaled = Bitmap.createScaledBitmap(
                    frame,
                    targetWidth,
                    (frame.height * targetWidth.toFloat() / frame.width).toInt(),
                    true
                )
                frame.recycle()

                val output = ByteArrayOutputStream()
                scaled.compress(Bitmap.CompressFormat.JPEG, 70, output)
                val base64 = Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)

                scaled.recycle()
                retriever.release()

                promise.resolve("data:image/jpeg;base64,$base64")
            } catch (e: Exception) {
                try {
                    retriever.release()
                } catch (_: Throwable) {
                }
                promise.reject("THUMBNAIL_ERROR", e.message, e)
            }
        }
    }

    override fun getMemory(promise: Promise) {
        try {
            val activityManager =
                reactContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val info = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(info)

            val totalMB = info.totalMem / (1024 * 1024)
            val availMB = info.availMem / (1024 * 1024)
            val usedMB = totalMB - availMB
            val percentUsed = (usedMB.toDouble() / totalMB * 100).toInt()

            val memInfo = Debug.MemoryInfo()
            Debug.getMemoryInfo(memInfo)
            val totalPss = memInfo.totalPss / 1024
            val nativePss = memInfo.nativePss / 1024
            val dalvikPss = memInfo.dalvikPss / 1024
            val otherPss = memInfo.otherPss / 1024

            val message = """
        💾 Memory usage:
        ▪ Total RAM:  ${totalMB}MB
        ▪ Used RAM:   ${usedMB}MB (${percentUsed}%)
        ▪ Native:     ${nativePss}MB
        ▪ Dalvik:     ${dalvikPss}MB
        ▪ Other:      ${otherPss}MB
        ▪ PSS Total:  ${totalPss}MB
      """.trimIndent()
            promise.resolve(message)
        } catch (e: Exception) {
            promise.reject("ERR_MEMORY", e)
        }
    }
}