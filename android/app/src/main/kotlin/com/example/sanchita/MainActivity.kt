package com.example.sanchita

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class MainActivity : FlutterFragmentActivity() {
    private val downloadExportChannel = "sanchita/downloads_export"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            downloadExportChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveImageToDownloads") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val fileName = call.argument<String>("fileName")
            val folderPath = call.argument<String>("folderPath")
            val bytes = call.argument<ByteArray>("bytes")

            if (fileName.isNullOrBlank() || bytes == null || bytes.isEmpty()) {
                result.error(
                    "invalid_args",
                    "fileName and image bytes are required.",
                    null,
                )
                return@setMethodCallHandler
            }

            try {
                val savedLocation = saveImageToDownloads(
                    fileName = fileName,
                    folderPath = folderPath ?: "sanchita/vault",
                    bytes = bytes,
                )
                result.success(savedLocation)
            } catch (error: Exception) {
                result.error(
                    "save_failed",
                    error.message ?: "Unknown export failure.",
                    null,
                )
            }
        }
    }

    private fun saveImageToDownloads(
        fileName: String,
        folderPath: String,
        bytes: ByteArray,
    ): String {
        val normalizedFolderPath = normalizeFolderPath(folderPath)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/$normalizedFolderPath",
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val uri = resolver.insert(collection, values)
                ?: throw IOException("Failed to create download entry.")

            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: throw IOException("Unable to open output stream for export.")

            val finalizeValues = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            resolver.update(uri, finalizeValues, null, null)

            return "Downloads/$normalizedFolderPath/$fileName"
        }

        @Suppress("DEPRECATION")
        val downloadsDir = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS,
        )
        val targetDir = File(downloadsDir, normalizedFolderPath)
        if (!targetDir.exists() && !targetDir.mkdirs()) {
            throw IOException("Failed to create target directory.")
        }
        val file = File(targetDir, fileName)
        FileOutputStream(file).use { output ->
            output.write(bytes)
            output.flush()
        }
        return file.absolutePath
    }

    private fun normalizeFolderPath(rawPath: String): String {
        val sanitized = rawPath
            .replace("\\", "/")
            .split("/")
            .map { it.trim() }
            .filter { it.isNotEmpty() && it != "." && it != ".." }
            .joinToString("/")

        if (sanitized.isBlank()) {
            return "sanchita/vault"
        }
        return sanitized
    }
}
