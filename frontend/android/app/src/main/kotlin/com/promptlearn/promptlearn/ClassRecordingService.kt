package com.promptlearn.promptlearn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.io.IOException
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

// State and channel callbacks are accessed on the main looper.
internal object ClassRecordingState {
    private var phase = "idle"
    private var details = mapOf<String, Any?>()
    private var startedAt = 0L
    var onChange: ((Map<String, Any?>) -> Unit)? = null

    val inProgress: Boolean
        get() = phase == "starting" || phase == "recording" || phase == "saving"

    fun snapshot(): Map<String, Any?> {
        val elapsed = if (startedAt == 0L) 0L else SystemClock.elapsedRealtime() - startedAt
        return details + mapOf("phase" to phase, "elapsedMs" to elapsed)
    }

    fun publish(
        phase: String,
        source: String? = null,
        startedAt: Long = 0L,
        clip: Map<String, Any>? = null,
        interrupted: Boolean = false,
        message: String? = null,
    ) {
        this.phase = phase
        this.startedAt = startedAt
        details = mapOf(
            "source" to source,
            "clip" to clip,
            "interrupted" to interrupted,
            "message" to message,
        )
        onChange?.invoke(snapshot())
    }
}

class ClassRecordingService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private val workerThread = HandlerThread("PromptLearnEncoder")
    private lateinit var worker: Handler
    private var startAccepted = false
    private var projection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var recorder: MediaRecorder? = null
    private var stagingFile: File? = null
    private var started = false
    private var finishing = false
    private var source = "screen"

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            finish(interrupted = true)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        workerThread.start()
        worker = Handler(workerThread.looper)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            START -> if (!startAccepted) {
                startAccepted = true
                try {
                    promoteToForeground()
                    worker.post { begin(intent) }
                } catch (error: RuntimeException) {
                    Log.w(TAG, "Could not start recording foreground service", error)
                    worker.post { finish(errorMessage = "Android could not start the recording service.") }
                }
            }
            STOP -> worker.post { finish() }
            else -> stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun promoteToForeground() {
        val notification = recordingNotification()
        if (Build.VERSION.SDK_INT >= 30) {
            startForeground(
                NOTIFICATION_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    @Suppress("DEPRECATION")
    private fun recordingNotification(): Notification {
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this, 1, Intent(this, ClassRecordingService::class.java).setAction(STOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Class recording", NotificationManager.IMPORTANCE_LOW),
            )
            Notification.Builder(this, CHANNEL)
        } else {
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }
        return builder
            .setSmallIcon(android.R.drawable.presence_video_online)
            .setContentTitle("PromptLearn is recording")
            .setContentText("Your screen and microphone are being recorded.")
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(android.R.drawable.ic_media_pause, "Stop recording", stop).build())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    @Suppress("DEPRECATION")
    private fun begin(intent: Intent) {
        source = intent.getStringExtra("source") ?: "screen"
        try {
            val consent = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra("projection", Intent::class.java)
            } else {
                intent.getParcelableExtra<Intent>("projection")
            } ?: error("Missing screen-capture consent")
            val directory = recordingsDirectory(this).apply { mkdirs() }
            if (directory.usableSpace < 96 * MEBIBYTE) {
                finish(errorMessage = "Free some device storage before starting a recording.")
                return
            }
            directory.listFiles { file -> file.extension == "partial" }?.forEach { it.delete() }
            val staging = File(
                directory, "class-${System.currentTimeMillis()}-${UUID.randomUUID().toString().take(8)}.partial",
            )
            stagingFile = staging

            val displayWidth = intent.getIntExtra("width", 0)
            val displayHeight = intent.getIntExtra("height", 0)
            require(displayWidth > 0 && displayHeight > 0)
            val scale = min(1.0, 1600.0 / max(displayWidth, displayHeight))
            val width = max(2, (displayWidth * scale).toInt() / 2 * 2)
            val height = max(2, (displayHeight * scale).toInt() / 2 * 2)

            val manager = getSystemService(MediaProjectionManager::class.java)
            val capture = checkNotNull(manager.getMediaProjection(RESULT_OK, consent))
            projection = capture
            capture.registerCallback(projectionCallback, worker)

            val encoder = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(this) else MediaRecorder()
            recorder = encoder
            encoder.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setVideoSource(MediaRecorder.VideoSource.SURFACE)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setVideoEncoder(MediaRecorder.VideoEncoder.H264)
                setVideoSize(width, height)
                setVideoFrameRate(24)
                setVideoEncodingBitRate(2_500_000)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioChannels(1)
                setAudioSamplingRate(44_100)
                setAudioEncodingBitRate(96_000)
                setMaxFileSize(directory.usableSpace - 64 * MEBIBYTE)
                setOutputFile(staging.absolutePath)
                setOnErrorListener { _, _, _ ->
                    finish(interrupted = true, errorMessage = "The device stopped recording.")
                }
                setOnInfoListener { _, what, _ ->
                    if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_FILESIZE_REACHED) {
                        finish(interrupted = true, errorMessage = "Recording stopped because device storage is low.")
                    }
                }
                prepare()
            }
            virtualDisplay = checkNotNull(
                capture.createVirtualDisplay(
                    "PromptLearn class", width, height, intent.getIntExtra("density", 160),
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, encoder.surface,
                    null, worker,
                ),
            )
            encoder.start()
            started = true
            val startTime = SystemClock.elapsedRealtime()
            main.post { ClassRecordingState.publish("recording", source = source, startedAt = startTime) }
        } catch (error: RuntimeException) {
            Log.w(TAG, "Could not start screen recording", error)
            finish(errorMessage = "Screen recording could not start. Check mic access and try again.")
        } catch (error: IOException) {
            Log.w(TAG, "Could not open recording file", error)
            finish(errorMessage = "Could not create the video file on this device.")
        }
    }

    private fun finish(interrupted: Boolean = false, errorMessage: String? = null) {
        if (finishing) return
        finishing = true
        val hadStarted = started
        started = false
        if (hadStarted) main.post { ClassRecordingState.publish("saving", source = source) }

        if (hadStarted) runCatching { recorder?.stop() }
            .onFailure { Log.w(TAG, "Recorder stop did not complete cleanly", it) }
        runCatching { virtualDisplay?.release() }
        runCatching { recorder?.release() }
        runCatching {
            projection?.unregisterCallback(projectionCallback)
            projection?.stop()
        }

        val staging = stagingFile
        val output = staging?.let { File(it.parentFile, "${it.nameWithoutExtension}.mp4") }
        val clip = if (hadStarted && staging != null && output != null &&
            hasAudioAndVideo(staging) && staging.renameTo(output)
        ) {
            clipDetails(output)
        } else {
            staging?.delete()
            null
        }

        main.post {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            if (clip != null) {
                ClassRecordingState.publish(
                    "saved", source = source, clip = clip, interrupted = interrupted, message = errorMessage,
                )
            } else {
                ClassRecordingState.publish(
                    "failed", source = source, interrupted = interrupted,
                    message = errorMessage ?: "No playable clip was saved. Try recording for a few seconds.",
                )
            }
        }
    }

    override fun onDestroy() {
        worker.post { finish(interrupted = true) }
        workerThread.quitSafely()
        super.onDestroy()
    }

    private fun hasAudioAndVideo(file: File): Boolean {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(file.absolutePath)
            val mediaTypes = (0 until extractor.trackCount).mapNotNull { index ->
                val format = extractor.getTrackFormat(index)
                if (format.containsKey(MediaFormat.KEY_DURATION) &&
                    format.getLong(MediaFormat.KEY_DURATION) > 0
                ) format.getString(MediaFormat.KEY_MIME) else null
            }
            mediaTypes.any { it.startsWith("video/") } && mediaTypes.any { it.startsWith("audio/") }
        } catch (error: IOException) {
            false
        } catch (error: RuntimeException) {
            false
        } finally {
            extractor.release()
        }
    }

    companion object {
        const val START = "com.promptlearn.promptlearn.START_CLASS_RECORDING"
        const val STOP = "com.promptlearn.promptlearn.STOP_CLASS_RECORDING"
        private const val RESULT_OK = android.app.Activity.RESULT_OK
        private const val CHANNEL = "class_recording"
        private const val NOTIFICATION_ID = 611
        private const val MEBIBYTE = 1024L * 1024L
        private const val TAG = "ClassRecording"

        private fun recordingsDirectory(context: Context) = File(context.noBackupFilesDir, "class-recordings")

        fun savedClips(context: Context): List<Map<String, Any>> =
            recordingsDirectory(context).listFiles { file -> file.isFile && file.extension == "mp4" }
                .orEmpty()
                .sortedByDescending { it.lastModified() }
                .map(::clipDetails)

        private fun clipDetails(file: File): Map<String, Any> = mapOf(
            "path" to file.absolutePath,
            "name" to file.name,
            "sizeBytes" to file.length(),
            "savedAtMs" to file.lastModified(),
        )
    }
}
