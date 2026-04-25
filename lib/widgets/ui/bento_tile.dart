import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';

/// Modern bento-grid tile. Icon + title + (optional) subtitle. Tappable with scale.
class BentoTile extends StatefulWidget {
  final IconData icon;
  final Widget? customIcon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? iconBg;
  final Color? iconColor;
  final double height;
  final bool featured;

  const BentoTile({
    super.key,
    required this.icon,
    this.customIcon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.gradient,
    this.iconBg,
    this.iconColor,
    this.height = 120,
    this.featured = false,
  });

  @override
  State<BentoTile> createState() => _BentoTileState();
}

class _BentoTileState extends State<BentoTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = widget.gradient != null
        ? null
        : (widget.featured
            ? (isDark ? AppColors.pearl : AppColors.midnight)
            : Colors.transparent);
    final gradient = widget.gradient ??
        (widget.featured
            ? (isDark ? AppColors.pearlGradient : AppColors.primaryGradient)
            : null);

    final titleColor = widget.featured
        ? (isDark ? AppColors.midnight : AppColors.pearl)
        : (isDark ? AppColors.darkTextPrimary : AppColors.midnight);
    final subColor = widget.featured
        ? titleColor.withValues(alpha: 0.75)
        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary);

    final iconBg = widget.iconBg ??
        (widget.featured
            ? (isDark ? AppColors.midnight : AppColors.pearl)
                .withValues(alpha: 0.15)
            : (isDark
                ? AppColors.pearl.withValues(alpha: 0.08)
                : AppColors.midnight.withValues(alpha: 0.06)));
    final iconColor = widget.iconColor ??
        (widget.featured
            ? (isDark ? AppColors.midnight : AppColors.pearl)
            : (isDark ? AppColors.pearl : AppColors.midnight));

    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : AppColors.midnight)
                    .withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.featured
                      ? bg
                      : (isDark ? AppColors.darkSurface : AppColors.lightBlueSoft)
                          .withValues(alpha: 0.45),
                  gradient: gradient,
                  border: widget.featured
                      ? null
                      : Border.all(
                          color: isDark
                              ? AppColors.darkBorder.withValues(alpha: 0.4)
                              : AppColors.midnight.withValues(alpha: 0.15),
                          width: 1.2,
                        ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
          child: Stack(
            children: [
              Center(
                child: widget.customIcon ??
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(widget.icon, color: iconColor, size: 32),
                    ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.1,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
