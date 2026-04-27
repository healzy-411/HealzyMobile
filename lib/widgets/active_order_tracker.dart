import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../Models/order_model.dart';
import '../screens/order_detail_page.dart';
import '../theme/app_colors.dart';

class ActiveOrderTracker extends StatefulWidget {
  final List<OrderDto> activeOrders;
  final double? userLat;
  final double? userLng;
  final VoidCallback? onRefresh;
  final VoidCallback? onDismiss;

  const ActiveOrderTracker({
    super.key,
    required this.activeOrders,
    this.userLat,
    this.userLng,
    this.onRefresh,
    this.onDismiss,
  });

  @override
  State<ActiveOrderTracker> createState() => _ActiveOrderTrackerState();
}

class _ActiveOrderTrackerState extends State<ActiveOrderTracker>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _animController;
  late Animation<double> _expandAnim;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.value = 1.0; // start expanded
    // Yolda durumunda tahmini süre her 30sn'de güncellensin.
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeOrders.isEmpty) return const SizedBox.shrink();

    final order = widget.activeOrders.first;

    return Positioned(
      bottom: 90,
      left: 12,
      right: 12,
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedBuilder(
          animation: _expandAnim,
          order: order,
          userLat: widget.userLat,
          userLng: widget.userLng,
          expanded: _expanded,
          onDismiss: order.status == "Delivered" ? widget.onDismiss : null,
          onDetailTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailPage(order: order),
              ),
            ).then((_) => widget.onRefresh?.call());
          },
        ),
      ),
    );
  }
}

