package com.example.medicine_reminder

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Environment
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.telephony.SmsManager
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val ALARM_CHANNEL = "medivoice/alarm"
    private val VOICE_CHANNEL = "medivoice/voice"
    private val SMS_CHANNEL = "medivoice/sms"
    private val AUDIO_PERMISSION_REQUEST = 202
    private val SMS_PERMISSION_REQUEST = 203

    private var ringtone: Ringtone? = null
    private var recorder: MediaRecorder? = null
    private var mediaPlayer: MediaPlayer? = null
    private var recordingFilePath: String? = null
    private var pendingVoiceResult: MethodChannel.Result? = null
    private var pendingSmsResult: MethodChannel.Result? = null
    private var pendingSmsPhone: String? = null
    private var pendingSmsMessage: String? = null
    private var vibrator: Vibrator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ALARM_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "playAlarm" -> playAlarm(result)
                "stopAlarm" -> stopAlarm(result)
                "startVibration" -> startVibration(result)
                "stopVibration" -> stopVibration(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOICE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> startRecording(result)
                "stopRecording" -> stopRecording(result)
                "playRecording" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("NO_PATH", "Audio path is missing", null)
                    } else {
                        playRecording(path, result)
                    }
                }
                "stopPlayback" -> stopPlayback(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")

                    if (phoneNumber.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error("INVALID_SMS", "Phone number or message missing", null)
                    } else {
                        sendSms(phoneNumber, message, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        stopRecorderSilently()
        stopPlayerSilently()
        ringtone?.stop()
        vibrator?.cancel()
        ringtone = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            AUDIO_PERMISSION_REQUEST -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    val result = pendingVoiceResult
                    pendingVoiceResult = null
                    if (result != null) {
                        startRecording(result)
                    }
                } else {
                    pendingVoiceResult?.error(
                        "PERMISSION_DENIED",
                        "Microphone permission was denied",
                        null
                    )
                    pendingVoiceResult = null
                }
            }
            SMS_PERMISSION_REQUEST -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    val result = pendingSmsResult
                    val phoneNumber = pendingSmsPhone
                    val message = pendingSmsMessage
                    pendingSmsResult = null
                    pendingSmsPhone = null
                    pendingSmsMessage = null

                    if (result != null && !phoneNumber.isNullOrBlank() && !message.isNullOrBlank()) {
                        sendSms(phoneNumber, message, result)
                    }
                } else {
                    pendingSmsResult?.success(false)
                    pendingSmsResult = null
                    pendingSmsPhone = null
                    pendingSmsMessage = null
                }
            }
        }
    }

    private fun playAlarm(result: MethodChannel.Result) {
        try {
            ringtone?.stop()
            val alarmUri: Uri = RingtoneManager.getDefaultUri(
                RingtoneManager.TYPE_ALARM
            ) ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            ringtone = RingtoneManager.getRingtone(applicationContext, alarmUri)
            ringtone?.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ringtone?.isLooping = true
            }

            ringtone?.play()
            result.success("playing")
        } catch (e: Exception) {
            result.error("ALARM_ERROR", e.message, null)
        }
    }

    private fun stopAlarm(result: MethodChannel.Result) {
        try {
            ringtone?.stop()
            ringtone = null
            result.success("stopped")
        } catch (e: Exception) {
            result.error("STOP_ERROR", e.message, null)
        }
    }

    private fun startVibration(result: MethodChannel.Result) {
        try {
            val deviceVibrator = getDeviceVibrator()
            if (deviceVibrator == null || !deviceVibrator.hasVibrator()) {
                result.success("unsupported")
                return
            }

            vibrator = deviceVibrator

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createWaveform(
                    longArrayOf(0, 700, 400),
                    0
                )
                deviceVibrator.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                deviceVibrator.vibrate(longArrayOf(0, 700, 400), 0)
            }

            result.success("vibrating")
        } catch (e: Exception) {
            result.error("VIBRATION_ERROR", e.message, null)
        }
    }

    private fun stopVibration(result: MethodChannel.Result) {
        try {
            vibrator?.cancel()
            result.success("stopped")
        } catch (e: Exception) {
            result.error("STOP_VIBRATION_ERROR", e.message, null)
        }
    }

    private fun startRecording(result: MethodChannel.Result) {
        if (!hasAudioPermission()) {
            pendingVoiceResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                AUDIO_PERMISSION_REQUEST
            )
            return
        }

        try {
            stopRecorderSilently()
            stopPlayerSilently()

            val outputDir = File(
                getExternalFilesDir(Environment.DIRECTORY_MUSIC),
                "doctor_notes"
            )
            if (!outputDir.exists()) {
                outputDir.mkdirs()
            }

            val outputFile = File(
                outputDir,
                "doctor_note_${System.currentTimeMillis()}.m4a"
            )
            recordingFilePath = outputFile.absolutePath

            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(applicationContext)
            } else {
                MediaRecorder()
            }.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(128000)
                setAudioSamplingRate(44100)
                setOutputFile(recordingFilePath)
                prepare()
                start()
            }

            result.success("recording")
        } catch (e: Exception) {
            stopRecorderSilently()
            recordingFilePath = null
            result.error("RECORDING_ERROR", e.message, null)
        }
    }

    private fun sendSms(
        phoneNumber: String,
        message: String,
        result: MethodChannel.Result
    ) {
        if (!hasSmsPermission()) {
            pendingSmsResult = result
            pendingSmsPhone = phoneNumber
            pendingSmsMessage = message
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.SEND_SMS),
                SMS_PERMISSION_REQUEST
            )
            return
        }

        try {
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            val parts = smsManager.divideMessage(message)
            smsManager.sendMultipartTextMessage(
                phoneNumber,
                null,
                parts,
                null,
                null
            )
            result.success(true)
        } catch (e: Exception) {
            result.error("SMS_ERROR", e.message, null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        val currentPath = recordingFilePath

        if (recorder == null || currentPath.isNullOrBlank()) {
            result.success(null)
            return
        }

        try {
            recorder?.stop()
            recorder?.reset()
            recorder?.release()
            recorder = null
            recordingFilePath = null
            result.success(currentPath)
        } catch (e: RuntimeException) {
            stopRecorderSilently()
            File(currentPath).delete()
            recordingFilePath = null
            result.error("STOP_RECORDING_ERROR", e.message, null)
        }
    }

    private fun playRecording(path: String, result: MethodChannel.Result) {
        try {
            stopPlayerSilently()

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )

                val audioFile = File(path)
                if (audioFile.exists()) {
                    setDataSource(path)
                } else {
                    setDataSource(this@MainActivity, Uri.parse(path))
                }

                setOnCompletionListener {
                    stopPlayerSilently()
                }
                prepare()
                start()
                result.success(duration)
            }
        } catch (e: IOException) {
            stopPlayerSilently()
            result.error("PLAYBACK_ERROR", e.message, null)
        } catch (e: IllegalArgumentException) {
            stopPlayerSilently()
            result.error("PLAYBACK_ERROR", e.message, null)
        }
    }

    private fun stopPlayback(result: MethodChannel.Result) {
        stopPlayerSilently()
        result.success("stopped")
    }

    private fun stopRecorderSilently() {
        try {
            recorder?.reset()
            recorder?.release()
        } catch (_: Exception) {
        } finally {
            recorder = null
        }
    }

    private fun stopPlayerSilently() {
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {
        }

        try {
            mediaPlayer?.reset()
            mediaPlayer?.release()
        } catch (_: Exception) {
        } finally {
            mediaPlayer = null
        }
    }

    private fun hasAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun getDeviceVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as Vibrator
        }
    }
}
