import 'dart:math';

class DistanceUtils {
  /// Haversine formulu ile iki koordinat arasindaki mesafeyi km cinsinden hesaplar
  static double haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0; // Dunya yaricapi (km)
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// Mesafeden tahmini teslimat suresi (dakika)
  /// Ortalama kurye hizi: 30 km/h
  static int estimateDeliveryMinutes(double distanceKm) {
    final minutes = (distanceKm / 30.0) * 60.0;
    return minutes.ceil().clamp(5, 90);
  }

  static double _toRad(double deg) => deg * pi / 180.0;
}
