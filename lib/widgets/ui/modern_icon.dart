import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Tile ortasında çıplak büyük ikon (etrafında kutu yok).
class ModernIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const ModernIcon({
    super.key,
    required this.icon,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.pearl : AppColors.midnight;
    return Icon(icon, color: fg, size: size);
  }
}
