package com.promptlearn.promptlearn

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.DisplayMetrics
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

internal class ClassRecordingChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : EventChannel.StreamHandler {
    private val methods = MethodChannel(messenger, "promptlearn/class_recording")
    private val events = EventChannel(messenger, "promptlearn/class_recording/events")
    private var pending: MethodChannel.Result? = null
    private var source = "screen"

    init {
        events.setStreamHandler(this)
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(ClassRecordingState.snapshot())
                "savedClips" -> result.success(ClassRecordingService.savedClips(activity))
                "start" -> start(call.arguments as? String, result)
                "stop" -> stop(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        ClassRecordingState.onChange = sink::success
        sink.success(ClassRecordingState.snapshot())
    }

    override fun onCancel(arguments: Any?) {
        ClassRecordingState.onChange = null
    }

    fun dispose() {
        onCancel(null)
        finishRequest("interrupted", "The capture request was interrupted. Try again.")
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    private fun start(requestedSource: String?, result: MethodChannel.Result) {
        if (requestedSource != "screen" && requestedSource != "slides") {
            result.error("invalid_source", "Choose a recording source.", null)
            return
        }
        if (pending != null || ClassRecordingState.inProgress) {
            result.error("busy", "A recording is already starting or running.", null)
            return
        }

        pending = result
        source = requestedSource
        if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            requestProjection()
        } else {
            activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), MIC_REQUEST)
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != MIC_REQUEST || pending == null) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            requestProjection()
        } else {
            finishRequest(
                "microphone_denied",
                "Allow microphone access for PromptLearn in Android settings to record narration.",
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun requestProjection() {
        try {
            val manager = activity.getSystemService(MediaProjectionManager::class.java)
            val consent = if (source == "screen" && Build.VERSION.SDK_INT >= 34) {
                manager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay())
            } else {
                manager.createScreenCaptureIntent()
            }
            activity.startActivityForResult(consent, PROJECTION_REQUEST)
        } catch (error: RuntimeException) {
            finishRequest("capture_unavailable", "Android could not open screen sharing.")
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PROJECTION_REQUEST || pending == null) return
        if (resultCode != Activity.RESULT_OK || data == null) {
            finishRequest("cancelled", "Screen sharing was cancelled.")
            return
        }

        try {
            val (width, height) = displaySize()
            val command = Intent(activity, ClassRecordingService::class.java)
                .setAction(ClassRecordingService.START)
                .putExtra("projection", data)
                .putExtra("source", source)
                .putExtra("width", width)
                .putExtra("height", height)
                .putExtra("density", activity.resources.displayMetrics.densityDpi)

            ClassRecordingState.publish("starting", source = source)
            if (Build.VERSION.SDK_INT >= 26) activity.startForegroundService(command)
            else activity.startService(command)
            finishRequest()
        } catch (error: RuntimeException) {
            ClassRecordingState.publish("failed", message = "Android could not start screen recording.")
            finishRequest("start_failed", "Android could not start screen recording.")
        }
    }

    @Suppress("DEPRECATION")
    private fun displaySize(): Pair<Int, Int> {
        if (Build.VERSION.SDK_INT >= 30) {
            val bounds = activity.windowManager.maximumWindowMetrics.bounds
            return Pair(bounds.width(), bounds.height())
        }
        val metrics = DisplayMetrics()
        activity.windowManager.defaultDisplay.getRealMetrics(metrics)
        return Pair(metrics.widthPixels, metrics.heightPixels)
    }

    private fun stop(result: MethodChannel.Result) {
        if (ClassRecordingState.inProgress) {
            try {
                activity.startService(
                    Intent(activity, ClassRecordingService::class.java)
                        .setAction(ClassRecordingService.STOP),
                )
            } catch (error: RuntimeException) {
                result.error("stop_failed", "Could not stop the recording. Try again.", null)
                return
            }
        }
        result.success(null)
    }

    private fun finishRequest(code: String? = null, message: String? = null) {
        val result = pending ?: return
        pending = null
        if (code == null) result.success(null)
        else result.error(code, message, null)
    }

    companion object {
        private const val PROJECTION_REQUEST = 601
        private const val MIC_REQUEST = 602
    }
}
