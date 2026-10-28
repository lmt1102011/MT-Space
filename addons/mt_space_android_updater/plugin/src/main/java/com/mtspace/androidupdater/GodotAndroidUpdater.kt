package com.mtspace.androidupdater

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import java.io.File

class GodotAndroidUpdater(godot: Godot) : GodotPlugin(godot) {
    override fun getPluginName() = "MTSpaceAndroidUpdater"

    @UsedByGodot
    fun canRequestInstallPackages(): Boolean {
        val hostActivity = activity ?: return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            hostActivity.packageManager.canRequestPackageInstalls()
    }

    @UsedByGodot
    fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val hostActivity = activity ?: return
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${hostActivity.packageName}")
        )
        hostActivity.startActivity(intent)
    }

    @UsedByGodot
    fun installApk(path: String): String {
        val hostActivity = activity
            ?: return "Android activity is unavailable."
        return try {
            val apk = File(path)
            if (!apk.isFile || !apk.canRead()) {
                return "Bản cập nhật không còn tồn tại hoặc không thể đọc."
            }
            val uri = FileProvider.getUriForFile(
                hostActivity,
                "${hostActivity.packageName}.mtspaceupdater.fileprovider",
                apk
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            hostActivity.startActivity(intent)
            ""
        } catch (error: Exception) {
            error.message ?: error.javaClass.simpleName
        }
    }
}
