package com.example.jitu

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.text.InputType
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import kotlin.math.abs

/**
 * 后台支付记账悬浮窗 Service。
 *
 * WHY: 当应用在后台且 Flutter 未 attached 时，由 PaymentNotificationListener 启动本 Service，
 * 通过 WindowManager 在屏幕顶部显示原生悬浮窗，用户可直接在悬浮窗完成记账，无需拉起 Flutter。
 *
 * 设计要点：
 * - 作为 Foreground Service 保活，避免被系统回收。
 * - 悬浮窗 View 用代码构建（不用 XML），保持模块内聚。
 * - 用户操作完成后通过 [AutoAccountingPlugin.handleOverlayResult] 回调 Flutter。
 */
class OverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "jitu_overlay_channel"
        private const val NOTIFICATION_ID = 1001

        // WHY: Intent extra keys，与 PaymentNotificationListener 传递数据约定
        const val EXTRA_AMOUNT = "amount"
        const val EXTRA_MERCHANT = "merchant"
        const val EXTRA_PACKAGE = "packageName"
        const val EXTRA_INFERRED_CATEGORY = "inferredCategory"
        const val EXTRA_CONFIDENCE = "confidence"
        const val EXTRA_RAW_TEXT = "rawText"
        // WHY: 收支方向标志（收入=true），由通知监听/无障碍服务识别后传入
        const val EXTRA_IS_INCOME = "isIncome"
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var amount: Double = 0.0
    private var merchant: String = ""
    private var packageName: String = ""
    private var inferredCategory: String? = null
    private var confidence: Double = 0.0
    private var rawText: String = ""
    private var isIncome: Boolean = false
    private var selectedCategory: String? = null
    private var selectedAccount: String? = null

    // WHY: 金额/商户改为可编辑 EditText，确认时从控件读取用户修改后的值
    private var amountEdit: EditText? = null
    private var merchantEdit: EditText? = null

    // WHY: 确认结果只回传一次——用户双击确认按钮或 Service 销毁延迟时，
    // 防止同一笔支付被重复回传导致重复记账
    private var confirmHandled = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        // WHY: 纯 Service 进程（系统拉起）下 Flutter 引擎从未 attach，
        // appContext 为 null 会导致悬浮窗结果无法回传，此处兜底缓存上下文
        AutoAccountingPlugin.ensureAppContext(this)
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildForegroundNotification())
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    /**
     * 处理启动命令，解析 Intent extra 获取支付数据并显示悬浮窗。
     *
     * @param intent 携带支付数据的 Intent，extra keys 见 [companion object] 中常量。
     * @param flags 启动标志位，透传给父类。
     * @param startId 启动 ID，透传给父类。
     * @return 启动模式，返回 [START_NOT_STICKY]，被杀后不自动重启。
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.let {
            amount = it.getDoubleExtra(EXTRA_AMOUNT, 0.0)
            merchant = it.getStringExtra(EXTRA_MERCHANT) ?: ""
            packageName = it.getStringExtra(EXTRA_PACKAGE) ?: ""
            inferredCategory = it.getStringExtra(EXTRA_INFERRED_CATEGORY)
            confidence = it.getDoubleExtra(EXTRA_CONFIDENCE, 0.0)
            rawText = it.getStringExtra(EXTRA_RAW_TEXT) ?: ""
            isIncome = it.getBooleanExtra(EXTRA_IS_INCOME, false)
            // WHY: 新支付事件到达时重置确认标志，允许新一笔支付的确认操作
            confirmHandled = false
            // WHY: 进程被杀后内存缓存丢失，先从 SharedPreferences 恢复，
            // 否则分类/账户 Chip 显示"暂无数据"导致无法修改分类
            AutoAccountingPlugin.restoreCacheIfNeeded(this)
            selectedCategory = inferredCategory
            // WHY: 推断分类缺失时兜底选第一个，保证用户可在此基础上修改
            if (selectedCategory == null) {
                selectedCategory =
                    AutoAccountingPlugin.getCachedCategories().firstOrNull()?.get("name")
            }
            // WHY: 默认选第一个账户，提升确认速度
            if (selectedAccount == null) {
                selectedAccount =
                    AutoAccountingPlugin.getCachedAccounts().firstOrNull()?.get("name")
            }
            showOverlay()
        }
        return START_NOT_STICKY
    }

    /**
     * 创建低优先级通知通道，用于前台 Service 通知。
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "记途支付监听",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "后台监听支付通知并自动记账"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    /**
     * 构建前台 Service 通知。
     *
     * @return 低优先级、常驻的前台通知 [Notification]。
     */
    private fun buildForegroundNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("记途")
            .setContentText("正在后台监听支付通知")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    /**
     * 显示悬浮窗：先移除已有 View，再通过 WindowManager 添加新 View。
     * WHY: 先移除避免重复添加导致异常。
     */
    @android.annotation.SuppressLint("ClickableViewAccessibility")
    private fun showOverlay() {
        removeOverlay()

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dpToPx(100)
        }

        layoutParams = params
        overlayView = buildOverlayView()
        attachDragListener(overlayView!!)
        windowManager?.addView(overlayView, params)
    }

    /**
     * 为悬浮窗绑定拖动监听器，实现顶部悬浮窗可拖动。
     * WHY: 用户可调整悬浮窗位置以避开当前操作区域。
     *
     * @param view 待绑定拖动监听的 View。
     */
    @android.annotation.SuppressLint("ClickableViewAccessibility")
    private fun attachDragListener(view: View) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var moved = false

        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = layoutParams?.x ?: 0
                    initialY = layoutParams?.y ?: 0
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    moved = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - initialTouchX
                    val dy = event.rawY - initialTouchY
                    // WHY: 超过 10px 才视为拖动，避免误触屏蔽点击
                    if (abs(dx) > 10 || abs(dy) > 10) moved = true
                    layoutParams?.let { lp ->
                        lp.x = initialX + dx.toInt()
                        lp.y = initialY + dy.toInt()
                        windowManager?.updateViewLayout(view, lp)
                    }
                }
                MotionEvent.ACTION_UP -> {
                    // WHY: 若发生拖动则消费事件，避免触发内部点击
                    if (moved) return@setOnTouchListener true
                }
            }
            false
        }
    }

    /**
     * 构建悬浮窗 View 树（代码构建，不使用 XML）。
     *
     * @return 悬浮窗根 [View]，包含标题、金额、商户、分类/账户选择、操作按钮。
     */
    private fun buildOverlayView(): View {
        val context = this
        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.WHITE)
            // WHY: 用代码设置圆角和阴影背景
            background = createCardBackground()
            setPadding(dpToPx(20), dpToPx(20), dpToPx(20), dpToPx(20))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        // 标题行
        val titleRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val titleText = TextView(context).apply {
            text = "记途检测到支付"
            setTextColor(Color.parseColor("#6366F1"))
            textSize = 16f
            setTypeface(typeface, Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        val closeBtn = TextView(context).apply {
            text = "×"
            setTextColor(Color.parseColor("#9CA3AF"))
            textSize = 24f
            setPadding(dpToPx(8), 0, dpToPx(8), 0)
            setOnClickListener { stopSelf() }
        }
        titleRow.addView(titleText)
        titleRow.addView(closeBtn)
        container.addView(titleRow)

        // 金额（可编辑）
        val amountRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.BOTTOM
            setPadding(0, dpToPx(12), 0, dpToPx(4))
        }
        val currencyText = TextView(context).apply {
            text = "¥ "
            setTextColor(Color.parseColor("#6366F1"))
            textSize = 32f
            setTypeface(typeface, Typeface.BOLD)
        }
        val amountField = EditText(context).apply {
            setText(String.format("%.2f", amount))
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
            setTextColor(Color.parseColor("#6366F1"))
            textSize = 32f
            setTypeface(typeface, Typeface.BOLD)
            // WHY: 去掉默认下划线背景，保持卡片简洁风格
            setBackgroundColor(Color.TRANSPARENT)
            setSelectAllOnFocus(true)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        enableKeyboardOnFocus(amountField)
        amountEdit = amountField
        amountRow.addView(currencyText)
        amountRow.addView(amountField)
        container.addView(amountRow)

        // 商户名（可编辑，始终展示便于补录）
        val merchantField = EditText(context).apply {
            setText(merchant)
            hint = "商户（可修改）"
            setHintTextColor(Color.parseColor("#D1D5DB"))
            inputType = InputType.TYPE_CLASS_TEXT
            setTextColor(Color.parseColor("#6B7280"))
            textSize = 14f
            setBackgroundColor(Color.TRANSPARENT)
            setPadding(0, 0, 0, dpToPx(16))
        }
        enableKeyboardOnFocus(merchantField)
        merchantEdit = merchantField
        container.addView(merchantField)

        // 分类标签
        val categoryLabel = TextView(context).apply {
            text = "分类"
            setTextColor(Color.parseColor("#6B7280"))
            textSize = 12f
        }
        container.addView(categoryLabel)
        val categoryRow = buildChipRow(
            AutoAccountingPlugin.getCachedCategories(),
            inferredCategory,
            onSelect = { selectedCategory = it }
        )
        container.addView(categoryRow)

        // 账户标签
        val accountLabel = TextView(context).apply {
            text = "账户"
            setTextColor(Color.parseColor("#6B7280"))
            textSize = 12f
            setPadding(0, dpToPx(12), 0, 0)
        }
        container.addView(accountLabel)
        val accountRow = buildChipRow(
            AutoAccountingPlugin.getCachedAccounts(),
            selectedAccount,
            onSelect = { selectedAccount = it }
        )
        container.addView(accountRow)

        // 操作按钮行
        val btnRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dpToPx(20), 0, 0)
        }
        val ignoreBtn = Button(context).apply {
            text = "忽略"
            setBackgroundColor(Color.TRANSPARENT)
            setTextColor(Color.parseColor("#6B7280"))
            textSize = 14f
            val lp = LinearLayout.LayoutParams(0, dpToPx(44), 1f)
            lp.setMargins(0, 0, dpToPx(8), 0)
            layoutParams = lp
            setOnClickListener { handleIgnore() }
        }
        val confirmBtn = Button(context).apply {
            text = "确认记账"
            setBackgroundColor(Color.parseColor("#6366F1"))
            setTextColor(Color.WHITE)
            textSize = 14f
            val lp = LinearLayout.LayoutParams(0, dpToPx(44), 2f)
            layoutParams = lp
            setOnClickListener { handleConfirm() }
        }
        btnRow.addView(ignoreBtn)
        btnRow.addView(confirmBtn)
        container.addView(btnRow)

        return container
    }

    /**
     * 让悬浮窗内的 EditText 聚焦时可弹出软键盘。
     *
     * WHY: 悬浮窗默认带 FLAG_NOT_FOCUSABLE（避免抢下层应用的返回键与焦点），
     * 该 flag 会阻断 IME。聚焦时动态移除、失焦后恢复，兼顾两者。
     *
     * @param editText 目标输入框。
     */
    private fun enableKeyboardOnFocus(editText: EditText) {
        editText.setOnFocusChangeListener { _, hasFocus ->
            val lp = layoutParams ?: return@setOnFocusChangeListener
            val view = overlayView ?: return@setOnFocusChangeListener
            lp.flags = if (hasFocus) {
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            } else {
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            }
            windowManager?.updateViewLayout(view, lp)
            if (hasFocus) {
                // WHY: flag 切换后需下一帧再请求 IME，否则系统仍认为窗口不可聚焦
                editText.post {
                    val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.showSoftInput(editText, InputMethodManager.SHOW_IMPLICIT)
                }
            }
        }
    }

    /**
     * 构建 Chip 选择行（横向滚动，展示全部条目）。
     *
     * WHY: 外层套 HorizontalScrollView 突破"最多 5 个"限制，
     * 用户可选择任意分类/账户；横向滑动手势由 ScrollView 消费，
     * 与根 View 的拖动监听天然隔离。
     *
     * @param items 待渲染的数据列表，每个 Map 至少含 `name` 字段。
     * @param selected 当前选中项名称，用于初始高亮。
     * @param onSelect 选中回调，参数为被点击项的 `name`。
     * @return 横向可滚动的 Chip 容器。
     */
    private fun buildChipRow(
        items: List<Map<String, String>>,
        selected: String?,
        onSelect: (String) -> Unit
    ): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dpToPx(4), 0, 0)
        }
        if (items.isEmpty()) {
            val empty = TextView(this).apply {
                text = "暂无数据"
                setTextColor(Color.parseColor("#EF4444"))
                textSize = 12f
            }
            row.addView(empty)
        } else {
            // WHY: 展示全部条目，时间复杂度 O(n)
            items.forEach { item ->
                val name = item["name"] ?: return@forEach
                val chip = TextView(this).apply {
                    text = name
                    val isSelected = name == selected
                    setBackgroundColor(
                        if (isSelected) Color.parseColor("#6366F1")
                        else Color.parseColor("#F3F4F6")
                    )
                    setTextColor(
                        if (isSelected) Color.WHITE
                        else Color.parseColor("#374151")
                    )
                    textSize = 13f
                    setPadding(dpToPx(12), dpToPx(6), dpToPx(12), dpToPx(6))
                    val lp = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    )
                    lp.setMargins(0, 0, dpToPx(8), 0)
                    layoutParams = lp
                    setOnClickListener {
                        onSelect(name)
                        // WHY: 局部刷新 Chip 选中色，不重建整个悬浮窗，
                        // 避免重建导致金额/商户输入框内容被重置
                        refreshChipSelection(row, name)
                    }
                }
                row.addView(chip)
            }
        }
        return HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            addView(row)
        }
    }

    /**
     * 局部刷新 Chip 行的选中态颜色。
     *
     * @param row Chip 所在 LinearLayout。
     * @param selectedName 当前选中的名称。
     */
    private fun refreshChipSelection(row: LinearLayout, selectedName: String) {
        // WHY: 时间复杂度 O(n)，n 为分类/账户数量，通常 < 30
        for (i in 0 until row.childCount) {
            val child = row.getChildAt(i) as? TextView ?: continue
            val isSelected = child.text.toString() == selectedName
            child.setBackgroundColor(
                if (isSelected) Color.parseColor("#6366F1")
                else Color.parseColor("#F3F4F6")
            )
            child.setTextColor(
                if (isSelected) Color.WHITE
                else Color.parseColor("#374151")
            )
        }
    }

    /**
     * 创建卡片背景 Drawable（白色 + 16dp 圆角 + 细边框）。
     *
     * @return 配置好的 [GradientDrawable]。
     */
    private fun createCardBackground(): GradientDrawable {
        return GradientDrawable().apply {
            setColor(Color.WHITE)
            cornerRadius = dpToPx(16).toFloat()
            // WHY: 模拟卡片阴影边框
            setStroke(1, Color.parseColor("#E5E7EB"))
        }
    }

    /**
     * 处理"确认记账"：通过 [AutoAccountingPlugin.handleOverlayResult] 回调 Flutter，然后关闭 Service。
     */
    private fun handleConfirm() {
        // WHY: 双击防护——确认结果只回传一次，防止同一笔支付重复记账
        if (confirmHandled) return
        confirmHandled = true
        // WHY: 金额/商户以用户修改后的输入框内容为准；解析失败回退原始识别值
        val finalAmount = amountEdit?.text?.toString()
            ?.replace(",", "")
            ?.toDoubleOrNull()
            ?.takeIf { it > 0 } ?: amount
        val finalMerchant = merchantEdit?.text?.toString()?.trim()
            .orEmpty()
            .ifEmpty { merchant }
        AutoAccountingPlugin.handleOverlayResult(
            action = "confirm",
            amount = finalAmount,
            merchant = finalMerchant,
            packageName = packageName,
            category = selectedCategory,
            account = selectedAccount,
            rawText = rawText,
            isIncome = isIncome
        )
        stopSelf()
    }

    /**
     * 处理"忽略"：通过 [AutoAccountingPlugin.handleOverlayResult] 回调 Flutter 忽略事件，然后关闭 Service。
     */
    private fun handleIgnore() {
        AutoAccountingPlugin.handleOverlayResult(
            action = "ignore",
            amount = amount,
            merchant = merchant,
            packageName = packageName,
            category = null,
            account = null,
            rawText = rawText,
            isIncome = isIncome
        )
        stopSelf()
    }

    /**
     * 移除悬浮窗 View，吞掉可能抛出的异常（View 未附加等情况）。
     */
    private fun removeOverlay() {
        overlayView?.let {
            try {
                windowManager?.removeView(it)
            } catch (e: Exception) {
                // WHY: 忽略移除异常，避免重复移除导致崩溃
            }
            overlayView = null
        }
        layoutParams = null
        // WHY: 清空输入框引用，防止悬浮窗重建后读到已销毁的 View
        amountEdit = null
        merchantEdit = null
    }

    override fun onDestroy() {
        removeOverlay()
        super.onDestroy()
    }

    /**
     * dp 转 px 工具方法。
     *
     * @param dp 密度无关像素值。
     * @return 转换后的物理像素值。
     */
    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}
