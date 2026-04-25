import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'auth_page.dart';
import 'home_page.dart';

class GetStartedPage extends StatefulWidget {
  final AuthService authService;

  const GetStartedPage({super.key, required this.authService});

  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeIn;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onGetStarted() {
    if (_navigating) return;
    setState(() => _navigating = true);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => AuthPage(
          authService: widget.authService,
          customerHome: const HomePage(),
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkBg : AppColors.midnight;
    final circleColor = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.white.withValues(alpha: 0.05);
    final titleColor = isDark ? AppColors.darkTextPrimary : AppColors.pearl;
    final subtitleColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.pearl;
    final btnBorderColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.2);
    final btnBgColor = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.3)
        : AppColors.midnight.withValues(alpha: 0.1);
    final shadowColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.3);

    return Scaffold(
      backgroundColor: bgColor,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Stack(
          children: [
            // Sag ust dekorasyon
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Sol alt dekorasyon
            Positioned(
              bottom: -80,
              left: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // HEALZY
                  Center(
                    child: Text(
                      "HEALZY",
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 64,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    "Sağlığınız için dijital köprü.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subtitleColor.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Hemen Basla butonu
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
                    child: GestureDetector(
                      onTap: _onGetStarted,
                      child: AnimatedOpacity(
                        opacity: _navigating ? 0.5 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                height: 70,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: btnBgColor,
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: btnBorderColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Hemen Basla",
                                      style: TextStyle(
                                        color: titleColor,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(Icons.arrow_forward_rounded, color: titleColor),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
