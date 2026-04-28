import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Lokal backend test için false yap.
  static const bool useProd = true;

  // Lokal makinenin LAN IP'si (telefon fiziksel cihazda test ederken).
  // Aynı wifi'ye bağlı olmalı. Terminalde: ipconfig getifaddr en0
  static const String _lanIp = '10.205.122.115';
  static const int _port = 5009;

  static String get baseUrl {
    if (useProd) return 'https://api.apphealzy.com';

    if (kIsWeb) return 'http://localhost:$_port';
    if (Platform.isAndroid) return 'http://10.0.2.2:$_port'; // Android emulator
    // iOS fiziksel cihaz: LAN IP. Simulator'da da LAN IP calisir.
    return 'http://$_lanIp:$_port';
  }
}
