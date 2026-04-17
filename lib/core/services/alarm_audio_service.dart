import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AlarmAudioService {
  AlarmAudioService._();

  static final AlarmAudioService instance = AlarmAudioService._();

  static const MethodChannel _alarmChannel = MethodChannel('medivoice/alarm');
  static const MethodChannel _voiceChannel = MethodChannel('medivoice/voice');

  bool get supportsNativeVoice =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> playAlarm() async {
    if (!Platform.isAndroid) return;
    await _alarmChannel.invokeMethod('playAlarm');
  }

  Future<void> stopAlarm() async {
    if (!Platform.isAndroid) return;
    await _alarmChannel.invokeMethod('stopAlarm');
  }

  Future<void> startVibration() async {
    if (!Platform.isAndroid) return;
    await _alarmChannel.invokeMethod('startVibration');
  }

  Future<void> stopVibration() async {
    if (!Platform.isAndroid) return;
    await _alarmChannel.invokeMethod('stopVibration');
  }

  Future<void> startRecording() async {
    if (!supportsNativeVoice) {
      throw UnsupportedError(
        'Voice recording is only available on mobile devices.',
      );
    }
    await _voiceChannel.invokeMethod('startRecording');
  }

  Future<String?> stopRecording() async {
    if (!supportsNativeVoice) return null;
    return _voiceChannel.invokeMethod<String>('stopRecording');
  }

  Future<int?> playRecording(String path) async {
    if (!supportsNativeVoice || path.isEmpty) return null;
    return _voiceChannel.invokeMethod<int>('playRecording', {
      'path': path,
    });
  }

  Future<void> stopPlayback() async {
    if (!supportsNativeVoice) return;
    await _voiceChannel.invokeMethod('stopPlayback');
  }

  Future<void> playReminderSequence(String? audioPath) async {
    await stopPlayback();
    await stopAlarm();
    await playAlarm();
    await Future.delayed(const Duration(seconds: 6));
    await stopAlarm();
    if (audioPath != null && audioPath.isNotEmpty) {
      await playRecording(audioPath);
    }
  }
}
