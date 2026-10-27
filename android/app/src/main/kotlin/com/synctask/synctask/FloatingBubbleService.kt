package com.synctask.synctask

import android.app.Service
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.FileObserver
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.text.InputType
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.io.File
import java.util.UUID

class FloatingBubbleService : Service() {
    private var windowManager: WindowManager? = null
    private var bubbleContainer: FrameLayout? = null
    private var panelContainer: FrameLayout? = null

    private var bubbleParams: WindowManager.LayoutParams? = null
    private var panelParams: WindowManager.LayoutParams? = null
    private var isPanelOpen = false

    private val mainHandler = Handler(Looper.getMainLooper())
    private var dbFileObserver: FileObserver? = null
    private var refreshTaskListCallback: (() -> Unit)? = null
    private var isCompactSize = false

    data class OverlayTask(val id: String, val title: String, val priority: Int)

    companion object {
        var isRunning: Boolean = false
            private set
        private var instance: FloatingBubbleService? = null

        fun notifyTasksChanged() {
            instance?.mainHandler?.post {
                instance?.refreshTaskListCallback?.invoke()
            }
        }

        fun setAppForeground(isForeground: Boolean) {
            instance?.mainHandler?.post {
                if (isForeground) {
                    instance?.bubbleContainer?.visibility = View.GONE
                    instance?.panelContainer?.visibility = View.GONE
                } else {
                    instance?.bubbleContainer?.visibility = View.VISIBLE
                }
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this

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

        // Floating Bubble Window Params
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
        bubbleParams = params

        bubbleContainer = FrameLayout(this).apply {
            val bgDrawable = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#0B132B"))
                setStroke((1.5 * density).toInt(), Color.parseColor("#38BDF8"))
            }
            background = bgDrawable
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                elevation = 8 * density
            }

            val iconView = ImageView(context).apply {
                setImageResource(R.drawable.ic_sky_mascot)
                scaleType = ImageView.ScaleType.FIT_CENTER
                val pad = (4 * density).toInt()
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
            private var isDragging = false
            private var touchDownTime = 0L

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        isDragging = false
                        touchDownTime = System.currentTimeMillis()
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        val distance = Math.hypot(dx.toDouble(), dy.toDouble())
                        if (!isDragging && distance > 10 * density) {
                            isDragging = true
                        }
                        if (isDragging) {
                            params.x = initialX + dx
                            params.y = initialY + dy
                            try {
                                windowManager?.updateViewLayout(bubbleContainer, params)
                            } catch (_: Exception) {}
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        val touchDuration = System.currentTimeMillis() - touchDownTime
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        val distance = Math.hypot(dx.toDouble(), dy.toDouble())

                        // Single Tap: open the Floating Task Panel!
                        if (!isDragging || (touchDuration < 400 && distance < 20 * density)) {
                            showFloatingPanel()
                        } else {
                            // Drag gesture finished: snap bubble to nearest screen edge
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
            startDbObserver()
        } catch (_: Exception) {
            stopSelf()
        }
    }

    private fun startDbObserver() {
        val dbFile = File(filesDir, "synctask.db")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                dbFileObserver = object : FileObserver(dbFile, CLOSE_WRITE or MODIFY or CREATE) {
                    override fun onEvent(event: Int, path: String?) {
                        notifyTasksChanged()
                    }
                }
            } else {
                @Suppress("DEPRECATION")
                dbFileObserver = object : FileObserver(filesDir.path, CLOSE_WRITE or MODIFY or CREATE) {
                    override fun onEvent(event: Int, path: String?) {
                        if (path == null || path.contains("synctask.db")) {
                            notifyTasksChanged()
                        }
                    }
                }
            }
            dbFileObserver?.startWatching()
        } catch (_: Exception) {}
    }

    private fun showFloatingPanel() {
        if (isPanelOpen || windowManager == null) return

        val metrics = resources.displayMetrics
        val density = metrics.density
        val screenWidth = metrics.widthPixels
        val screenHeight = metrics.heightPixels

        val panelWidth = (330 * density).toInt().coerceAtMost(screenWidth - (20 * density).toInt())
        val initialHeight = if (isCompactSize) (310 * density).toInt() else (460 * density).toInt()
        val panelHeight = initialHeight.coerceAtMost(screenHeight - (50 * density).toInt())

        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        // Calculate position near bubble, clamped to screen
        val bX = bubbleParams?.x ?: (screenWidth - panelWidth - (16 * density).toInt())
        val bY = bubbleParams?.y ?: (screenHeight / 4)
        val panelX = (bX - (panelWidth / 3)).coerceIn((10 * density).toInt(), screenWidth - panelWidth - (10 * density).toInt())
        val panelY = (bY - (panelHeight / 3)).coerceIn((30 * density).toInt(), screenHeight - panelHeight - (30 * density).toInt())

        val pParams = WindowManager.LayoutParams(
            panelWidth,
            panelHeight,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = panelX
            y = panelY
        }
        panelParams = pParams

        // Panel Container Card
        val root = FrameLayout(this).apply {
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 20 * density
                setColor(Color.parseColor("#151A24"))
                setStroke((1.5 * density).toInt(), Color.parseColor("#3880FF"))
            }
            background = bg
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                elevation = 16 * density
            }
        }

        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val pad = (12 * density).toInt()
            setPadding(pad, pad, pad, pad)
        }

        // Top Drag Handle Bar
        val handleBarContainer = LinearLayout(this).apply {
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, (6 * density).toInt())
        }
        val handleBar = View(this).apply {
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 2 * density
                setColor(Color.parseColor("#475569"))
            }
            background = bg
            layoutParams = LinearLayout.LayoutParams((38 * density).toInt(), (4 * density).toInt())
        }
        handleBarContainer.addView(handleBar)
        mainLayout.addView(handleBarContainer)

        // 1. Header Row (Draggable touch area)
        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, (8 * density).toInt())
        }

        // Draggable Touch Listener on Header & HandleBar
        val dragTouchListener = object : View.OnTouchListener {
            private var startX = 0
            private var startY = 0
            private var touchX = 0f
            private var touchY = 0f
            private var isDragging = false

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        startX = pParams.x
                        startY = pParams.y
                        touchX = event.rawX
                        touchY = event.rawY
                        isDragging = false
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - touchX).toInt()
                        val dy = (event.rawY - touchY).toInt()
                        if (!isDragging && Math.hypot(dx.toDouble(), dy.toDouble()) > 8 * density) {
                            isDragging = true
                        }
                        if (isDragging) {
                            val curScreenWidth = resources.displayMetrics.widthPixels
                            val curScreenHeight = resources.displayMetrics.heightPixels
                            pParams.x = (startX + dx).coerceIn(0, curScreenWidth - pParams.width)
                            pParams.y = (startY + dy).coerceIn((16 * density).toInt(), curScreenHeight - pParams.height)
                            try {
                                windowManager?.updateViewLayout(panelContainer, pParams)
                            } catch (_: Exception) {}
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        return true
                    }
                }
                return false
            }
        }

        headerRow.setOnTouchListener(dragTouchListener)
        handleBarContainer.setOnTouchListener(dragTouchListener)

        val iconView = ImageView(this).apply {
            setImageResource(R.mipmap.ic_launcher)
            val iconSize = (22 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(iconSize, iconSize).apply {
                marginEnd = (8 * density).toInt()
            }
        }
        headerRow.addView(iconView)

        val titleView = TextView(this).apply {
            text = "SyncTask"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15.5f)
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        headerRow.addView(titleView)

        // Pending count badge
        val badgeView = TextView(this).apply {
            setTextColor(Color.parseColor("#3880FF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            typeface = Typeface.DEFAULT_BOLD
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 10 * density
                setColor(Color.parseColor("#253880FF"))
            }
            background = bg
            val pX = (6 * density).toInt()
            val pY = (2 * density).toInt()
            setPadding(pX, pY, pX, pY)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                marginStart = (6 * density).toInt()
            }
        }
        headerRow.addView(badgeView)

        // Spacer
        val spacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1.0f)
        }
        headerRow.addView(spacer)

        // Size Adjustment Toggle Button (Compact vs Expanded)
        val sizeBtn = TextView(this).apply {
            text = if (isCompactSize) "⤢" else "⤡"
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding((6 * density).toInt(), (4 * density).toInt(), (6 * density).toInt(), (4 * density).toInt())
            setOnClickListener {
                isCompactSize = !isCompactSize
                text = if (isCompactSize) "⤢" else "⤡"
                val curScreenH = resources.displayMetrics.heightPixels
                val targetHeight = if (isCompactSize) (310 * density).toInt() else (460 * density).toInt()
                pParams.height = targetHeight.coerceAtMost(curScreenH - (50 * density).toInt())
                try {
                    windowManager?.updateViewLayout(panelContainer, pParams)
                } catch (_: Exception) {}
            }
        }
        headerRow.addView(sizeBtn)

        // Open Full App button (↗)
        val openAppBtn = TextView(this).apply {
            text = "↗"
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding((6 * density).toInt(), (4 * density).toInt(), (6 * density).toInt(), (4 * density).toInt())
            setOnClickListener {
                openFullApp(openCreateTask = false)
            }
        }
        headerRow.addView(openAppBtn)

        // Close / Minimize Panel button (✕)
        val closeBtn = TextView(this).apply {
            text = "✕"
            setTextColor(Color.parseColor("#EF4444"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding((6 * density).toInt(), (4 * density).toInt(), (6 * density).toInt(), (4 * density).toInt())
            setOnClickListener {
                hideFloatingPanel()
            }
        }
        headerRow.addView(closeBtn)

        mainLayout.addView(headerRow)

        // 2. Task List Scroll View
        val scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1.0f
            )
            isFillViewport = true
        }

        val taskListLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        scrollView.addView(taskListLayout)
        mainLayout.addView(scrollView)

        // Refresh Tasks Function (Invoked in real time)
        fun refreshTaskList() {
            taskListLayout.removeAllViews()
            val tasks = loadPendingTasks()
            badgeView.text = tasks.size.toString()

            if (tasks.isEmpty()) {
                val emptyView = TextView(this).apply {
                    text = "No pending tasks 🎉"
                    setTextColor(Color.parseColor("#64748B"))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                    gravity = Gravity.CENTER
                    setPadding(0, (30 * density).toInt(), 0, (20 * density).toInt())
                }
                taskListLayout.addView(emptyView)

                // Direct button to create new task in full app
                val createFirstBtn = Button(this).apply {
                    text = "+ Create First Task"
                    setTextColor(Color.WHITE)
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                    val bBg = GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = 8 * density
                        setColor(Color.parseColor("#2563EB"))
                    }
                    background = bBg
                    val lp = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        (36 * density).toInt()
                    ).apply {
                        gravity = Gravity.CENTER_HORIZONTAL
                    }
                    layoutParams = lp
                    setOnClickListener {
                        openFullApp(openCreateTask = true)
                    }
                }
                taskListLayout.addView(createFirstBtn)
                return
            }

            for (task in tasks) {
                val row = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    val rPad = (8 * density).toInt()
                    setPadding(rPad, (8 * density).toInt(), rPad, (8 * density).toInt())
                    val rowBg = GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = 8 * density
                        setColor(Color.parseColor("#1C2333"))
                    }
                    background = rowBg
                    val lp = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        bottomMargin = (6 * density).toInt()
                    }
                    layoutParams = lp
                }

                // Checkbox / Circle Button (ONLY THIS COMPLETES TASK!)
                val checkCircle = TextView(this).apply {
                    text = "○"
                    setTextColor(Color.parseColor("#3880FF"))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
                    typeface = Typeface.DEFAULT_BOLD
                    val pad = (6 * density).toInt()
                    setPadding(pad, pad, pad, pad)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        marginEnd = (6 * density).toInt()
                    }
                    // ONLY CLICKING CHECKBOX COMPLETES!
                    setOnClickListener {
                        text = "✓"
                        setTextColor(Color.parseColor("#10B981"))
                        mainHandler.postDelayed({
                            completeTask(task.id)
                            refreshTaskList()
                        }, 180)
                    }
                }
                row.addView(checkCircle)

                // Task Title (Clicking opens the task in the full app instead of completing!)
                val titleTv = TextView(this).apply {
                    text = task.title
                    setTextColor(Color.parseColor("#F1F5F9"))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 13.5f)
                    maxLines = 2
                    ellipsize = TextUtils.TruncateAt.END
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
                    setOnClickListener {
                        openFullApp(openCreateTask = false)
                    }
                }
                row.addView(titleTv)

                // Priority Indicator dot if medium/high
                if (task.priority >= 2) {
                    val priorityDot = View(this).apply {
                        val dotSize = (8 * density).toInt()
                        val pBg = GradientDrawable().apply {
                            shape = GradientDrawable.OVAL
                            setColor(if (task.priority == 3) Color.parseColor("#EF4444") else Color.parseColor("#F59E0B"))
                        }
                        background = pBg
                        layoutParams = LinearLayout.LayoutParams(dotSize, dotSize).apply {
                            marginStart = (6 * density).toInt()
                            marginEnd = (4 * density).toInt()
                        }
                    }
                    row.addView(priorityDot)
                }

                taskListLayout.addView(row)
            }
        }

        refreshTaskListCallback = {
            if (isPanelOpen) {
                refreshTaskList()
            }
        }

        // Initial task load
        refreshTaskList()

        // 3. Quick-Add / Create Page Action Row at Bottom
        val inputRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val topM = (8 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = topM
            }
        }

        val inputEdit = EditText(this).apply {
            hint = "Add quick task or tap + for full create..."
            setHintTextColor(Color.parseColor("#64748B"))
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            imeOptions = EditorInfo.IME_ACTION_DONE
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            val pad = (10 * density).toInt()
            setPadding(pad, pad, pad, pad)
            val iBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 10 * density
                setColor(Color.parseColor("#1C2333"))
            }
            background = iBg
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
        }
        inputRow.addView(inputEdit)

        // Action Button (+): If text entered, quickly creates; if empty, directly opens full Create Page!
        val addBtn = TextView(this).apply {
            text = "+"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            val aBg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 10 * density
                setColor(Color.parseColor("#3880FF"))
            }
            background = aBg
            val bSize = (38 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(bSize, bSize).apply {
                marginStart = (8 * density).toInt()
            }
            setOnClickListener {
                val t = inputEdit.text.toString().trim()
                if (t.isNotEmpty()) {
                    createTask(t)
                    inputEdit.setText("")
                    refreshTaskList()
                } else {
                    // Direct open full create page when clicking + on empty input!
                    openFullApp(openCreateTask = true)
                }
            }
        }
        inputRow.addView(addBtn)

        inputEdit.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                val t = inputEdit.text.toString().trim()
                if (t.isNotEmpty()) {
                    createTask(t)
                    inputEdit.setText("")
                    refreshTaskList()
                } else {
                    openFullApp(openCreateTask = true)
                }
                true
            } else {
                false
            }
        }

        mainLayout.addView(inputRow)
        root.addView(mainLayout)

        panelContainer = root

        try {
            // Hide small bubble while panel is displayed
            bubbleContainer?.visibility = View.GONE
            windowManager?.addView(panelContainer, panelParams)
            isPanelOpen = true
        } catch (_: Exception) {
            bubbleContainer?.visibility = View.VISIBLE
        }
    }

    private fun hideFloatingPanel() {
        if (!isPanelOpen || windowManager == null) return
        panelContainer?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        panelContainer = null
        refreshTaskListCallback = null
        isPanelOpen = false
        bubbleContainer?.visibility = View.VISIBLE
    }

    private fun openFullApp(openCreateTask: Boolean = false) {
        hideFloatingPanel()
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            if (openCreateTask) {
                putExtra("open_create_task", true)
            }
        } ?: Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            if (openCreateTask) {
                putExtra("open_create_task", true)
            }
        }
        try {
            startActivity(launchIntent)
        } catch (_: Exception) {}
    }

    private fun getDb(): SQLiteDatabase? {
        val dbFile = File(filesDir, "synctask.db")
        if (!dbFile.exists()) return null
        return try {
            SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READWRITE)
        } catch (_: Exception) {
            null
        }
    }

    private fun loadPendingTasks(): List<OverlayTask> {
        val list = mutableListOf<OverlayTask>()
        val db = getDb() ?: return list
        try {
            val cursor = db.rawQuery(
                "SELECT id, title, priority FROM tasks WHERE completed = 0 AND deleted = 0 ORDER BY priority DESC, created_at DESC LIMIT 30",
                null
            )
            while (cursor.moveToNext()) {
                val id = cursor.getString(0)
                val title = cursor.getString(1)
                val priority = cursor.getInt(2)
                list.add(OverlayTask(id, title, priority))
            }
            cursor.close()
        } catch (_: Exception) {
        } finally {
            db.close()
        }
        return list
    }

    private fun completeTask(taskId: String) {
        val db = getDb() ?: return
        val now = System.currentTimeMillis()
        try {
            db.execSQL("UPDATE tasks SET completed = 1, updated_at = ? WHERE id = ?", arrayOf<Any>(now, taskId))
            var deviceId = "local"
            val cursor = db.rawQuery("SELECT value FROM meta WHERE key = 'device_id'", null)
            if (cursor.moveToFirst()) {
                deviceId = cursor.getString(0)
            }
            cursor.close()

            db.execSQL(
                "INSERT INTO change_log (task_id, op, revision, device_id, at, synced) VALUES (?, 'update', 0, ?, ?, 0)",
                arrayOf<Any>(taskId, deviceId, now)
            )
        } catch (_: Exception) {
        } finally {
            db.close()
        }
    }

    private fun createTask(title: String) {
        if (title.isBlank()) return
        val db = getDb() ?: return
        val now = System.currentTimeMillis()
        val taskId = UUID.randomUUID().toString()
        try {
            var deviceId = "local"
            val cursor = db.rawQuery("SELECT value FROM meta WHERE key = 'device_id'", null)
            if (cursor.moveToFirst()) {
                deviceId = cursor.getString(0)
            }
            cursor.close()

            db.execSQL(
                "INSERT INTO tasks (id, title, notes, due_at, priority, category, completed, recurrence, created_at, updated_at, revision, device_id, deleted) VALUES (?, ?, '', NULL, 1, '', 0, 'none', ?, ?, 0, ?, 0)",
                arrayOf<Any>(taskId, title.trim(), now, now, deviceId)
            )
            db.execSQL(
                "INSERT INTO change_log (task_id, op, revision, device_id, at, synced) VALUES (?, 'create', 0, ?, ?, 0)",
                arrayOf<Any>(taskId, deviceId, now)
            )
        } catch (_: Exception) {
        } finally {
            db.close()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        hideFloatingPanel()
        try {
            dbFileObserver?.stopWatching()
        } catch (_: Exception) {}
        dbFileObserver = null
        bubbleContainer?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        bubbleContainer = null
        isRunning = false
        if (instance == this) {
            instance = null
        }
    }
}
