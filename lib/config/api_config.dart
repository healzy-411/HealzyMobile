class ApiConfig {
  static const bool useProd = true;

  static String get baseUrl =>
      useProd ? 'https://api.apphealzy.com' : 'http://localhost:5009';
}
