package com.example.jitu

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * 悬浮窗事件 headless 落库执行器。
 *
 * WHY: 应用被杀（Flutter 未 attached）时，悬浮窗的确认记账无法立即落库
 * （Hive 数据在 Dart 层）。v3.4.1 用户反馈：不允许唤起 MainActivity 打扰用户。
 * 本类在 Service 进程内创建无界面 Flutter 引擎执行 Dart 入口
 * `overlayHeadlessMain`，由 Dart 侧循环读取补录队列并落库，完成后调
 * headlessDone 销毁引擎，全程无任何 UI。
 *
 * 失败兜底：引擎创建/执行失败时数据仍保留在 SharedPreferences 补录队列，
 * 用户下次打开 app 由 AutoAccountingProvider.init 读取补录，不会丢数据。
 */
object OverlayHeadlessRunner {

    /// Dart 与本执行器之间的通信通道：drainQueue 拉取队列，headlessDone 汇报完成
    private const val CHANNEL_NAME = "jitu.overlay_headless/entry"

    // WHY: 60 秒看门狗——Dart 侧挂死或异常时强制销毁引擎防止泄漏；
    // 正常完成（headlessDone）时会取消
    private const val WATCHDOG_TIMEOUT_MS = 60_000L

    private var engine: FlutterEngine? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var watchdogRunnable: Runnable? = null

    /**
     * 确保有 headless 引擎在运行（幂等）。
     *
     * WHY: 多笔支付场景下 handleOverlayResult 可能被连续调用，
     * 已有引擎在跑时直接复用——引擎内的 Dart 循环每轮都会再次 drain
     * 队列，新入队的数据会被一并处理，无需重复创建。
     *
     * @param context 任意可用 Context（内部取 applicationContext）。
     */
    @Synchronized
    fun ensureEngine(context: Context) {
        if (engine != null) {
            android.util.Log.d("AutoAccounting", "headless 引擎已在运行，复用")
            return
        }
        val appCtx = context.applicationContext
        try {
            // WHY: 双参构造与 DartEntrypoint.createDefault 同源——pathToBundle
            // 固定 "flutter_assets"（应用内 assets 目录名），第二个参数为自定义
            // Dart 入口函数名；不使用主引擎的 main() 入口避免拉起完整 UI
            val entrypoint = DartExecutor.DartEntrypoint(
                "flutter_assets",
                "overlayHeadlessMain"
            )
            val created = FlutterEngineGroup(appCtx).createAndRunEngine(appCtx, entrypoint)
            engine = created

            // WHY: headless 引擎不注册任何插件——插件副作用包括
            // AutoAccountingPlugin 置 flutterAttached=true 引发事件路由混乱。
            // Hive 所需的数据目录由 drainQueue 响应直接传入，
            // 与主 app 的 getApplicationDocumentsDirectory() 路径完全一致
            //（path_provider 的实现即 context.getDir("app_flutter", MODE_PRIVATE)）

            // WHY: Dart 驱动处理循环，本通道只提供数据（drainQueue）与销毁指令
            //（headlessDone）；handler 在引擎创建后立即注册，Dart 任何时刻调用均可达
            MethodChannel(created.dartExecutor.binaryMessenger, CHANNEL_NAME)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "drainQueue" -> {
                            result.success(
                                mapOf(
                                    "dbPath" to appCtx.getDir("app_flutter", Context.MODE_PRIVATE)
                                        .absolutePath,
                                    "items" to AutoAccountingPlugin.drainPendingOverlayResults()
                                )
                            )
                        }
                        "headlessDone" -> {
                            result.success(null)
                            destroy()
                        }
                        else -> result.notImplemented()
                    }
                }

            startWatchdog()
            android.util.Log.d("AutoAccounting", "headless 引擎已创建，开始后台落库")
        } catch (e: Exception) {
            // WHY: 引擎创建失败（低内存等）不中断流程——数据已在补录队列，
            // 用户下次打开 app 时由 AutoAccountingProvider.init 补录兜底
            android.util.Log.e(
                "AutoAccounting",
                "headless 引擎创建失败，交由启动补录兜底: ${e.message}"
            )
            engine = null
        }
    }

    /** 启动看门狗：超时强制销毁引擎。 */
    private fun startWatchdog() {
        cancelWatchdog()
        val runnable = Runnable {
            android.util.Log.e("AutoAccounting", "headless 落库超时，强制销毁引擎")
            destroy()
        }
        watchdogRunnable = runnable
        mainHandler.postDelayed(runnable, WATCHDOG_TIMEOUT_MS)
    }

    /** 取消看门狗。 */
    private fun cancelWatchdog() {
        watchdogRunnable?.let { mainHandler.removeCallbacks(it) }
        watchdogRunnable = null
    }

    /**
     * 销毁当前 headless 引擎并取消看门狗（幂等）。
     */
    @Synchronized
    fun destroy() {
        cancelWatchdog()
        engine?.let {
            try {
                it.destroy()
            } catch (e: Exception) {
                android.util.Log.e("AutoAccounting", "headless 引擎销毁异常: ${e.message}")
            }
        }
        engine = null
    }
}

