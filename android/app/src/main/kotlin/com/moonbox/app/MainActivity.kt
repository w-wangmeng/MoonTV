package com.moonbox.app

import android.app.UiModeManager
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "moonbox/device",
        ).setMethodCallHandler { call, result ->
            if (call.method == "isTelevision") {
                result.success(isTelevision())
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "moonbox/update",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDownloadDirectory" -> {
                    // 与 res/xml/file_paths.xml 的 files-path downloads/ 保持一致，
                    // 保证 FileProvider 能授权给系统安装器。
                    val dir = File(filesDir, "downloads").apply { mkdirs() }
                    result.success(dir.absolutePath)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_arg", "no apk path", null)
                    } else {
                        result.success(installApk(File(path)))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isTelevision(): Boolean {
        val uiMode = getSystemService(UI_MODE_SERVICE) as UiModeManager
        return uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_TELEVISION)
    }

    /** 用 FileProvider 暴露 APK 并唤起系统安装器。 */
    private fun installApk(file: File): Boolean {
        if (!file.exists()) return false
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
