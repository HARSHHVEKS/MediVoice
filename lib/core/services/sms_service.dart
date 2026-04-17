import 'dart:io';

import 'package:flutter/services.dart';

class SmsService {
  SmsService._();

  static final SmsService instance = SmsService._();

  static const MethodChannel _channel = MethodChannel(
    'medivoice/sms',
  );

  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    if (!Platform.isAndroid) return false;

    final sent = await _channel.invokeMethod<bool>('sendSms', {
      'phoneNumber': phoneNumber,
      'message': message,
    });

    return sent ?? false;
  }
}
