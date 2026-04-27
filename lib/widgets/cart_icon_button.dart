import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';

/// Home page'deki sepet ikonuyla birebir aynı görünümü veren paylaşılan widget.
/// Tüm sepete-götüren ikonlarda kullanılmalı.
class CartIconButton extends StatelessWidget {
  final int badge;
  final VoidCallback onTap;

  const CartIconButton({
    super.key,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.8)
        : AppColors.pearl;
    final iconColor = isDark ? AppColors.darkTextPrimary : AppColors.midnight;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: bg,
          elevation: 0,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.border.withValues(alpha: 0.6),
                ),
                boxShadow: AppShadows.soft(isDark),
              ),
              child: Icon(Icons.shopping_bag_outlined, color: iconColor, size: 20),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: bg, width: 2),
              ),
              child: Text(
                badge > 9 ? '9+' : '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
