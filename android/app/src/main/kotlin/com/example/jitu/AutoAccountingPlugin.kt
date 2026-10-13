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

        // WHY: 缓存持久化到 SharedPreferences，进程被杀后悬浮窗仍能渲染分类/账户，
        // 否则用户遇到"暂无数据"无法修改分类
        private const val PREFS_NAME = "jitu_overlay_cache"
        private const val KEY_CACHED_CATEGORIES = "cached_categories"
        private const val KEY_CACHED_ACCOUNTS = "cached_accounts"

        /**
         * 供 NotificationListenerService 调用，跨组件传递通知事件。
         *
         * @param packageName 支付来源包名。
         * @param combined 拼接后的通知文本（title + text）。
         * @param postTime 通知发布时间戳。
         */
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
         * 处理悬浮窗用户操作结果，回调 Flutter 或拉起 MainActivity。
         * WHY: 当 eventSink 为 null（Flutter 未 attached）时，通过 Intent 拉起 MainActivity
         * 并以 extra 传递数据，MainActivity 启动后由 Flutter 侧读取并处理。
         *
         * @param action 用户操作类型，"confirm" 或 "ignore"。
         * @param amount 支付金额。
         * @param merchant 商户名。
         * @param packageName 支付来源包名。
         * @param category 用户选择的分类名（ignore 时为 null）。
         * @param account 用户选择的账户名（ignore 时为 null）。
         * @param rawText 原始通知文本。
         */
        fun handleOverlayResult(
            action: String,
            amount: Double,
            merchant: String,
            packageName: String,
            category: String?,
            account: String?,
            rawText: String
        ) {
            val data: Map<String, Any?> = mapOf(
                "action" to action,
                "amount" to amount,
                "merchant" to merchant,
                "packageName" to packageName,
                "category" to category,
                "account" to account,
                "rawText" to rawText
            )
            val sink = eventSink
            if (sink != null) {
                // WHY: Flutter attached，直接通过 EventChannel 推送
                sink.success(data)
            } else {
                // WHY: Flutter 未 attached，拉起 MainActivity 并通过 Intent extra 传递数据
                val ctx = appContext ?: pluginInstance?.context
                if (ctx != null) {
                    val intent = Intent(ctx, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        putExtra("overlay_action", action)
                        putExtra("overlay_amount", amount)
                        putExtra("overlay_merchant", merchant)
                        putExtra("overlay_package", packageName)
                        category?.let { putExtra("overlay_category", it) }
                        account?.let { putExtra("overlay_account", it) }
                        putExtra("overlay_rawText", rawText)
                    }
                    try {
                        ctx.startActivity(intent)
                    } catch (e: Exception) {
                        // WHY: 拉起失败时静默处理，避免悬浮窗 Service 崩溃
                    }
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