class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final OrderDto order;
  final double? userLat;
  final double? userLng;
  final bool expanded;
  final VoidCallback onDetailTap;
  final VoidCallback? onDismiss;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.order,
    this.userLat,
    this.userLng,
    required this.expanded,
    required this.onDetailTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo(order.status);
    final estimate = _estimateDelivery(order, userLat, userLng);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: expanded
          ? (isDark ? const Color(0xFF132B44) : Colors.white)
          : statusInfo.color.withValues(alpha: 0.35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header - always visible
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: expanded
                  ? (isDark ? const Color(0xFF132B44) : Colors.white)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.85)),
              borderRadius: expanded
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(statusInfo.icon, color: statusInfo.color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusInfo.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: statusInfo.color,
                        ),
                      ),
                      Text(
                        order.pharmacyName,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF8A97A8)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (order.status == "Delivered")
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          "Teslim Edildi",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (estimate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "~${estimate.minutes} dk",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: statusInfo.color,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Icon(
                  expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                  size: 20,
                ),
              ],
            ),
          ),

          // Expandable content
          SizeTransition(
            sizeFactor: animation,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF132B44) : Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                children: [
                  _buildProgressBar(context, order.status),
                  const SizedBox(height: 16),

                  // Mesafe ve sure detayi
                  if (estimate != null && order.status != "Delivered")
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFF102E4A).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16,
                              color: isDark ? Colors.white : const Color(0xFF102E4A)),
                          const SizedBox(width: 6),
                          Text(
                            "${estimate.distanceKm.toStringAsFixed(1)} km uzakta",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF102E4A),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Icon(Icons.timer_outlined,
                              size: 16,
                              color: isDark ? Colors.white : const Color(0xFF102E4A)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Hazırlık ~${estimate.prepMin} dk + Yol ~${estimate.travelMin} dk",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF102E4A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (estimate != null && order.status != "Delivered")
                    const SizedBox(height: 8),

                  // Order summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Siparis #${order.orderId}",
                        style: const TextStyle(fontSize: 14, color: Color(0xFF8A97A8)),
                      ),
                      Text(
                        "${order.total.toStringAsFixed(2)} TL",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "${order.items.length} urun",
                        style: const TextStyle(fontSize: 14, color: Color(0xFF9AA7B8)),
                      ),
                      const Spacer(),
                      if (onDismiss != null)
                        GestureDetector(
                          onTap: onDismiss,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "Gizle",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8A97A8),
                              ),
                            ),
                          ),
                        ),
                      if (onDismiss != null) const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onDetailTap,
                        child: Text(
                          "Detay >",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Asset image paths for custom icons (null = use Flutter icon)
  static const _stepAssets = <int, String>{
    0: 'assets/images/alindi.jpg',       // Pending - Alındı
    1: 'assets/images/hazirlaniyor.jpg', // Preparing
    2: 'assets/images/hazirlandi.jpg',   // Ready
    3: 'assets/images/yolda.jpg',        // Dispatched
    4: 'assets/images/teslimedildi.png', // Delivered
  };

  static const _stepIconSizes = <int, double>{
    0: 32, // Alindi
    1: 32, // Hazirlaniyor - biraz küçük
    2: 32, // Hazirlandi
    3: 32, // Yolda
    4: 32, // Teslim Edildi
  };

  static const _stepPulseIconSizes = <int, double>{
    0: 34, // Alindi
    1: 34, // Hazirlaniyor - biraz küçük
    2: 34, // Hazirlandi
    3: 34, // Yolda
    4: 34, // Teslim Edildi
  };

  static const _stepFallbackIcons = <int, IconData>{
    0: Icons.receipt_long_rounded,  // Pending
  };

  static const _fallbackIconSizes = <int, double>{
    0: 22, // Pending - normal
  };
  static const _fallbackPulseIconSizes = <int, double>{
    0: 24, // Pending - pulse
  };

  Widget _buildStepIcon(int stepIndex, bool done, Color doneColor, Color idleColor) {
    final asset = _stepAssets[stepIndex];
    if (asset != null) {
      return ClipOval(
        child: ColorFiltered(
          colorFilter: done
              ? ColorFilter.mode(doneColor.withValues(alpha: 0.15), BlendMode.srcATop)
              : ColorFilter.mode(idleColor.withValues(alpha: 0.3), BlendMode.srcATop),
          child: Image.asset(asset, width: 22, height: 22, fit: BoxFit.contain),
        ),
      );
    }
    return Icon(
      done ? Icons.check_rounded : (_stepFallbackIcons[stepIndex] ?? Icons.circle),
      size: 16,
      color: Colors.white,
    );
  }

  Widget _buildProgressBar(BuildContext context, String status) {
    final steps = ["Pending", "Preparing", "Ready", "Dispatched", "Delivered"];
    final labels = ["Siparis\nAlindi", "Hazirlaniyor", "Hazirlandi", "Yolda", "Teslim\nEdildi"];
    final currentIndex = steps.indexOf(status).clamp(0, steps.length - 1);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color doneColor = isDark ? Colors.white : AppColors.midnight;
    final Color idleColor =
        isDark ? Colors.white.withValues(alpha: 0.25) : Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepBefore = i ~/ 2;
          final active = stepBefore < currentIndex;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                height: 4,
                decoration: BoxDecoration(
                  color: active ? doneColor : idleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }

        final stepIndex = i ~/ 2;
        final done = stepIndex <= currentIndex;
        final isCurrent = stepIndex == currentIndex;
        final hasAsset = _stepAssets.containsKey(stepIndex);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isCurrent
                ? _PulseImageIcon(
                    stepIndex: stepIndex,
                    color: doneColor,
                  )
                : AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? doneColor : idleColor,
                    ),
                    child: Center(
                      child: hasAsset
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(17),
                              child: Image.asset(
                                _stepAssets[stepIndex]!,
                                width: _stepIconSizes[stepIndex] ?? 32,
                                height: _stepIconSizes[stepIndex] ?? 32,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Icon(
                              done ? Icons.check_rounded : (_stepFallbackIcons[stepIndex] ?? Icons.circle),
                              size: _fallbackIconSizes[stepIndex] ?? 16,
                              color: Colors.white,
                            ),
                    ),
                  ),
            const SizedBox(height: 6),
            SizedBox(
              width: 58,
              child: Text(
                labels[stepIndex],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: done ? doneColor : idleColor,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StatusInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusInfo(this.label, this.icon, this.color);
}

_StatusInfo _getStatusInfo(String status) {
  switch (status) {
    case "Pending":
      return const _StatusInfo("Siparis Alindi", Icons.access_time, Colors.orange);
    case "Preparing":
      return const _StatusInfo("Hazirlaniyor", Icons.local_pharmacy, Colors.blue);
    case "Ready":
      return const _StatusInfo("Teslimata Hazir", Icons.check_circle_outline, Colors.teal);
    case "Dispatched":
      return const _StatusInfo("Siparis Yolda", Icons.delivery_dining, Colors.green);
    case "Delivered":
      return const _StatusInfo("Teslim Edildi", Icons.check_circle, Colors.green);
    default:
      return const _StatusInfo("Siparis", Icons.shopping_bag_outlined, Colors.grey);
  }
}

class _DeliveryEstimate {
  final double distanceKm;
  final int prepMin;
  final int travelMin;
  final DateTime? dispatchedAt;

  // Yolda ise dispatch anından bu yana geçen süreyi travelMin'den düş;
  // diğer durumlarda prep + travel toplamını göster.
  int get minutes {
    if (dispatchedAt != null) {
      final elapsedMin =
          DateTime.now().toUtc().difference(dispatchedAt!).inSeconds / 60.0;
      final remaining = (travelMin - elapsedMin).ceil();
      return remaining < 1 ? 1 : remaining;
    }
    return prepMin + travelMin;
  }

  const _DeliveryEstimate({
    required this.distanceKm,
    required this.prepMin,
    required this.travelMin,
    this.dispatchedAt,
  });
}

_DeliveryEstimate? _estimateDelivery(OrderDto order, double? userLat, double? userLng) {
  if (order.pharmacyLatitude == null || order.pharmacyLongitude == null) {
    return null;
  }

  // Oncelik: GPS konumu > teslimat adresi koordinatlari
  final destLat = userLat ?? order.deliveryLatitude;
  final destLng = userLng ?? order.deliveryLongitude;

  if (destLat == null || destLng == null) return null;

  final distanceKm = _haversineKm(
    order.pharmacyLatitude!,
    order.pharmacyLongitude!,
    destLat,
    destLng,
  );

  int prepMin;
  switch (order.status) {
    case "Pending":
      prepMin = 15;
      break;
    case "Preparing":
      prepMin = 8;
      break;
    case "Ready":
      prepMin = 3;
      break;
    case "Dispatched":
      prepMin = 0;
      break;
    default:
      prepMin = 10;
  }

  // ~25 km/h sehir ici ortalama hiz (trafik dahil)
  final travelMin = (distanceKm / 25 * 60).ceil();

  // Yolda ise baseline olarak son durum güncelleme zamanını kullan,
  // böylece kalan süre zaman geçtikçe azalsın.
  final dispatchedAt =
      order.status == "Dispatched" ? order.updatedAtUtc.toUtc() : null;

  return _DeliveryEstimate(
    distanceKm: distanceKm,
    prepMin: prepMin,
    travelMin: travelMin,
    dispatchedAt: dispatchedAt,
  );
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _toRad(double deg) => deg * pi / 180;

class _PulseImageIcon extends StatefulWidget {
  final int stepIndex;
  final Color color;

  const _PulseImageIcon({required this.stepIndex, required this.color});

  @override
  State<_PulseImageIcon> createState() => _PulseImageIconState();
}

class _PulseImageIconState extends State<_PulseImageIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  static const _assets = AnimatedBuilder._stepAssets;
  static const _fallbackIcons = AnimatedBuilder._stepFallbackIcons;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween<double>(begin: 0.4, end: 0.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assets[widget.stepIndex];
    final hasAsset = asset != null;

    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, child) {
        return SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring
              Transform.scale(
                scale: _scale.value * 1.3,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.color.withValues(alpha: _opacity.value), width: 3),
                  ),
                ),
              ),
              // Icon circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: hasAsset
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(asset!, width: AnimatedBuilder._stepPulseIconSizes[widget.stepIndex] ?? 34, height: AnimatedBuilder._stepPulseIconSizes[widget.stepIndex] ?? 34, fit: BoxFit.contain),
                        )
                      : Icon(_fallbackIcons[widget.stepIndex] ?? Icons.circle, size: AnimatedBuilder._fallbackPulseIconSizes[widget.stepIndex] ?? 20, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
