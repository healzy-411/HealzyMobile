import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/notification_api_service.dart';
import '../services/token_store.dart';
import '../theme/app_colors.dart';
import '../screens/medicine_reminder_page.dart';
import '../screens/notifications_page.dart';
import '../screens/profile_page.dart';
import '../screens/home_map_fullscreen_page.dart';

enum HealzyNavTab { home, reminder, map, notifications, profile }

class HealzyBottomNav extends StatefulWidget {
  final HealzyNavTab? current;
  final int? notificationBadge; // override icin opsiyonel
  const HealzyBottomNav({
    super.key,
    this.current,
    this.notificationBadge,
  });

  @override
  State<HealzyBottomNav> createState() => _HealzyBottomNavState();
}

class _HealzyBottomNavState extends State<HealzyBottomNav>
    with WidgetsBindingObserver {
  final _notifApi = NotificationApiService(baseUrl: ApiConfig.baseUrl);
  int _unreadCount = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnread();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadUnread(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUnread();
    }
  }

  Future<void> _loadUnread() async {
    if (TokenStore.get() == null) return;
    try {
      final count = await _notifApi.getUnreadCount();
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {
      // sessiz: token süresi dolmuş olabilir
    }
  }

  Future<void> _go(BuildContext ctx, HealzyNavTab tab) async {
    if (widget.current == tab) return;

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

    await Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (r) => r.isFirst || r.settings.name == '/',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.pearl : AppColors.midnight;
    final idleColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : AppColors.midnight.withValues(alpha: 0.45);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: SizedBox(
          height: 78,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Glass bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : AppColors.midnight.withValues(alpha: 0.08),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark
                                    ? Colors.black
                                    : AppColors.midnight)
                                .withValues(alpha: isDark ? 0.4 : 0.16),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _NavItem(
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            label: 'Ana Sayfa',
                            selected: widget.current == HealzyNavTab.home,
                            activeColor: activeColor,
                            inactiveColor: idleColor,
                            onTap: () => _go(context, HealzyNavTab.home),
                          ),
                          _NavItem(
                            icon: Icons.access_alarm_outlined,
                            activeIcon: Icons.access_alarm_rounded,
                            label: 'Hatırlatıcı',
                            selected: widget.current == HealzyNavTab.reminder,
                            activeColor: activeColor,
                            inactiveColor: idleColor,
                            onTap: () => _go(context, HealzyNavTab.reminder),
                          ),
                          // FAB için boşluk
                          const SizedBox(width: 76),
                          _NavItem(
                            icon: Icons.notifications_outlined,
                            activeIcon: Icons.notifications_rounded,
                            label: 'Bildirim',
                            selected: widget.current == HealzyNavTab.notifications,
                            activeColor: activeColor,
                            inactiveColor: idleColor,
                            badge: widget.notificationBadge ?? _unreadCount,
                            onTap: () async {
                              await _go(context, HealzyNavTab.notifications);
                              if (mounted) _loadUnread();
                            },
                          ),
                          _NavItem(
                            icon: Icons.person_outline_rounded,
                            activeIcon: Icons.person_rounded,
                            label: 'Profil',
                            selected: widget.current == HealzyNavTab.profile,
                            activeColor: activeColor,
                            inactiveColor: idleColor,
                            onTap: () => _go(context, HealzyNavTab.profile),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // FAB — merkez, yukarı taşmış
              Positioned(
                top: 0,
                child: _MapFab(
                  selected: widget.current == HealzyNavTab.map,
                  onTap: () => _go(context, HealzyNavTab.map),
                ),
              ),
            ],
          ),
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
  final int badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(selected ? activeIcon : icon, size: 22, color: color),
                  if (badge > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapFab extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _MapFab({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.midnight,
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.18),
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.midnight.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/map-icon.jpg',
            width: 68,
            height: 68,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
