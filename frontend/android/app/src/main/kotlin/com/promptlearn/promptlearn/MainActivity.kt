package com.promptlearn.promptlearn

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var recordingChannel: ClassRecordingChannel? = null
    private var syllabusExport: SyllabusFileExport? = null
    private var inspectorChannel: MethodChannel? = null
    private var inspectorReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        recordingChannel = ClassRecordingChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        syllabusExport = SyllabusFileExport(this, flutterEngine.dartExecutor.binaryMessenger)
        if ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) == 0) return

        inspectorChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        inspectorChannel?.setMethodCallHandler { call, result ->
            if (call.method == "initialize") {
                inspectorReady = true
                result.success(consumeInspectorIntent())
                enableInspectorNotification()
            } else {
                result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        recordingChannel?.dispose()
        recordingChannel = null
        syllabusExport?.dispose()
        syllabusExport = null
        inspectorReady = false
        inspectorChannel?.setMethodCallHandler(null)
        inspectorChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (inspectorReady && consumeInspectorIntent()) {
            inspectorChannel?.invokeMethod("open", null)
        }
    }

    override fun onResume() {
        super.onResume()
        if (inspectorReady) postInspectorNotification()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        recordingChannel?.onRequestPermissionsResult(requestCode, grantResults)
        if (requestCode == PERMISSION_REQUEST && inspectorReady) postInspectorNotification()
    }

    @Deprecated("Android screen-capture consent and document picker return activity results")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        recordingChannel?.onActivityResult(requestCode, resultCode, data)
        syllabusExport?.onActivityResult(requestCode, resultCode, data)
    }

    private fun consumeInspectorIntent(): Boolean {
        val launchIntent = intent ?: return false
        if (launchIntent.action != OPEN_INSPECTOR) return false
        launchIntent.action = null
        return true
    }

    private fun canPostInspectorNotification(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun enableInspectorNotification() {
        if (canPostInspectorNotification()) {
            postInspectorNotification()
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val preferences = getPreferences(MODE_PRIVATE)
            if (!preferences.getBoolean("inspector_notification_requested", false)) {
                preferences.edit().putBoolean("inspector_notification_requested", true).apply()
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun postInspectorNotification() {
        if (!canPostInspectorNotification()) return

        val notifications = getSystemService(NotificationManager::class.java)
        if (!notifications.areNotificationsEnabled()) return

        val openInspector = Intent(this, MainActivity::class.java)
            .setAction(OPEN_INSPECTOR)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val shortcut = PendingIntent.getActivity(
            this, 0, openInspector, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notifications.createNotificationChannel(
                NotificationChannel(NOTIFICATION_CHANNEL, "Debug HTTP inspector", NotificationManager.IMPORTANCE_LOW),
            )
            Notification.Builder(this, NOTIFICATION_CHANNEL)
        } else {
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.stat_notify_sync_noanim)
            .setContentTitle("Chucker HTTP inspector")
            .setContentText("Tap to view API requests and responses")
            .setContentIntent(shortcut)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .build()
        notifications.notify(NOTIFICATION_ID, notification)
    }

    companion object {
        private const val CHANNEL_NAME = "promptlearn/http_inspector"
        private const val OPEN_INSPECTOR = "com.promptlearn.promptlearn.OPEN_HTTP_INSPECTOR"
        private const val NOTIFICATION_CHANNEL = "debug_http_inspector"
        private const val NOTIFICATION_ID = 401
        private const val PERMISSION_REQUEST = 402
    }
}
