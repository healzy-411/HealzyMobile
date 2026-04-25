import 'dart:ui';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../theme/app_colors.dart';
import '../screens/medicine_reminder_page.dart';
import '../screens/notifications_page.dart';
import '../screens/profile_page.dart';
import '../screens/home_map_fullscreen_page.dart';

enum HealzyNavTab { home, reminder, map, notifications, profile }

class HealzyBottomNav extends StatelessWidget {
  final HealzyNavTab? current;
  const HealzyBottomNav({super.key, this.current});

  void _go(BuildContext ctx, HealzyNavTab tab) {
    if (current == tab) return;

    if (tab == HealzyNavTab.home) {
      Navigator.of(ctx).popUntil((r) => r.isFirst);
      return;
    }

    final Widget page;
    switch (tab) {
      case HealzyNavTab.reminder:
        page = MedicineReminderPage(baseUrl: ApiConfig.baseUrl);
        break;
      case HealzyNavTab.map:
        page = const HomeMapFullscreenPage();
        break;
      case HealzyNavTab.notifications:
        page = const NotificationsPage();
        break;
      case HealzyNavTab.profile:
        page = ProfilePage(baseUrl: ApiConfig.baseUrl);
        break;
      case HealzyNavTab.home:
        return;
    }

    Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (r) => r.isFirst || r.settings.name == '/',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final inactive =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final active = isDark ? AppColors.pearl : AppColors.midnight;

    const double barHeight = 72;
    const double mapSize = 70;
    final double mapOverflow = (mapSize - barHeight) / 2 + 8;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: barHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkSurface : AppColors.lightBlueSoft)
                    .withValues(alpha: 0.75),
                border: Border(
                  top: BorderSide(
                    color: border.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Ana Sayfa',
                    selected: current == HealzyNavTab.home,
                    activeColor: active,
                    inactiveColor: inactive,
                    onTap: () => _go(context, HealzyNavTab.home),
                  ),
                  _NavItem(
                    icon: Icons.access_alarm_outlined,
                    activeIcon: Icons.access_alarm_rounded,
                    label: 'Hatırlatıcı',
                    selected: current == HealzyNavTab.reminder,
                    activeColor: active,
                    inactiveColor: inactive,
                    onTap: () => _go(context, HealzyNavTab.reminder),
                  ),
                  const Expanded(child: SizedBox()),
                  _NavItem(
                    icon: Icons.notifications_outlined,
                    activeIcon: Icons.notifications_rounded,
                    label: 'Bildirim',
                    selected: current == HealzyNavTab.notifications,
                    activeColor: active,
                    inactiveColor: inactive,
                    onTap: () => _go(context, HealzyNavTab.notifications),
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profil',
                    selected: current == HealzyNavTab.profile,
                    activeColor: active,
                    inactiveColor: inactive,
                    onTap: () => _go(context, HealzyNavTab.profile),
                  ),
                ],
              ),
            ),
          ),
          ),
            // Map button — tasan
            Positioned(
              top: -mapOverflow,
              left: 0,
              right: 0,
              child: Center(
                child: _MapButton(
                  size: mapSize,
                  selected: current == HealzyNavTab.map,
                  isDark: isDark,
                  onTap: () => _go(context, HealzyNavTab.map),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Icon(selected ? activeIcon : icon, size: 30, color: color),
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final double size;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _MapButton({
    required this.size,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppColors.pearl : AppColors.midnight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: accent.withValues(alpha: selected ? 0.8 : 0.3),
            width: selected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: selected ? 0.45 : 0.25),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/map-icon.jpg',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
