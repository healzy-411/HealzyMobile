import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';

/// Modern bento-grid tile. Icon + title + (optional) subtitle. Tappable with scale.
class BentoTile extends StatefulWidget {
  final IconData icon;
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
            : (isDark ? AppColors.darkSurface : AppColors.pearl));
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.soft(isDark),
            border: widget.featured
                ? null
                : Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.border.withValues(alpha: 0.6),
                    width: 1,
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(widget.icon, color: iconColor, size: 20),
              ),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
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
                          fontSize: 11,
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
    );
  }
}
