package com.example.jitu

import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.accessibilityservice.AccessibilityService

/**
 * 支付页面识别无障碍服务。
 *
 * WHY: 部分用户的微信/支付宝不推送支付通知（通知被关闭或系统限制），
 * 通知监听通道完全失效。本服务作为补充通道：监听微信/支付宝窗口事件，
 * 遍历节点树收集页面文本，命中"支付成功"类关键词后解析金额/商户，
 * 复用与通知监听相同的路由（Flutter attached → EventChannel；
 * 否则 → OverlayService 悬浮窗 / 拉起 MainActivity 待确认）。
 */
class PaymentAccessibilityService : AccessibilityService() {

    companion object {
        // WHY: 正则在 companion 中预编译一次，避免高频事件回调重复创建（遵循"循环内禁止重复创建正则"规则）
        // 金额正则 A：符号在数字后，如 "12.34元"、"12.5 ￥"
        private val amountSuffixRegex = Regex("(\\d+(?:\\.\\d{1,2})?)\\s*(?:元|￥|¥)")
        // 金额正则 B：符号在数字前，如 "¥12.50"、"￥ 0.01"（支付成功页主流展示形式）
        private val amountPrefixRegex = Regex("(?:￥|¥)\\s*(\\d+(?:\\.\\d{1,2})?)")

        // 商户正则：覆盖"在XX消费/收款方：XX/向XX付款/付款给XX/XX的收款码"等常见模板
        private val merchantRegex =
            Regex("在(.+?)消费|收款方[:：]?\\s*(.+?)$|向(.+?)付款|付款给(.+?)$")

        // 支付成功页关键词：命中其一才判定为支付成功事件，避免首页/账单列表误触发
        private val successKeywords = listOf(
            "支付成功", "付款成功", "转账成功", "支付完成", "扣款成功", "交易成功"
        )

        // WHY: 收入类成功页关键词（收款/到账），与支出关键词分开判定收支方向
        private val incomeSuccessKeywords = listOf(
            "收款成功", "收款到账", "转账到账"
        )

        /**
         * 检查无障碍服务是否已在系统设置中开启。
         *
         * @param context 任意可用 Context。
         * @return true 表示本应用的无障碍服务已授权。
         */
        fun isServiceEnabled(context: android.content.Context): Boolean {
            val enabledServices = android.provider.Settings.Secure.getString(
                context.contentResolver,
                android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            val expectedComponent = android.content.ComponentName(
                context,
                PaymentAccessibilityService::class.java
            ).flattenToString()
            return enabledServices.split(':').any {
                android.content.ComponentName.unflattenFromString(it)?.let { cn ->
                    cn.packageName == expectedComponent.split('/')[0] &&
                        cn.className == expectedComponent.split('/')[1]
                } == true || it.contains(expectedComponent)
            }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        // 只处理窗口状态变化与内容变化（config 中已限定包名，此处双保险）
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        ) return

        // WHY: 纯 Service 进程下 Flutter 引擎从未 attach，appContext 为 null
        // 会导致悬浮窗结果无法回传，此处兜底缓存上下文
        AutoAccountingPlugin.ensureAppContext(this)

        val root = rootInActiveWindow ?: return
        val textBuilder = StringBuilder()
        collectNodeText(root, textBuilder, 0)
        root.recycle()

        val combined = textBuilder.toString()
        if (combined.isBlank()) return

        // 命中支付/收款成功关键词才继续，O(k)，k 为关键词数量（常量级）
        val isIncomePage = incomeSuccessKeywords.any { combined.contains(it) }
        val isSuccessPage =
            isIncomePage || successKeywords.any { combined.contains(it) }
        if (!isSuccessPage) return

        // WHY: 跨通道统一去重——用「包名+金额」替代旧的整页文本 hashCode 签名。
        // 旧签名在页面动画/倒计时/节点懒加载导致文本微变时即失效，同一支付页
        // 停留期间会绕过窗口限制重复弹窗；金额在同一笔支付中是稳定值，
        // 且与通知监听通道共享同一去重表，杜绝双通道重复弹窗（60 秒窗口）
        val pkg = event.packageName?.toString() ?: ""
        val dedupAmount = extractAmount(combined)
        if (!AutoAccountingPlugin.shouldProcessEvent(pkg, dedupAmount)) return

        routePaymentEvent(pkg, combined, isIncomePage)
    }

    /**
     * 递归遍历节点树收集所有可见文本。
     *
     * WHY: 支付成功页的金额/商户分散在不同 TextView 节点中，
     * 需全树遍历拼接后统一解析；深度限制防止异常深层树导致栈溢出。
     * 时间复杂度：O(n)，n 为节点数
     *
     * @param node 当前节点。
     * @param builder 文本收集容器。
     * @param depth 当前递归深度（上限 32 层）。
     */
    private fun collectNodeText(
        node: AccessibilityNodeInfo?,
        builder: StringBuilder,
        depth: Int
    ) {
        if (node == null || depth > 32) return
        val text = node.text?.toString()
        if (!text.isNullOrBlank()) {
            if (builder.isNotEmpty()) builder.append(' ')
            builder.append(text)
        }
        // WHY: contentDescription 也可能承载金额（部分页面用图标+描述）
        val desc = node.contentDescription?.toString()
        if (!desc.isNullOrBlank()) {
            builder.append(' ').append(desc)
        }
        for (i in 0 until node.childCount) {
            collectNodeText(node.getChild(i), builder, depth + 1)
        }
    }

    /**
     * 将捕获的支付成功事件路由到 Flutter 或原生悬浮窗（与通知监听同构）。
     *
     * @param packageName 事件来源包名（微信/支付宝）。
     * @param combined 支付成功页拼接文本。
     * @param isIncome true 表示收入（收款/到账类页面）。
     */
    private fun routePaymentEvent(
        packageName: String,
        combined: String,
        isIncome: Boolean
    ) {
        if (AutoAccountingPlugin.isFlutterAttached()) {
            // Flutter attached：走 EventChannel，由 Dart 侧 NotificationParserService 解析
            // WHY: 收支方向 Dart 解析器会从文本独立识别（关键词同构），无需额外透传
            AutoAccountingPlugin.sendPaymentEvent(
                packageName = packageName,
                combined = combined,
                postTime = System.currentTimeMillis()
            )
            return
        }

        // Flutter 未 attached：原生侧简化解析后走悬浮窗/待确认回退路径
        val parsedAmount = extractAmount(combined)
        val parsedMerchant = extractMerchant(combined)
        if (AutoAccountingPlugin.isOverlayEnabled(this)) {
            val intent = Intent(this, OverlayService::class.java).apply {
                putExtra(OverlayService.EXTRA_PACKAGE, packageName)
                putExtra(OverlayService.EXTRA_RAW_TEXT, combined)
                putExtra(OverlayService.EXTRA_MERCHANT, parsedMerchant)
                putExtra(OverlayService.EXTRA_AMOUNT, parsedAmount)
                putExtra(OverlayService.EXTRA_IS_INCOME, isIncome)
            }
            startService(intent)
        } else {
            android.util.Log.w(
                "PaymentA11y",
                "悬浮窗权限未授权，回退到拉起 MainActivity 生成待确认记录"
            )
            AutoAccountingPlugin.handleOverlayResult(
                action = "pending",
                amount = parsedAmount,
                merchant = parsedMerchant,
                packageName = packageName,
                category = null,
                account = null,
                rawText = combined,
                isIncome = isIncome
            )
        }
    }

    /**
     * 从支付成功页文本中提取金额。
     *
     * WHY: 优先匹配"符号在前"形式（¥12.50，支付成功页主流），
     * 其次匹配"符号在后"形式（12.34元），与通知解析口径互补。
     *
     * @param text 页面拼接文本。
     * @return 解析到的金额；失败返回 0.0。
     */
    private fun extractAmount(text: String): Double {
        amountPrefixRegex.find(text)?.groupValues?.get(1)?.toDoubleOrNull()
            ?.let { return it }
        return amountSuffixRegex.find(text)?.groupValues?.get(1)?.toDoubleOrNull() ?: 0.0
    }

    /**
     * 从支付成功页文本中提取商户名。
     *
     * @param text 页面拼接文本。
     * @return 解析到的商户名；失败返回空字符串。
     */
    private fun extractMerchant(text: String): String {
        val match = merchantRegex.find(text) ?: return ""
        // WHY: groupValues[0] 是整体匹配，从 index 1 起取首个非空捕获组
        return match.groupValues.drop(1).firstOrNull { it.isNotEmpty() }?.trim() ?: ""
    }

    override fun onInterrupt() {
        // WHY: 服务被系统中断时无需处理，下次窗口事件会自动恢复
    }
}
