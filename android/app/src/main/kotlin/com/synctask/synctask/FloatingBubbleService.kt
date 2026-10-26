package com.synctask.synctask

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView

class FloatingBubbleService : Service() {
    private var windowManager: WindowManager? = null
    private var bubbleContainer: FrameLayout? = null

    companion object {
        var isRunning: Boolean = false
            private set
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }

        windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
        if (windowManager == null) {
            stopSelf()
            return
        }

        val metrics = resources.displayMetrics
        val density = metrics.density
        val bubbleSize = (58 * density).toInt()

        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        // FLAG_NOT_FOCUSABLE ensures touches pass through to video players and underlying apps
        val params = WindowManager.LayoutParams(
            bubbleSize,
            bubbleSize,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = metrics.widthPixels - bubbleSize - (16 * density).toInt()
            y = metrics.heightPixels / 3
        }

        bubbleContainer = FrameLayout(this).apply {
            val bgDrawable = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#1E232E"))
                setStroke((2 * density).toInt(), Color.parseColor("#3880FF"))
            }
            background = bgDrawable
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                elevation = 8 * density
            }

            val iconView = ImageView(context).apply {
                setImageResource(R.mipmap.ic_launcher)
                scaleType = ImageView.ScaleType.FIT_CENTER
                val pad = (6 * density).toInt()
                setPadding(pad, pad, pad, pad)
            }
            addView(
                iconView,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                )
            )
        }

        bubbleContainer?.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        params.x = initialX + dx
                        params.y = initialY + dy
                        try {
                            windowManager?.updateViewLayout(bubbleContainer, params)
                        } catch (_: Exception) {}
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        val diffX = Math.abs(event.rawX - initialTouchX)
                        val diffY = Math.abs(event.rawY - initialTouchY)

                        if (diffX < 12 * density && diffY < 12 * density) {
                            val intent = Intent(this@FloatingBubbleService, MainActivity::class.java).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            }
                            startActivity(intent)
                        } else {
                            val screenWidth = resources.displayMetrics.widthPixels
                            params.x = if (params.x + (bubbleSize / 2) < screenWidth / 2) {
                                (12 * density).toInt()
                            } else {
                                screenWidth - bubbleSize - (12 * density).toInt()
                            }
                            try {
                                windowManager?.updateViewLayout(bubbleContainer, params)
                            } catch (_: Exception) {}
                        }
                        return true
                    }
                }
                return false
            }
        })

        try {
            windowManager?.addView(bubbleContainer, params)
            isRunning = true
        } catch (_: Exception) {
            stopSelf()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        bubbleContainer?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        bubbleContainer = null
        isRunning = false
    }
}
