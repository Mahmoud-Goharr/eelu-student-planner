import 'dart:io';

class NetworkProbe {
  NetworkProbe._();

  static Future<bool> isOnline({Duration timeout = const Duration(seconds: 2)}) async {
    try {
      final result = await InternetAddress.lookup('example.com').timeout(timeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
