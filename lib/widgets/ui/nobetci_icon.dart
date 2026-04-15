import 'package:flutter/material.dart';

/// Nöbetçi eczane ikonu: kırmızı çerçeveli beyaz kare + kırmızı "N" harfi.
/// Animasyonsuz, statik.
class NobetciIcon extends StatelessWidget {
  final double size;
  const NobetciIcon({super.key, this.size = 64});

  static const Color _red = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    final s = size;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(s * 0.18),
        border: Border.all(color: _red, width: s * 0.08),
      ),
      alignment: Alignment.center,
      child: Text(
        'N',
        style: TextStyle(
          fontSize: s * 0.62,
          height: 1.0,
          fontWeight: FontWeight.w900,
          color: _red,
          letterSpacing: -1,
        ),
      ),
    );
  }
}
