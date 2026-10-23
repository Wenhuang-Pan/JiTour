package com.example.jitu

import android.app.DownloadManager
import android.content.Context
import android.database.Cursor
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// WHY: local_auth 的生物识别弹窗（BiometricPrompt）依赖 FragmentActivity，
// 必须由 FlutterActivity 改为 FlutterFragmentActivity，否则验证调用直接抛异常
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AutoAccountingPlugin())

        // WHY: 注册系统下载通道——应用内 APK 更新改用系统 DownloadManager，
        // 下载由系统进程执行，应用退后台/被杀均不中断（自带断点续传与通知栏进度）
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jitu.system_downloader/methods")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enqueueApkDownload" -> handleEnqueueDownload(call, result)
                    "queryApkDownloadStatus" -> handleQueryDownload(call, result)
                    "cancelApkDownload" -> {
                        val id = (call.argument<Any>("downloadId") as? Number)?.toLong() ?: -1L
                        val removed = if (id > 0L) getDownloadManager().remove(id) else 0
                        result.success(removed > 0)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getDownloadManager(): DownloadManager =
        getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    /**
     * 创建系统下载任务下载 APK。
     *
     * WHY: 系统 DownloadManager 的下载独立于应用进程，配合通知栏进度，
     * 用户离开应用后下载依然继续，解决 Dart 层 http 下载退后台即中断的问题。
     *
     * @param call 含 url 参数（APK 下载地址）。
     * @param result 回传 downloadId（Long）；参数缺失或入队失败回传错误码。
     */
    private fun handleEnqueueDownload(call: MethodCall, result: MethodChannel.Result) {
        try {
            val url = call.argument<String>("url")
            if (url.isNullOrEmpty()) {
                result.error("INVALID_PARAM", "url 缺失", null)
                return
            }
            val request = DownloadManager.Request(Uri.parse(url))
                .setTitle("记途更新包")
                .setDescription("新版本安装包下载")
                .setMimeType("application/vnd.android.package-archive")
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                // WHY: 应用私有外部目录，免存储权限；下载完成后 open_filex 的
                // FileProvider 可直接读取该路径调起安装器
                .setDestinationInExternalFilesDir(this, null, "jitu_update.apk")
            result.success(getDownloadManager().enqueue(request))
        } catch (e: Exception) {
            result.error("ENQUEUE_FAILED", "创建下载任务失败: ${e.message}", null)
        }
    }

    /**
     * 查询系统下载任务状态与进度。
     *
     * @param call 含 downloadId 参数。
     * @param result 回传 Map：status（running/paused/pending/successful/failed）、
     *               bytesSoFar、totalBytes、filePath（仅成功时，用于调起安装器）；
     *               任务不存在时回传 null。
     */
    private fun handleQueryDownload(call: MethodCall, result: MethodChannel.Result) {
        val id = (call.argument<Any>("downloadId") as? Number)?.toLong() ?: -1L
        if (id <= 0L) {
            result.success(null)
            return
        }
        var cursor: Cursor? = null
        try {
            cursor = getDownloadManager().query(DownloadManager.Query().setFilterById(id))
            if (cursor == null || !cursor.moveToFirst()) {
                result.success(null)
                return
            }
            val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            val statusName = when (status) {
                DownloadManager.STATUS_SUCCESSFUL -> "successful"
                DownloadManager.STATUS_FAILED -> "failed"
                DownloadManager.STATUS_PAUSED -> "paused"
                DownloadManager.STATUS_PENDING -> "pending"
                else -> "running"
            }
            val bytesSoFar = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
            val totalBytes = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
            var filePath: String? = null
            if (status == DownloadManager.STATUS_SUCCESSFUL) {
                // WHY: 完成任务的本地路径供 Dart 侧调起安装器，file:// URI 直接取 path
                val localUri = cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
                filePath = localUri?.let { Uri.parse(it).path }
            }
            result.success(
                mapOf(
                    "status" to statusName,
                    "bytesSoFar" to bytesSoFar,
                    "totalBytes" to totalBytes,
                    "filePath" to filePath
                )
            )
        } catch (e: Exception) {
            result.error("QUERY_FAILED", "查询下载状态失败: ${e.message}", null)
        } finally {
            cursor?.close()
        }
    }
}
