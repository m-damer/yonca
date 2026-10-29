package com.cyberomeda.yonca

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingRingtone: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.cyberomeda.yonca/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickRingtone" -> pickRingtone(call.argument<String>("current"), result)
                    "canUseFullScreenIntent" -> {
                        val ok = if (Build.VERSION.SDK_INT >= 34) {
                            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).canUseFullScreenIntent()
                        } else {
                            true
                        }
                        result.success(ok)
                    }
                    "openFullScreenSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= 34) {
                            Intent("android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT", Uri.parse("package:$packageName"))
                        } else {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        }
                        startSafely(intent)
                        result.success(null)
                    }
                    "canInstallPackages" -> {
                        val ok = if (Build.VERSION.SDK_INT >= 26) packageManager.canRequestPackageInstalls() else true
                        result.success(ok)
                    }
                    "openInstallSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= 26) {
                            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                        } else {
                            Intent(Settings.ACTION_SECURITY_SETTINGS)
                        }
                        startSafely(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startSafely(intent: Intent) {
        try {
            startActivity(intent)
        } catch (e: Exception) {
            // No settings screen to open on this phone.
        }
    }

    private fun pickRingtone(current: String?, result: MethodChannel.Result) {
        if (pendingRingtone != null) {
            result.success(null)
            return
        }
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
        val existing = if (current.isNullOrEmpty()) RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) else Uri.parse(current)
        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, existing)
        pendingRingtone = result
        try {
            startActivityForResult(intent, RINGTONE_REQUEST)
        } catch (e: Exception) {
            pendingRingtone = null
            result.success(null)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != RINGTONE_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingRingtone
        pendingRingtone = null
        if (result == null) return
        if (resultCode != RESULT_OK || data == null) {
            result.success(null)
            return
        }
        val uri: Uri? = data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        if (uri == null) {
            result.success(null)
            return
        }
        val title = try {
            RingtoneManager.getRingtone(this, uri)?.getTitle(this) ?: ""
        } catch (e: Exception) {
            ""
        }
        val isDefault = uri == RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        result.success(mapOf("uri" to (if (isDefault) "" else uri.toString()), "title" to (if (isDefault) "" else title)))
    }

    companion object {
        private const val RINGTONE_REQUEST = 4711
    }
}
