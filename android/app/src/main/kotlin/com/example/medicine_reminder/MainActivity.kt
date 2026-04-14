package com.example.medicine_reminder

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // Must match exactly what Flutter calls
    private val CHANNEL = "medivoice/recorder"
    private val RECORD_REQUEST_CODE = 101

    // Hold the result callback between Activity launch and result
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "recordAudio" -> {
                    // Store result — we return it in onActivityResult
                    pendingResult = result

                    // Launch Android's built-in voice recorder
                    // This is on EVERY Android phone — no package needed
                    val intent = Intent(
                        MediaStore.Audio.Media.RECORD_SOUND_ACTION
                    )

                    // Check if any app can handle this intent
                    if (intent.resolveActivity(packageManager) != null) {
                        startActivityForResult(intent, RECORD_REQUEST_CODE)
                    } else {
                        // No voice recorder app found on device
                        pendingResult = null
                        result.error(
                            "NO_RECORDER",
                            "No voice recorder app found on this device",
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == RECORD_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {

                // Get the URI of the saved recording
                val audioUri: Uri? = data.data

                if (audioUri != null) {
                    // Convert URI to real file path
                    val filePath = getRealPathFromUri(audioUri)

                    if (filePath != null) {
                        // ✅ Return path to Flutter
                        pendingResult?.success(filePath)
                        android.util.Log.d(
                            "MediVoice",
                            "✅ Audio saved: $filePath"
                        )
                    } else {
                        // URI exists but path conversion failed
                        // Return the URI string as fallback
                        pendingResult?.success(audioUri.toString())
                        android.util.Log.d(
                            "MediVoice",
                            "⚠️ Using URI fallback: $audioUri"
                        )
                    }
                } else {
                    // No data returned
                    pendingResult?.success(null)
                }
            } else {
                // User cancelled or back pressed
                pendingResult?.success(null)
            }

            pendingResult = null
        }
    }

    // Convert content URI to real file path
    private fun getRealPathFromUri(uri: Uri): String? {
        return try {
            val projection = arrayOf(
                MediaStore.Audio.Media.DATA
            )
            val cursor = contentResolver.query(
                uri, projection, null, null, null
            )
            cursor?.use {
                if (it.moveToFirst()) {
                    val columnIndex = it.getColumnIndexOrThrow(
                        MediaStore.Audio.Media.DATA
                    )
                    it.getString(columnIndex)
                } else null
            }
        } catch (e: Exception) {
            android.util.Log.e(
                "MediVoice",
                "❌ Path conversion failed: ${e.message}"
            )
            null
        }
    }
}