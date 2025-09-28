package com.reactnativesharedelement.video

import android.app.Dialog
import android.content.Context
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.media3.ui.PlayerView

class FullscreenVideoDialog(
    context: Context,
    private val playerView: PlayerView,
    private val onDismissed: (PlayerView) -> Unit // callback
) : Dialog(context, android.R.style.Theme_Black_NoTitleBar_Fullscreen) {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window?.setBackgroundDrawableResource(android.R.color.black)
        window?.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        val container = FrameLayout(context)
        container.addView(playerView,FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))
        val closeButton = ImageView(context).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setPadding(40, 40, 40, 40)
            setOnClickListener { dismiss() }
        }
        container.addView(closeButton, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ))
        playerView.setControllerVisibilityListener(
            PlayerView.ControllerVisibilityListener { visibility ->
                closeButton.visibility = if (visibility == View.VISIBLE) View.VISIBLE else View.GONE
            }
        )
        setContentView(container)
        container.post {
            playerView.layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            playerView.requestLayout()
        }
    }

    override fun dismiss() {
        (playerView.parent as? FrameLayout)?.removeView(playerView)
        super.dismiss()
        onDismissed(playerView) // gọi về cho RCTVideoView gắn lại
    }
}