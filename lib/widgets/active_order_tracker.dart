import 'dart:math';
import 'package:flutter/material.dart';
import '../Models/order_model.dart';
import '../screens/order_detail_page.dart';

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
  }

  @override
  void dispose() {
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
      top: 8,
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

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header - always visible
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusInfo.color.withValues(alpha: 0.1),
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
                          fontSize: 13,
                          color: statusInfo.color,
                        ),
                      ),
                      Text(
                        order.pharmacyName,
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
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
                            fontSize: 12,
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
                        fontSize: 12,
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Column(
                children: [
                  // Progress bar
                  _buildProgressBar(order.status),
                  const SizedBox(height: 10),

                  // Mesafe ve sure detayi
                  if (estimate != null && order.status != "Delivered")
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            "${estimate.distanceKm.toStringAsFixed(1)} km uzakta",
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.timer_outlined, size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            "Hazirlik ~${estimate.prepMin} dk + Yol ~${estimate.travelMin} dk",
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
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
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      Text(
                        "${order.total.toStringAsFixed(2)} TL",
                        style: const TextStyle(
                          fontSize: 13,
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
                        style: const TextStyle(fontSize: 11, color: Colors.black45),
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
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      if (onDismiss != null) const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onDetailTap,
                        child: const Text(
                          "Detay >",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
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

  Widget _buildProgressBar(String status) {
    final steps = ["Pending", "Preparing", "Ready", "Dispatched", "Delivered"];
    final labels = ["Alindi", "Hazirlaniyor", "Hazir", "Yolda", "Teslim"];
    final icons = [
      Icons.receipt_long,
      Icons.local_pharmacy,
      Icons.check_circle_outline,
      Icons.delivery_dining,
      Icons.home_outlined,
    ];
    final currentIndex = steps.indexOf(status).clamp(0, steps.length - 1);

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepBefore = i ~/ 2;
          final active = stepBefore < currentIndex;
          return Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: active ? Colors.green : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }

        final stepIndex = i ~/ 2;
        final done = stepIndex <= currentIndex;
        final isCurrent = stepIndex == currentIndex;

        return Column(
          children: [
            Container(
              width: isCurrent ? 22 : 16,
              height: isCurrent ? 22 : 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? Colors.green : Colors.grey[300],
                border: isCurrent
                    ? Border.all(color: Colors.green.shade700, width: 2.5)
                    : null,
              ),
              child: Icon(
                done ? icons[stepIndex] : icons[stepIndex],
                size: isCurrent ? 12 : 9,
                color: done ? Colors.white : Colors.grey,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              labels[stepIndex],
              style: TextStyle(
                fontSize: 8,
                color: done ? Colors.green.shade700 : Colors.grey,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
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
  int get minutes => prepMin + travelMin;

  const _DeliveryEstimate({
    required this.distanceKm,
    required this.prepMin,
    required this.travelMin,
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

  return _DeliveryEstimate(
    distanceKm: distanceKm,
    prepMin: prepMin,
    travelMin: travelMin,
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
