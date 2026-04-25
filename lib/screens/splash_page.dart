import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SplashPage extends StatefulWidget {
  final Widget nextPage;

  /// Safety cap — from WebView page-load. If SplashDone channel doesn't fire
  /// by then (e.g. JS error, channel not wired), we navigate anyway.
  final Duration safetyTimeout;

  const SplashPage({
    super.key,
    required this.nextPage,
    this.safetyTimeout = const Duration(seconds: 6),
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final WebViewController _controller;
  Timer? _safetyTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A1F36))
      ..addJavaScriptChannel(
        'SplashDone',
        onMessageReceived: (_) => _goNext(),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            // Animation runs once HTML has loaded; fallback if channel never fires.
            _safetyTimer?.cancel();
            _safetyTimer = Timer(widget.safetyTimeout, _goNext);
          },
        ),
      )
      ..loadFlutterAsset('assets/splash/splash.html');
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _safetyTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.nextPage,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0A1F36),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1F36),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
