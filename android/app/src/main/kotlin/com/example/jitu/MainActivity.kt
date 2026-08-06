package com.example.jitu

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // WHY: 启动数据缓存，存放从 Intent extra 中提取的 overlay 结果。
    // Flutter 引擎启动后通过 MethodChannel `jitu.auto_accounting/launch`
    // 查询此数据，处理完毕后调用 `clearLaunchData` 清空。
    private var launchData: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // WHY: 首次启动时从 Intent extra 提取 overlay 结果（应用被杀后由悬浮窗拉起）
        launchData = extractOverlayData(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AutoAccountingPlugin())

        // WHY: 注册启动数据通道，供 Flutter 查询 Intent extra 中的 overlay 结果
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jitu.auto_accounting/launch")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLaunchData" -> result.success(launchData)
                    "clearLaunchData" -> {
                        launchData = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // WHY: 应用已在后台时，新的 Intent 通过 onNewIntent 传递
        launchData = extractOverlayData(intent)
    }

    /**
     * 从 Intent 中提取 overlay 结果数据。
     *
     * WHY: AutoAccountingPlugin.handleOverlayResult 在 Flutter 未 attached 时，
     * 通过 Intent extra 传递悬浮窗操作结果并拉起 MainActivity。
     * 此方法将 extra 重组为 Map 供 Flutter 读取。
     *
     * @param intent 启动 Activity 的 Intent。
     * @return 含 overlay 结果的 Map；无 overlay 数据时返回 null。
     */
    private fun extractOverlayData(intent: Intent): Map<String, Any?>? {
        if (!intent.hasExtra("overlay_action")) return null
        return mapOf(
            "action" to intent.getStringExtra("overlay_action"),
            "amount" to intent.getDoubleExtra("overlay_amount", 0.0),
            "merchant" to (intent.getStringExtra("overlay_merchant") ?: ""),
            "packageName" to (intent.getStringExtra("overlay_package") ?: ""),
            "category" to intent.getStringExtra("overlay_category"),
            "account" to intent.getStringExtra("overlay_account"),
            "rawText" to (intent.getStringExtra("overlay_rawText") ?: "")
        )
    }
}
