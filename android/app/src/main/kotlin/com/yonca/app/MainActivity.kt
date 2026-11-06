package com.yonca.app

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
    private var pendingCallPermission: MethodChannel.Result? = null

    /**
     * The app handles its own yonca:// links (widget buttons, the call card). Letting Flutter also treat them as
     * routes made the app push an unknown route and fail with "Null check operator used on a null value".
     */
    override fun shouldHandleDeeplinking(): Boolean = false

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CALL_PERMISSION_REQUEST) return
        val result = pendingCallPermission
        pendingCallPermission = null
        result?.success(grantResults.isNotEmpty() && grantResults.all { it == android.content.pm.PackageManager.PERMISSION_GRANTED })
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yonca.app/system")
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
                    "deviceInfo" -> result.success(mapOf("model" to Build.MODEL, "android" to Build.VERSION.RELEASE))
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
                    "canManageStorage" -> {
                        val ok = if (Build.VERSION.SDK_INT >= 30) android.os.Environment.isExternalStorageManager() else true
                        result.success(ok)
                    }
                    "openStorageSettings" -> {
                        if (Build.VERSION.SDK_INT >= 30) {
                            try {
                                startActivity(Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:$packageName")))
                            } catch (e: Exception) {
                                startSafely(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                            }
                        }
                        result.success(null)
                    }
                    "hasContactsPermission" -> {
                        val granted = android.content.pm.PackageManager.PERMISSION_GRANTED
                        result.success(
                            checkSelfPermission(android.Manifest.permission.READ_CONTACTS) == granted &&
                                checkSelfPermission(android.Manifest.permission.WRITE_CONTACTS) == granted
                        )
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
                        } catch (e: Exception) {
                            startSafely(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        }
                        result.success(null)
                    }
                    "callCardStatus" -> {
                        val granted = android.content.pm.PackageManager.PERMISSION_GRANTED
                        result.success(
                            mapOf(
                                "phone" to (checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == granted &&
                                    checkSelfPermission(android.Manifest.permission.READ_CALL_LOG) == granted),
                                "overlay" to Settings.canDrawOverlays(this)
                            )
                        )
                    }
                    "requestCallPermissions" -> {
                        if (pendingCallPermission != null) {
                            result.success(null)
                        } else {
                            pendingCallPermission = result
                            requestPermissions(arrayOf(android.Manifest.permission.READ_PHONE_STATE, android.Manifest.permission.READ_CALL_LOG), CALL_PERMISSION_REQUEST)
                        }
                    }
                    "openOverlaySettings" -> {
                        startSafely(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "previewCallCard" -> result.success(CallCard.preview(applicationContext))
                    "openAppSettings" -> {
                        startSafely(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "restartApp" -> {
                        val intent = packageManager.getLaunchIntentForPackage(packageName)
                        if (intent != null) {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                            startActivity(intent)
                        }
                        result.success(null)
                        android.os.Handler(mainLooper).postDelayed({ android.os.Process.killProcess(android.os.Process.myPid()) }, 300)
                    }
                    "closeTask" -> {
                        // After the installer is on screen: drop the old app's card from recent apps,
                        // so the updated app does not show up twice.
                        result.success(null)
                        android.os.Handler(mainLooper).postDelayed({ finishAndRemoveTask() }, 800)
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
        private const val CALL_PERMISSION_REQUEST = 4712
    }
}
