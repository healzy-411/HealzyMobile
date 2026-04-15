import 'package:flutter/material.dart';

/// Türkiye eczane logosu: kırmızı çerçeveli beyaz kare + yanıp sönen kırmızı "E" harfi.
/// `size` null ise parent'ı doldurur (min(maxWidth, maxHeight) kullanır).
class EczaneIcon extends StatefulWidget {
  final double? size;
  const EczaneIcon({super.key, this.size = 40});

  @override
  State<EczaneIcon> createState() => _EczaneIconState();
}

class _EczaneIconState extends State<EczaneIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _blink;

  static const Color _red = Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _blink = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _buildBox(double s) {
    return AnimatedBuilder(
      animation: _blink,
      builder: (_, __) {
        return Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(s * 0.18),
            border: Border.all(color: _red, width: s * 0.08),
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: _blink.value * 0.5),
                blurRadius: s * 0.25,
                spreadRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'E',
            style: TextStyle(
              fontSize: s * 0.62,
              height: 1.0,
              fontWeight: FontWeight.w900,
              color: _red.withValues(alpha: _blink.value),
              letterSpacing: -1,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.size != null) return _buildBox(widget.size!);
    return LayoutBuilder(
      builder: (_, constraints) {
        final s = (constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight)
            .clamp(0.0, 1000.0);
        return Center(child: _buildBox(s.toDouble()));
      },
    );
  }
}
