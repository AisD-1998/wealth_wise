import 'package:flutter/foundation.dart';

class Logger {
  final String _name;

  Logger([this._name = '']);

  void info(String message) {
    if (kDebugMode) {
      print('[INFO]${_name.isNotEmpty ? ' $_name:' : ''} $message');
    }
  }

  void warning(String message) {
    if (kDebugMode) {
      print('[WARNING]${_name.isNotEmpty ? ' $_name:' : ''} $message');
    }
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('[ERROR]${_name.isNotEmpty ? ' $_name:' : ''} $message');
      if (error != null) {
        print('Error: $error');
      }
      if (stackTrace != null) {
        print('StackTrace: $stackTrace');
      }
    }
  }

  void debug(String message) {
    if (kDebugMode) {
      print('[DEBUG]${_name.isNotEmpty ? ' $_name:' : ''} $message');
    }
  }
}
