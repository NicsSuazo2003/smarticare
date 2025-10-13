import 'package:flutter/services.dart';

class EyeDetectionChannel {
  static const MethodChannel _channel = MethodChannel('eye_detection_channel');

  static Future<bool> isEyeInImage(String imagePath) async {
    final bool isEye =
        await _channel.invokeMethod('isEyeInImage', {'imagePath': imagePath});
    return isEye;
  }
}
