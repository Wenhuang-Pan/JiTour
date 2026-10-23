package com.example.jitu

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class PaymentNotificationListener : NotificationListenerService() {

    companion object {
        // WHY: 正则在 companion 中预编译一次，避免每次通知重复创建（遵循"循环内禁止重复创建正则"规则）
        // 金额正则：匹配 "12.34元"、"¥12"、"￥12.5" 等常见支付金额格式
        private val amountRegex = Regex("(\\d+(?:\\.\\d{1,2})?)\\s*(?:元|￥|¥)")

        // 商户正则：匹配 "在XX消费"、"收款方：XX"、"向XX付款"、"付款给XX" 等常见格式
        private val merchantRegex = Regex("在(.+?)消费|收款方[:：]\\s*(.+?)$|向(.+?)付款|付款给(.+?)$")
    }

    // 只处理这两个包名的通知，避免其他应用通知误触发
    private val targetPackages = setOf(
        "com.eg.android.AlipayGphone", // 支付宝
        "com.tencent.mm"               // 微信
    )

    // 关键词过滤，避免同一 App 的非支付类通知误触发
    private val paymentKeywords = listOf(
        "支付", "付款", "消费", "转账", "收款", "支出", "扣款",
        "账单", "订单", "元", "¥", "￥"
    )

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        // WHY: 纯 Service 进程下 Flutter 引擎从未 attach，appContext 为 null
        // 会导致悬浮窗结果无法回传，此处兜底缓存上下文
        AutoAccountingPlugin.ensureAppContext(this)

        val packageName = sbn.packageName
        if (packageName !in targetPackages) return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString()
            ?: extras.getCharSequence("android.bigText")?.toString() ?: ""

        // 空文本直接跳过
        if (title.isBlank() && text.isBlank()) return

        // 拼接 title + text，组合后的内容供 Dart 侧正则解析金额和商户
        val combined = buildString {
            if (title.isNotBlank()) append(title)
            if (text.isNotBlank()) {
                if (this.isNotBlank()) append(" ")
                append(text)
            }
        }

        // 只有包含支付关键词才推送，降低误报率
        // WHY: 时间复杂度 O(k)，k 为关键词数量（常量级）
        val shouldTrigger = paymentKeywords.any { combined.contains(it) }
        if (!shouldTrigger) return

        // WHY: 跨通道统一去重——同一笔支付若同时被无障碍服务捕获，
        // 两条通道独立触发会造成重复弹窗/重复记账；金额在同一笔支付中稳定，
        // 与无障碍通道共享同一去重表（包名+金额，60 秒窗口）
        val parsedAmount = extractAmount(combined)
        if (!AutoAccountingPlugin.shouldProcessEvent(packageName, parsedAmount)) return

        // WHY: 根据 Flutter 是否 attached 决定推送方式
        // - attached（应用在前台/后台保活）→ 推送给 Flutter，由 QuickEntryOverlay 弹窗
        // - not attached（应用被杀）→ 启动 OverlayService 显示原生悬浮窗
        if (AutoAccountingPlugin.isFlutterAttached()) {
            // 现有逻辑：推送给 Flutter
            AutoAccountingPlugin.sendPaymentEvent(
                packageName = packageName,
                combined = combined,
                postTime = sbn.postTime
            )
        } else {
            // WHY: Flutter 未 attached 时，根据悬浮窗权限决定路径：
            // - 已授权悬浮窗 → 启动 OverlayService 显示原生悬浮窗
            // - 未授权悬浮窗 → 以 pending 动作走 handleOverlayResult，写入
            //   补录队列并创建 headless 引擎后台落库（不唤起任何窗口），
            //   Flutter 启动后由 AutoAccountingProvider 处理
            val parsedMerchant = extractMerchant(combined)
            // WHY: 收入类通知（如「支付宝成功收款1.00元」）需标记收支方向，
            // 否则原生回退路径会把收入误记为支出
            val isIncome = AutoAccountingPlugin.detectIncome(combined)
            if (AutoAccountingPlugin.isOverlayEnabled(this)) {
                // WHY: 已授权悬浮窗，启动 OverlayService 显示原生悬浮窗
                val intent = Intent(this, OverlayService::class.java).apply {
                    putExtra(OverlayService.EXTRA_PACKAGE, packageName)
                    putExtra(OverlayService.EXTRA_RAW_TEXT, combined)
                    putExtra(OverlayService.EXTRA_MERCHANT, parsedMerchant)
                    putExtra(OverlayService.EXTRA_AMOUNT, parsedAmount)
                    putExtra(OverlayService.EXTRA_IS_INCOME, isIncome)
                }
                startService(intent)
            } else {
                // WHY: 未授权悬浮窗，回退方案：以 pending 动作走补录队列 +
                // headless 引擎，category/account 为 null，Dart 侧
                // OverlayResultService 会创建一条 PendingTransaction
                // 等待用户手动确认，全程不唤起任何窗口
                android.util.Log.w(
                    "PaymentListener",
                    "悬浮窗权限未授权，回退到 headless 后台落库"
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
    }

    /**
     * 从通知文本中提取支付金额。
     * WHY: Flutter 未 attached 时无法使用 Dart 侧的 NotificationParserService，
     * 故在 Kotlin 侧用预编译正则做简化解析，金额用于悬浮窗直接展示。
     *
     * @param text 通知拼接文本。
     * @return 解析到的金额；解析失败返回 0.0。
     */
    private fun extractAmount(text: String): Double {
        return amountRegex.find(text)?.groupValues?.get(1)?.toDoubleOrNull() ?: 0.0
    }

    /**
     * 从通知文本中提取商户名。
     * WHY: 覆盖"在XX消费/收款方：XX/向XX付款/付款给XX"几种常见模板，
     * 取首个非空捕获组作为商户名；匹配失败返回空字符串。
     *
     * @param text 通知拼接文本。
     * @return 解析到的商户名；解析失败返回空字符串。
     */
    private fun extractMerchant(text: String): String {
        val match = merchantRegex.find(text) ?: return ""
        // WHY: groupValues[0] 是整体匹配，从 index 1 开始是各捕获组，取首个非空
        return match.groupValues.drop(1).firstOrNull { it.isNotEmpty() }?.trim() ?: ""
    }
}
