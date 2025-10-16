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

@ReactModule(name = VideoThumbnailModule.NAME)
class VideoThumbnailModule(private val reactContext: ReactApplicationContext)
    : NativeVideoThumbnailSpec(reactContext) {

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

                // ⚙️ Scale nhỏ lại để tiết kiệm RAM và tăng tốc encode
                val targetWidth = 160  // bạn có thể chỉnh 120–240 tùy thanh preview
                val scaled = Bitmap.createScaledBitmap(
                    frame,
                    targetWidth,
                    (frame.height * targetWidth.toFloat() / frame.width).toInt(),
                    true
                )
                frame.recycle()

                // 🧠 Nén JPEG ở chất lượng thấp hơn cho tốc độ nhanh
                val output = ByteArrayOutputStream()
                scaled.compress(Bitmap.CompressFormat.JPEG, 70, output)
                val base64 = Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)

                scaled.recycle()
                retriever.release()

                // ✅ Trả về data URI sẵn sàng hiển thị bên React Native
                promise.resolve("data:image/jpeg;base64,$base64")
            } catch (e: Exception) {
                try { retriever.release() } catch (_: Throwable) {}
                promise.reject("THUMBNAIL_ERROR", e.message, e)
            }
        }
    }
}