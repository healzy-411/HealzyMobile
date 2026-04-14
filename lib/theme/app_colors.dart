import 'package:flutter/material.dart';

class AppColors {
  // Marka renkleri
  static const Color midnight = Color(0xFF102E4A);
  static const Color midnightSoft = Color(0xFF1B4965);
  static const Color pearl = Color(0xFFFFFFFF);
  static const Color pearlWarm = Color(0xFFFFF8E8);

  // Accent (dikkat çeken ikincil)
  static const Color accent = Color(0xFF4FC3CF);
  static const Color accentSoft = Color(0xFFA9E5E8);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Nötr
  static const Color textPrimary = Color(0xFF0B1F33);
  static const Color textSecondary = Color(0xFF5A6B80);
  static const Color textTertiary = Color(0xFF8A97A8);
  static const Color border = Color(0xFFE4E8EE);
  static const Color surface = Color(0xFFF6F8FB);

  // Dark mode
  static const Color darkBg = Color(0xFF0A1A2B);
  static const Color darkSurface = Color(0xFF132B44);
  static const Color darkSurfaceElevated = Color(0xFF1B3A5C);
  static const Color darkBorder = Color(0xFF234968);
  static const Color darkTextPrimary = Color(0xFFF1F6FC);
  static const Color darkTextSecondary = Color(0xFFB0C2D6);
  static const Color darkTextTertiary = Color(0xFF7A8FA5);

  // Gradient preset'leri
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [midnight, midnightSoft],
  );

  static const LinearGradient pearlGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [pearl, pearlWarm],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, midnightSoft],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkBg, Color(0xFF0F2237)],
  );
}
