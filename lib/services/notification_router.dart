import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../main.dart' show navigatorKey;
import '../screens/home_care_page.dart';
import '../screens/home_care_provider_requests_page.dart';
import '../screens/order_detail_page.dart';
import '../screens/pharmacy_orders_page.dart';
import 'order_api_service.dart';

class NotificationRouter {
  NotificationRouter._();

  static Future<void> route(Map<String, dynamic> data) async {
    final type = (data['type'] ?? '').toString();
    final refStr = (data['referenceId'] ?? '').toString();
    final referenceId = int.tryParse(refStr);

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    switch (type) {
      case 'OrderStatusChanged':
        if (referenceId != null) {
          await _openOrderDetail(nav, referenceId);
        }
        break;
      case 'NewOrder':
        nav.push(MaterialPageRoute(
          builder: (_) => const PharmacyOrdersPage(initialTabIndex: 0),
        ));
        break;
      case 'NewHomeCareRequest':
        nav.push(MaterialPageRoute(
          builder: (_) => const HomeCareProviderRequestsPage(initialTabIndex: 0),
        ));
        break;
      case 'HomeCareRequestStatusChanged':
        // Müşteri tarafı: serum talebi onay/red/tamamlandı bildirimine basınca
        // Eve Serum Hizmeti ekraninin "Taleplerim" sekmesine yonlendir.
        nav.push(MaterialPageRoute(
          builder: (_) => HomeCarePage(
            baseUrl: ApiConfig.baseUrl,
            initialTabIndex: 1,
          ),
        ));
        break;
    }
  }

  static Future<void> _openOrderDetail(NavigatorState nav, int orderId) async {
    try {
      final api = OrderApiService(baseUrl: ApiConfig.baseUrl);
      final orders = await api.getMyOrders();
      final order = orders.firstWhere(
        (o) => o.orderId == orderId,
        orElse: () => orders.isNotEmpty ? orders.first : (throw StateError('not found')),
      );
      nav.push(MaterialPageRoute(
        builder: (_) => OrderDetailPage(order: order, baseUrl: ApiConfig.baseUrl),
      ));
    } catch (_) {
      // sessizce yut: bildirime basıldığında order bulunamazsa ana akış kalır
    }
  }
}
