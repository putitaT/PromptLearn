package com.promptlearn.promptlearn

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

internal class SyllabusFileExport(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "promptlearn/syllabus_export")
    private var pending: PendingExport? = null

    init {
        channel.setMethodCallHandler(::onMethodCall)
    }

    @Suppress("DEPRECATION")
    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "saveHtml") {
            result.notImplemented()
            return
        }
        val fileName = call.argument<String>("fileName")
        val contents = call.argument<ByteArray>("contents")
        if (fileName.isNullOrBlank() || contents == null || contents.isEmpty()) {
            result.error("invalid_document", "An HTML filename and document are required.", null)
            return
        }
        if (pending != null) {
            result.error("export_in_progress", "Another syllabus export is in progress.", null)
            return
        }

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("text/html")
            .putExtra(Intent.EXTRA_TITLE, fileName)
        pending = PendingExport(contents, result)
        try {
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (exception: ActivityNotFoundException) {
            pending = null
            result.error("file_picker_unavailable", "Android could not open the file picker.", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_CODE) return
        val export = pending ?: return
        pending = null
        if (resultCode != Activity.RESULT_OK) {
            export.result.success(false)
            return
        }
        val uri = data?.data
        if (uri == null) {
            export.result.error("missing_document", "Android did not return a file destination.", null)
            return
        }

        Thread {
            val saved = runCatching {
                val stream = activity.contentResolver.openOutputStream(uri, "w")
                    ?: throw IOException("Could not open the file destination")
                stream.use { it.write(export.contents) }
            }
            activity.runOnUiThread {
                if (saved.isSuccess) {
                    export.result.success(true)
                } else {
                    export.result.error("write_failed", "Could not write the syllabus file.", null)
                }
            }
        }.start()
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pending?.result?.success(false)
        pending = null
    }

    private data class PendingExport(val contents: ByteArray, val result: MethodChannel.Result)

    private companion object {
        const val REQUEST_CODE = 403
    }
}
