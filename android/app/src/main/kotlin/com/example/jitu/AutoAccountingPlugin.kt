package com.example.jitu

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class AutoAccountingPlugin : FlutterPlugin, ActivityAware, EventChannel.StreamHandler, MethodChannel.MethodCallHandler {

    companion object {
        private const val EVENT_CHANNEL_NAME = "jitu.auto_accounting/events"
        private const val METHOD_CHANNEL_NAME = "jitu.auto_accounting/methods"
        // WHY: POST_NOTIFICATIONS 权限请求码，onRequestPermissionsResult 中据此识别
        private const val REQUEST_CODE_POST_NOTIFICATIONS = 1001

        private var eventSink: EventChannel.EventSink? = null
        private var pluginInstance: AutoAccountingPlugin? = null

        // WHY: 保存 applicationContext 到 companion，供悬浮窗结果回调等场景在 Flutter 未 attached 时拉起 MainActivity
        private var appContext: Context? = null

        // WHY: Flutter 引擎 attached 状态，决定通知事件路由到 Flutter 还是原生悬浮窗
        // 用属性 flutterAttached + 函数 isFlutterAttached() 避免同名冲突
        private var flutterAttached: Boolean = false

        // WHY: 分类/账户缓存，供 OverlayService 渲染 Chip 选择项
        private var cachedCategories: List<Map<String, String>> = emptyList()
        private var cachedAccounts: List<Map<String, String>> = emptyList()

        // WHY: 跨通道统一去重——同一笔支付可能同时触发通知监听与无障碍服务，
        // 两条通道独立触发会造成重复弹窗/重复记账。金额在同一笔支付中是稳定值
        // （页面文本会随动画/倒计时变化，不可靠），用「包名+金额」15 秒窗口去重。
        // 窗口取 15 秒而非 60 秒：同笔支付的双通道事件毫秒级到达，15 秒足够去重，
        // 又能大幅降低误杀 60 秒内两笔同金额不同交易的概率。
        private const val EVENT_DEDUP_WINDOW_MS = 15_000L

        // WHY: 多槽位去重表（key=「包名:金额」→ 首次事件时间戳）——
        // 旧的单槽位设计（lastEventKey 单变量）在多笔支付交错或双通道并发
        // 场景下会互相覆盖去重记录，导致同一笔支付被重复弹窗（v3.4.1 修复）。
        // 通知监听与无障碍服务均在主线程调用，HashMap 无并发风险
        private val recentEventKeys = HashMap<String, Long>()

        /**
         * 确保 applicationContext 已缓存。
         *
         * WHY: 华为等国产 ROM 杀后台后，系统会单独拉起应用进程运行
         * NotificationListener/Accessibility/Overlay Service（纯 Service 进程，
         * Flutter 引擎从未 attach，onAttachedToEngine 从未执行），
         * 此时 appContext/pluginInstance 均为 null，悬浮窗确认后无法创建
         * headless 落库引擎，导致记账结果滞留队列。各 Service 创建时调用本方法兜底。
         *
         * @param context 任意可用 Context，内部取 applicationContext 缓存。
         */
        fun ensureAppContext(context: Context) {
            if (appContext == null) {
                appContext = context.applicationContext
            }
        }

        /**
         * 跨通道支付事件去重判断。
         *
         * WHY: 通知监听与无障碍服务可能同时捕获同一笔支付，
         * 在事件路由（sendPaymentEvent / 启动 OverlayService）前统一过一道去重。
         * 金额解析失败（amount <= 0）时不参与去重直接放行，避免误挡后续正常事件。
         *
         * @param packageName 事件来源包名。
         * @param amount 解析出的支付金额。
         * @return true 表示是新事件应继续处理；false 表示窗口期内重复，应丢弃。
         */
        @Synchronized
        fun shouldProcessEvent(packageName: String, amount: Double): Boolean {
            // WHY: 金额无效时不具备去重依据，放行交给上层流程自行处理
            if (amount <= 0.0) return true
            val now = System.currentTimeMillis()
            // WHY: 顺手清理过期条目防止 Map 无限增长；事件频率低（支付级别），
            // O(n) 遍历开销可忽略（n 通常 < 10）
            recentEventKeys.entries.removeAll { now - it.value >= EVENT_DEDUP_WINDOW_MS }
            val key = "$packageName:$amount"
            val lastTime = recentEventKeys[key]
            if (lastTime != null && now - lastTime < EVENT_DEDUP_WINDOW_MS) {
                android.util.Log.d("AutoAccounting", "重复事件被去重: $key")
                return false
            }
            recentEventKeys[key] = now
            return true
        }

        // WHY: 缓存持久化到 SharedPreferences，进程被杀后悬浮窗仍能渲染分类/账户，
        // 否则用户遇到"暂无数据"无法修改分类
        private const val PREFS_NAME = "jitu_overlay_cache"
        private const val KEY_CACHED_CATEGORIES = "cached_categories"
        private const val KEY_CACHED_ACCOUNTS = "cached_accounts"

        // WHY: 悬浮窗事件补录队列——Flutter 未 attached 时（应用被杀），悬浮窗的
        // 确认/待确认事件无法立即写入 Hive，持久化到 SharedPreferences，
        // 应用下次启动后由 Dart 侧 drainPendingOverlayResults 读取补录。
        // v3.4.1 用户反馈：确认/忽略都不应拉起 MainActivity 打扰用户
        private const val KEY_PENDING_OVERLAY_RESULTS = "pending_overlay_results"

        /**
         * 将悬浮窗事件写入补录队列（追加到已有队列尾部）。
         *
         * WHY: 纯 Service 进程无 Dart 执行环境，确认记账的落库必须延迟到
         * 应用下次启动；SharedPreferences 持久化保证进程被杀后数据不丢。
         *
         * @param data 事件数据，含 action/amount/merchant/category/account/rawText/isIncome。
         */
        fun enqueuePendingOverlayResult(data: Map<String, Any?>) {
            val ctx = appContext ?: run {
                android.util.Log.e(
                    "AutoAccounting",
                    "enqueuePendingOverlayResult 丢弃: 无可用 Context, action=${data["action"]}"
                )
                return
            }
            try {
                val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val existing = prefs.getString(KEY_PENDING_OVERLAY_RESULTS, null)
                val arr = if (existing != null) JSONArray(existing) else JSONArray()
                val obj = JSONObject()
                data.forEach { (k, v) ->
                    // WHY: JSONObject.put(key, null) 语义是移除 key，null 值直接跳过，
                    // Dart 侧读取缺失 key 与显式 null 行为一致
                    if (v != null) obj.put(k, v)
                }
                arr.put(obj)
                prefs.edit().putString(KEY_PENDING_OVERLAY_RESULTS, arr.toString()).apply()
                android.util.Log.d(
                    "AutoAccounting",
                    "悬浮窗事件入队待补录: action=${data["action"]}, amount=${data["amount"]}"
                )
            } catch (e: Exception) {
                // WHY: 队列写入失败必须留日志，禁止静默丢弃用户确认的记账数据
                android.util.Log.e(
                    "AutoAccounting",
                    "悬浮窗事件入队失败: ${e.message}"
                )
            }
        }

        /**
         * 读取并清空补录队列。
         *
         * WHY: 先清空再解析——即使解析失败也不至于重复补录导致重复记账；
         * 队列数据不含 timestamp，Dart 侧过期检查按「历史数据有效」处理
         * （用户明确确认过的记账不应因打开 app 晚而被丢弃）。
         *
         * @return 队列数据列表（每项为 String/double/bool/null 值的 Map），空队列返回空列表。
         */
        fun drainPendingOverlayResults(): List<Map<String, Any?>> {
            val ctx = appContext ?: return emptyList()
            val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY_PENDING_OVERLAY_RESULTS, null) ?: return emptyList()
            prefs.edit().remove(KEY_PENDING_OVERLAY_RESULTS).apply()
            return try {
                val arr = JSONArray(json)
                (0 until arr.length()).map { i ->
                    val obj = arr.getJSONObject(i)
                    val map = mutableMapOf<String, Any?>()
                    obj.keys().forEach { k ->
                        map[k] = when {
                            obj.isNull(k) -> null
                            obj.get(k) is Boolean -> obj.getBoolean(k)
                            obj.get(k) is Number -> obj.getDouble(k)
                            else -> obj.getString(k)
                        }
                    }
                    map
                }
            } catch (e: Exception) {
                android.util.Log.e("AutoAccounting", "解析待补录队列失败: ${e.message}")
                emptyList()
            }
        }

        /**
         * 供 NotificationListenerService 调用，跨组件传递通知事件。
         *
         * @param packageName 支付来源包名。
         * @param combined 拼接后的通知文本（title + text）。
         * @param postTime 通知发布时间戳。
         */
        // WHY: 收入类关键词——通知监听与无障碍服务共用的收支方向判定。
        // 不能用裸「收款」：支出页面的「收款方」（商户名标签）会造成误判，
        // 故只匹配明确的成功/到账语义短语
        private val incomeKeywords = listOf(
            "成功收款", "收款成功", "收款到账", "转账到账", "已到账",
            "收到转账", "收到红包", "转入", "入账", "退款成功", "退款到账"
        )

        // WHY: 退款通知文案不一定带「成功/到账」（如「微信支付退款 ￥12.00」
        // 「原路退回」），只靠上面的短语会把退款误记成支出（v3.4.2 用户反馈）
        private val refundKeywords = listOf("退款", "退回", "退费")

        // WHY: 退款申请/退款中等未完成态不能算收入
        private val refundPendingKeywords = listOf(
            "退款失败", "申请退款", "退款中", "退款处理中", "待退款", "退款申请"
        )

        /**
         * 判断文本是否描述收入场景。
         *
         * @param text 通知或页面拼接文本。
         * @return true 表示收入（收款/到账/退款），false 表示支出。
         */
        fun detectIncome(text: String): Boolean {
            // WHY: 未完成的退款流程优先排除，避免把申请退款当成收入
            if (refundPendingKeywords.any { text.contains(it) }) return false
            // O(k)，k 为关键词数量（常量级）
            return incomeKeywords.any { text.contains(it) } ||
                refundKeywords.any { text.contains(it) }
        }

        fun sendPaymentEvent(packageName: String, combined: String, postTime: Long = System.currentTimeMillis()) {
            val data = mapOf(
                "packageName" to packageName,
                "combined" to combined,
                "postTime" to postTime
            )
            eventSink?.success(data)
        }

        /**
         * 检查通知监听权限是否已开启。
         *
         * @param context 任意可用 Context。
         * @return true 表示已授权本应用监听通知。
         */
        fun isNotificationListenerEnabled(context: Context): Boolean {
            val enabledListeners = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            ) ?: return false
            val expectedComponent = ComponentName(
                context,
                PaymentNotificationListener::class.java
            ).flattenToString()
            return enabledListeners.split(':').any {
                ComponentName.unflattenFromString(it)?.let { cn ->
                    cn.packageName == expectedComponent.split('/')[0] &&
                        cn.className == expectedComponent.split('/')[1]
                } == true || it.contains(expectedComponent)
            }
        }

        /**
         * 跳转系统通知监听设置页。
         *
         * @param context 任意可用 Context。
         * @return true 表示跳转成功。
         */
        fun openNotificationListenerSettings(context: Context): Boolean {
            return try {
                val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                true
            } catch (e: Exception) {
                false
            }
        }

        /**
         * 检查无障碍服务（支付页面识别）是否已开启。
         *
         * @param context 任意可用 Context。
         * @return true 表示已授权本应用的无障碍服务。
         */
        fun isAccessibilityServiceEnabled(context: Context): Boolean {
            return PaymentAccessibilityService.isServiceEnabled(context)
        }

        /**
         * 跳转系统无障碍设置页。
         *
         * @param context 任意可用 Context。
         * @return true 表示跳转成功。
         */
        fun openAccessibilitySettings(context: Context): Boolean {
            return try {
                val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                true
            } catch (e: Exception) {
                false
            }
        }

        /**
         * 更新分类缓存，由 Flutter 侧通过 MethodChannel `pushCategories` 推送。
         *
         * @param list 分类列表，每个 Map 至少含 `name` 字段。
         */
        fun updateCachedCategories(list: List<Map<String, String>>) {
            cachedCategories = list
            persistCache(KEY_CACHED_CATEGORIES, list)
        }

        /**
         * 更新账户缓存，由 Flutter 侧通过 MethodChannel `pushAccounts` 推送。
         *
         * @param list 账户列表，每个 Map 至少含 `name` 字段。
         */
        fun updateCachedAccounts(list: List<Map<String, String>>) {
            cachedAccounts = list
            persistCache(KEY_CACHED_ACCOUNTS, list)
        }

        /**
         * 将缓存列表持久化到 SharedPreferences（JSON 数组字符串）。
         *
         * @param key 存储键名。
         * @param list 待持久化的列表。
         */
        private fun persistCache(key: String, list: List<Map<String, String>>) {
            val ctx = appContext ?: return
            val arr = JSONArray()
            list.forEach { map ->
                val obj = JSONObject()
                map.forEach { (k, v) -> obj.put(k, v) }
                arr.put(obj)
            }
            ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(key, arr.toString())
                .apply()
        }

        /**
         * 进程被杀后内存缓存丢失时，从 SharedPreferences 恢复缓存。
         *
         * WHY: OverlayService 可能由 NotificationListener 在 Flutter 未启动时拉起，
         * 此时内存缓存为空，需从磁盘恢复才能渲染分类/账户 Chip。
         *
         * @param context 任意 Context（Service/Activity 均可）。
         */
        fun restoreCacheIfNeeded(context: Context) {
            if (cachedCategories.isEmpty()) {
                cachedCategories = readCache(context, KEY_CACHED_CATEGORIES)
            }
            if (cachedAccounts.isEmpty()) {
                cachedAccounts = readCache(context, KEY_CACHED_ACCOUNTS)
            }
        }

        /**
         * 从 SharedPreferences 读取缓存列表。
         *
         * @param context 任意 Context。
         * @param key 存储键名。
         * @return 解析出的列表；无数据或解析失败返回空列表。
         */
        private fun readCache(context: Context, key: String): List<Map<String, String>> {
            val json = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(key, null) ?: return emptyList()
            return try {
                val arr = JSONArray(json)
                (0 until arr.length()).map { i ->
                    val obj = arr.getJSONObject(i)
                    val map = mutableMapOf<String, String>()
                    obj.keys().forEach { k -> map[k] = obj.getString(k) }
                    map
                }
            } catch (e: Exception) {
                // WHY: 缓存损坏时静默降级为空列表，不影响悬浮窗主流程
                emptyList()
            }
        }

        /**
         * 获取分类缓存，供 OverlayService 渲染 Chip。
         *
         * @return 分类列表副本引用（不可变 List）。
         */
        fun getCachedCategories(): List<Map<String, String>> = cachedCategories

        /**
         * 获取账户缓存，供 OverlayService 渲染 Chip。
         *
         * @return 账户列表副本引用（不可变 List）。
         */
        fun getCachedAccounts(): List<Map<String, String>> = cachedAccounts

        /**
         * 判断 Flutter 引擎是否 attached。
         * WHY: NotificationListenerService 据此决定推送至 Flutter 还是启动原生悬浮窗。
         *
         * @return true 表示 Flutter 已 attached，EventChannel 可用。
         */
        fun isFlutterAttached(): Boolean = flutterAttached

        /**
         * 检查悬浮窗权限（SYSTEM_ALERT_WINDOW）是否已授权。
         *
         * @param context 任意可用 Context。
         * @return true 表示已授权可绘制悬浮窗。
         */
        fun isOverlayEnabled(context: Context): Boolean = Settings.canDrawOverlays(context)

        /**
         * 检查 POST_NOTIFICATIONS 权限是否已授权（Android 13+）。
         *
         * WHY: Android 13 (API 33) 起通知权限需要运行时请求，
         * 否则前台 Service 通知无法显示，系统可能在 1 分钟后杀死 Service。
         *
         * @param context 任意可用 Context。
         * @return true 表示已授权或 Android 版本 < 13（无需请求）。
         */
        fun isPostNotificationsGranted(context: Context): Boolean {
            // WHY: Android 13 以下版本无需运行时请求，直接视为已授权
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
            return ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        }

        /**
         * 跳转系统悬浮窗权限设置页。
         *
         * @param context 任意可用 Context。
         * @return true 表示跳转成功；false 表示无可用 Activity 处理该 Intent。
         */
        fun openOverlaySettings(context: Context): Boolean {
            return try {
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                intent.data = Uri.parse("package:" + context.packageName)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                true
            } catch (e: Exception) {
                false
            }
        }

        /**
         * 检查本应用是否已在电池优化白名单中（即"忽略电池优化"）。
         *
         * WHY: 国产 ROM（华为 EMUI 等）的电池优化会强行关闭无障碍服务与后台
         * Service，导致自动记账通道失效。加入白名单后可显著降低被杀概率。
         *
         * @param context 任意可用 Context。
         * @return true 表示已加入电池优化白名单。
         */
        fun isIgnoringBatteryOptimizations(context: Context): Boolean {
            // WHY: PowerManager.isIgnoringBatteryOptimizations 为 API 23 (M) 新增，
            // 低版本设备无电池优化概念，直接视为已豁免，避免 NoSuchMethodError 崩溃
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
            val pm = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            return pm.isIgnoringBatteryOptimizations(context.packageName)
        }

        /**
         * 跳转系统"忽略电池优化"授权页，引导用户将本应用加入白名单。
         *
         * WHY: 该 Intent 直接弹出系统授权对话框，无需用户手动翻找设置项；
         * 需要 Manifest 声明 REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 权限。
         *
         * @param context 任意可用 Context。
         * @return true 表示跳转成功。
         */
        fun requestIgnoreBatteryOptimizations(context: Context): Boolean {
            // WHY: ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 为 API 23 新增，
            // 低版本设备无需电池优化授权，直接返回 true
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
            return try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:" + context.packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                true
            } catch (e: Exception) {
                android.util.Log.e("AutoAccounting", "跳转电池优化设置失败: ${e.message}")
                false
            }
        }

        /**
         * 跳转国产 ROM 的自启动管理页（华为/小米/OPPO/vivo 逐个尝试）。
         *
         * WHY: 自启动/关联启动权限是国产 ROM 保活的关键，缺失时系统会在后台
         * 杀掉无障碍服务与监听 Service。各厂商设置页 Component 不统一且无公开
         * API，按主流厂商逐个尝试，全部失败时回退到应用详情设置页。
         *
         * @param context 任意可用 Context。
         * @return true 表示成功跳转到某个设置页。
         */
        fun openAutoStartSettings(context: Context): Boolean {
            val intents = listOf(
                // 华为 EMUI（不同版本 Component 不同，逐一尝试）
                Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
                Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity")),
                Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")),
                // 小米 MIUI
                Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
                // OPPO ColorOS
                Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
                Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")),
                // vivo OriginOS
                Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
                Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager")),
                // 荣耀
                Intent().setComponent(ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
            )
            for (intent in intents) {
                try {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    return true
                } catch (e: Exception) {
                    // WHY: 厂商 Component 不存在时尝试下一个，属预期分支无需日志
                }
            }
            // WHY: 所有厂商页均不可用时，回退到应用详情页，用户至少可手动配置
            return try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:" + context.packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                true
            } catch (e: Exception) {
                android.util.Log.e("AutoAccounting", "跳转自启动设置失败: ${e.message}")
                false
            }
        }

        /**
         * 处理悬浮窗用户操作结果，回调 Flutter、入队后台落库或直接丢弃。
         * WHY: 分三种路径处理（v3.4.1 起不再唤起 MainActivity，避免打扰用户）——
         * 1. Flutter attached：通过 EventChannel 推送，Dart 后台完成数据处理；
         * 2. Flutter 未 attached 且 action=confirm/pending：写入 SharedPreferences
         *    补录队列，同时创建 headless 引擎立即后台落库（无任何 UI）；
         *    引擎失败时数据留在队列，下次打开 app 由启动补录兜底；
         * 3. Flutter 未 attached 且 action=ignore：忽略无需数据写入，原生直接丢弃。
         *
         * @param action 用户操作类型，"confirm"、"pending" 或 "ignore"。
         * @param amount 支付金额。
         * @param merchant 商户名。
         * @param packageName 支付来源包名。
         * @param category 用户选择的分类名（ignore/pending 时为 null）。
         * @param account 用户选择的账户名（ignore/pending 时为 null）。
         * @param rawText 原始通知文本。
         * @param isIncome 收支方向，true 表示收入（退款/收款）。
         */
        fun handleOverlayResult(
            action: String,
            amount: Double,
            merchant: String,
            packageName: String,
            category: String?,
            account: String?,
            rawText: String,
            isIncome: Boolean = false
        ) {
            val data: Map<String, Any?> = mapOf(
                "action" to action,
                "amount" to amount,
                "merchant" to merchant,
                "packageName" to packageName,
                "category" to category,
                "account" to account,
                "rawText" to rawText,
                "isIncome" to isIncome
            )
            val sink = eventSink
            if (sink != null) {
                // WHY: Flutter attached，直接通过 EventChannel 推送
                sink.success(data)
            } else if (action == "ignore") {
                // WHY: 忽略操作无需任何数据写入，原生侧直接丢弃即可，
                // 避免用户点"忽略"后被突兀打扰（v3.4.1 用户反馈修复）
                android.util.Log.d(
                    "AutoAccounting",
                    "悬浮窗忽略: Flutter 未 attached，原生直接丢弃, amount=$amount, merchant=$merchant"
                )
            } else {
                // WHY: confirm/pending 需要 Dart 写入 Hive，Flutter 未 attached 时
                // 无法立即落库。先持久化到补录队列（数据不丢），再创建 headless
                // 引擎立即后台落库，全程不唤起任何窗口（v3.4.1 用户反馈修复）
                enqueuePendingOverlayResult(data)
                val ctx = appContext ?: pluginInstance?.context
                if (ctx != null) {
                    OverlayHeadlessRunner.ensureEngine(ctx)
                } else {
                    // WHY: ensureAppContext 应已兜底；仍无 Context 时引擎无法创建，
                    // 数据保留在队列等待启动补录，必须留日志便于排查
                    android.util.Log.e(
                        "AutoAccounting",
                        "handleOverlayResult: 无可用 Context，跳过 headless 落库，等待启动补录, action=$action"
                    )
                }
            }
        }
    }

    private lateinit var context: Context
    private var eventChannel: EventChannel? = null
    private var methodChannel: MethodChannel? = null
    // WHY: 保存 Activity 引用用于运行时权限请求，ActivityAware 生命周期内有效
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        // WHY: 同步刷新 companion 中的 applicationContext 与 attached 状态，
        // 供 NotificationListenerService 路由判断及悬浮窗结果回调拉起 MainActivity 使用
        appContext = binding.applicationContext
        flutterAttached = true
        pluginInstance = this
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel!!.setStreamHandler(this)
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel!!.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // WHY: 标记 Flutter 已分离，后续通知事件改走原生悬浮窗路径
        flutterAttached = false
        eventChannel?.setStreamHandler(null)
        methodChannel?.setMethodCallHandler(null)
        eventSink = null
        eventChannel = null
        methodChannel = null
        pluginInstance = null
    }

    // WHY: ActivityAware 实现，用于获取 Activity 引用以请求运行时权限
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // EventChannel.StreamHandler
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // MethodCallHandler
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isListenerEnabled" -> {
                result.success(isNotificationListenerEnabled(context))
            }
            "openNotificationSettings" -> {
                result.success(openNotificationListenerSettings(context))
            }
            "isAccessibilityEnabled" -> {
                // WHY: 支付页面识别（无障碍）授权状态查询，v3.3.0 新增补充通道
                result.success(isAccessibilityServiceEnabled(context))
            }
            "openAccessibilitySettings" -> {
                result.success(openAccessibilitySettings(context))
            }
            "isOverlayEnabled" -> {
                result.success(isOverlayEnabled(context))
            }
            "openOverlaySettings" -> {
                result.success(openOverlaySettings(context))
            }
            "isPostNotificationsGranted" -> {
                // WHY: 查询 POST_NOTIFICATIONS 权限状态，Android 13+ 必需
                result.success(isPostNotificationsGranted(context))
            }
            "requestPostNotifications" -> {
                // WHY: 请求 POST_NOTIFICATIONS 运行时权限，仅 Android 13+ 有效
                requestPostNotifications(result)
            }
            "pushCategories" -> {
                // WHY: Flutter 推送分类列表到原生侧缓存，供 OverlayService 渲染
                updateCachedCategories(toStringMapList(call.arguments))
                result.success(null)
            }
            "pushAccounts" -> {
                // WHY: Flutter 推送账户列表到原生侧缓存，供 OverlayService 渲染
                updateCachedAccounts(toStringMapList(call.arguments))
                result.success(null)
            }
            "isIgnoringBatteryOptimizations" -> {
                // WHY: 查询电池优化白名单状态，国产 ROM 保活引导用
                result.success(isIgnoringBatteryOptimizations(context))
            }
            "requestIgnoreBatteryOptimizations" -> {
                // WHY: 跳转系统"忽略电池优化"授权对话框
                result.success(requestIgnoreBatteryOptimizations(context))
            }
            "openAutoStartSettings" -> {
                // WHY: 跳转国产 ROM 自启动管理页，保活引导用
                result.success(openAutoStartSettings(context))
            }
            "drainPendingOverlayResults" -> {
                // WHY: 应用正常启动后 Dart 读取补录队列兜底（headless 引擎失败时
                // 数据滞留在队列中）；读取即清空，不会重复处理
                result.success(drainPendingOverlayResults())
            }
            else -> result.notImplemented()
        }
    }

    /**
     * 请求 POST_NOTIFICATIONS 运行时权限（Android 13+）。
     *
     * WHY: 使用 ActivityCompat 请求权限，结果通过 MethodChannel.Result 同步返回。
     * Android 13 以下版本直接返回 true（无需请求）。
     *
     * @param result MethodChannel 结果回调，返回 Boolean 表示是否已授权。
     */
    private fun requestPostNotifications(result: MethodChannel.Result) {
        // WHY: Android 13 以下无需请求，直接视为已授权
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        val act = activity
        if (act == null) {
            // WHY: Activity 未绑定（后台/被杀），无法请求权限，返回当前状态
            result.success(isPostNotificationsGranted(context))
            return
        }
        // WHY: 已授权直接返回 true，避免重复请求打扰用户
        if (isPostNotificationsGranted(context)) {
            result.success(true)
            return
        }
        // WHY: 请求权限，异步回调中通过 result 返回最终状态
        ActivityCompat.requestPermissions(
            act,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_CODE_POST_NOTIFICATIONS
        )
        // WHY: requestPermissions 异步执行，此处先返回 false，
        // Flutter 侧在用户从设置返回后会再次调用 isPostNotificationsGranted 刷新
        result.success(false)
    }

    /**
     * 将 MethodChannel 传入的原始参数转换为 [List]<[Map]<[String], [String]>>。
     * WHY: Flutter 侧 `List<Map<String, String>>` 经由 platform channel 传递后，
     * 在 Kotlin 侧表现为 `ArrayList<HashMap<String, Any?>>`，需统一转成 String 值以便缓存。
     *
     * @param raw 原始参数，预期为 List 形态。
     * @return 转换后的字符串 Map 列表；非 List 输入返回空列表。
     */
    // WHY: 时间复杂度 O(n*m)，n 为列表长度，m 为单个 Map 的键值对数
    private fun toStringMapList(raw: Any?): List<Map<String, String>> {
        if (raw !is List<*>) return emptyList()
        return raw.mapNotNull { item ->
            (item as? Map<*, *>)?.entries?.associate { (k, v) ->
                (k?.toString() ?: "") to (v?.toString() ?: "")
            }
        }
    }
}
