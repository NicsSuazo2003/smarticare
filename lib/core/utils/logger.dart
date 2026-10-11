import 'package:flutter/foundation.dart';

class Logger {
  Logger._();
  static void d(String message) { if (kDebugMode) debugPrint('🐛 $message'); }
  static void i(String message) { if (kDebugMode) debugPrint('ℹ️ $message'); }
  static void w(String message) { if (kDebugMode) debugPrint('⚠️ $message'); }
  static void e(String message, [Object? error, StackTrace? stack]) { if (kDebugMode) debugPrint('❌ $message${error != null ? ' — $error' : ''}'); }
}
