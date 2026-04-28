import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' show ClientException;

/// Hata objesini kullaniciya gosterilebilir bir Turkce mesaja cevirir.
/// Network/baglanti hatalarinda jenerik teknik mesaj yerine
/// "Internet baglantinizi kontrol edin." doner.
String friendlyError(Object e) {
  if (e is SocketException || e is ClientException || e is HttpException) {
    return 'İnternet bağlantınızı kontrol edin.';
  }
  if (e is TimeoutException) {
    return 'İstek zaman aşımına uğradı. Lütfen tekrar deneyin.';
  }

  final raw = e.toString();
  // http paketi bazen "ClientException" stringini Exception ile birlikte yazar
  if (raw.contains('ClientException') ||
      raw.contains('SocketException') ||
      raw.contains('Failed host lookup') ||
      raw.contains('Connection refused') ||
      raw.contains('Network is unreachable') ||
      raw.contains('Connection closed') ||
      raw.contains('Connection reset')) {
    return 'İnternet bağlantınızı kontrol edin.';
  }

  return raw.replaceFirst('Exception: ', '');
}
