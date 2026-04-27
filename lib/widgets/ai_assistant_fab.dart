import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_colors.dart';

class AiAssistantFab extends StatefulWidget {
  final VoidCallback onPressed;
  final String bubbleText;
  final Duration bubbleVisibleDuration;
  final Duration bubbleInterval;

  const AiAssistantFab({
    super.key,
    required this.onPressed,
    this.bubbleText = 'Merak Ettiğiniz Soruları kolayca bana sorabilirsiniz',
    this.bubbleVisibleDuration = const Duration(seconds: 5),
    this.bubbleInterval = const Duration(seconds: 15),
  });

  @override
  State<AiAssistantFab> createState() => _AiAssistantFabState();
}

class _AiAssistantFabState extends State<AiAssistantFab>
    with TickerProviderStateMixin {
  static const double _fabSize = 84;
  static const double _edgeMargin = 8;
  static const double _defaultBottomInset = 200;
  static const double _navBarSafeZone = 110;

  late final AnimationController _pulseCtrl;
  late final AnimationController _bubbleCtrl;

  Timer? _cycleTimer;
  bool _bubbleVisible = false;

  Offset? _pos;
  Offset _dragStart = Offset.zero;
  bool _dragging = false;
  bool _hidden = false;
  bool _hiddenOnRight = true;
  double _hiddenY = 0;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _startCycle());
  }

  void _startCycle() {
    _showBubble();
    _cycleTimer?.cancel();
    _cycleTimer = Timer.periodic(
      widget.bubbleInterval + widget.bubbleVisibleDuration,
      (_) {
        if (!_dragging) _showBubble();
      },
    );
  }

  Future<void> _showBubble() async {
    if (!mounted || _bubbleVisible) return;
    setState(() => _bubbleVisible = true);
    await _bubbleCtrl.forward();
    await Future.delayed(widget.bubbleVisibleDuration);
    if (!mounted) return;
    await _bubbleCtrl.reverse();
    if (!mounted) return;
    setState(() => _bubbleVisible = false);
  }

  Future<void> _hideBubbleImmediately() async {
    if (!_bubbleVisible) return;
    await _bubbleCtrl.reverse();
    if (!mounted) return;
    setState(() => _bubbleVisible = false);
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _pulseCtrl.dispose();
    _bubbleCtrl.dispose();
    super.dispose();
  }

  Offset _defaultPos(Size size) => Offset(
        size.width - _fabSize - _edgeMargin,
        size.height - _fabSize - _defaultBottomInset,
      );

  Offset _clamp(Offset p, Size size) {
    final dx = p.dx.clamp(_edgeMargin, size.width - _fabSize - _edgeMargin);
    final dy = p.dy.clamp(_edgeMargin, size.height - _fabSize - _navBarSafeZone);
    return Offset(dx, dy);
  }

  Offset _clampForDrag(Offset p, Size size) {
    // Allow horizontal drag fully off-screen so user can throw the FAB away.
    final dx = p.dx.clamp(-_fabSize, size.width.toDouble());
    final dy = p.dy.clamp(_edgeMargin, size.height - _fabSize - _navBarSafeZone);
    return Offset(dx, dy);
  }

  void _snapOrHide(Size size) {
    if (_pos == null) return;
    final centerX = _pos!.dx + _fabSize / 2;
    // If user dragged FAB far past the edge, hide it.
    if (centerX > size.width - _fabSize * 0.25) {
      setState(() {
        _hidden = true;
        _hiddenOnRight = true;
        _hiddenY = (_pos!.dy + _fabSize / 2).clamp(
          _fabSize,
          size.height - _fabSize - _navBarSafeZone,
        );
      });
      return;
    }
    if (centerX < _fabSize * 0.25) {
      setState(() {
        _hidden = true;
        _hiddenOnRight = false;
        _hiddenY = (_pos!.dy + _fabSize / 2).clamp(
          _fabSize,
          size.height - _fabSize - _navBarSafeZone,
        );
      });
      return;
    }
    final snappedX = centerX < size.width / 2
        ? _edgeMargin
        : size.width - _fabSize - _edgeMargin;
    setState(() {
      _pos = _clamp(Offset(snappedX, _pos!.dy), size);
    });
  }

  void _restoreFab(Size size) {
    final defX = _hiddenOnRight
        ? size.width - _fabSize - _edgeMargin
        : _edgeMargin;
    final defY = (_hiddenY - _fabSize / 2).clamp(
      _edgeMargin,
      size.height - _fabSize - _navBarSafeZone,
    );
    setState(() {
      _hidden = false;
      _pos = Offset(defX, defY);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        if (_hidden) {
          return Stack(
            clipBehavior: Clip.none,
            children: [_buildPeekHandle(size, isDark)],
          );
        }

        final pos = _pos == null
            ? _defaultPos(size)
            : (_dragging ? _clampForDrag(_pos!, size) : _clamp(_pos!, size));
        final bubbleOnLeft = pos.dx + _fabSize / 2 > size.width / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedPositioned(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: pos.dx,
              top: pos.dy,
              width: _fabSize,
              height: _fabSize,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (_) {
                  _dragStart = _pos ?? _defaultPos(size);
                  _hideBubbleImmediately();
                  setState(() => _dragging = true);
                },
                onLongPressMoveUpdate: (d) {
                  final next = _dragStart + d.offsetFromOrigin;
                  setState(() => _pos = _clampForDrag(next, size));
                },
                onLongPressEnd: (_) {
                  setState(() => _dragging = false);
                  _snapOrHide(size);
                },
                onLongPressCancel: () {
                  setState(() => _dragging = false);
                  _snapOrHide(size);
                },
                child: _buildFabContent(isDark, bubbleOnLeft),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPeekHandle(Size size, bool isDark) {
    const handleW = 22.0;
    const handleH = 56.0;
    final top = (_hiddenY - handleH / 2).clamp(
      _fabSize,
      size.height - handleH - _navBarSafeZone,
    );
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: _hiddenOnRight ? null : 0,
      right: _hiddenOnRight ? 0 : null,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _restoreFab(size),
        child: Container(
          width: handleW,
          height: handleH,
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkSurfaceElevated : Colors.white)
                .withValues(alpha: 0.92),
            borderRadius: _hiddenOnRight
                ? const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  )
                : const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
            border: Border.all(
              color: (isDark ? Colors.white : AppColors.midnight)
                  .withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : AppColors.midnight)
                    .withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            _hiddenOnRight ? Icons.chevron_left : Icons.chevron_right,
            size: 18,
            color: isDark ? Colors.white : AppColors.midnight,
          ),
        ),
      ),
    );
  }

  Widget _buildFabContent(bool isDark, bool bubbleOnLeft) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, _) => SizedBox(
            width: _fabSize,
            height: _fabSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildPulseRing(_pulseCtrl.value, isDark, delay: 0),
                _buildPulseRing(_pulseCtrl.value, isDark, delay: 0.5),
              ],
            ),
          ),
        ),
        _buildRobot(isDark),
        if (_bubbleVisible)
          Positioned(
            left: bubbleOnLeft ? null : _fabSize,
            right: bubbleOnLeft ? _fabSize : null,
            top: _fabSize / 2 - 22,
            child: _buildBubble(isDark, tailOnRight: bubbleOnLeft),
          ),
      ],
    );
  }

  Widget _buildPulseRing(double pulse, bool isDark, {required double delay}) {
    final t = (pulse + delay) % 1.0;
    final size = 56 + (t * 40);
    final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.32;
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: (isDark ? AppColors.darkTextPrimary : AppColors.midnight)
                .withValues(alpha: opacity),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildRobot(bool isDark) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          _showBubble();
          widget.onPressed();
        },
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      AppColors.darkSurfaceElevated,
                      AppColors.midnightSoft,
                    ]
                  : [
                      const Color(0xFFEAF4FF),
                      Colors.white,
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : AppColors.midnight)
                    .withValues(alpha: _dragging ? 0.4 : 0.28),
                blurRadius: _dragging ? 22 : 16,
                offset: Offset(0, _dragging ? 10 : 6),
              ),
            ],
            border: Border.all(
              color: (isDark ? AppColors.darkTextPrimary : AppColors.midnight)
                  .withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Lottie.asset(
            'assets/animations/ai_robot.json',
            fit: BoxFit.contain,
            repeat: true,
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(bool isDark, {required bool tailOnRight}) {
    const bg = Colors.white;
    const textColor = AppColors.midnight;

    return FadeTransition(
      opacity: _bubbleCtrl,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: _bubbleCtrl, curve: Curves.easeOutBack),
        ),
        alignment:
            tailOnRight ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: CustomPaint(
            painter: _BubbleTailPainter(color: bg, tailOnRight: tailOnRight),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tailOnRight ? 14 : 18,
                10,
                tailOnRight ? 18 : 14,
                10,
              ),
              child: Text(
                widget.bubbleText,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final bool tailOnRight;

  _BubbleTailPainter({required this.color, required this.tailOnRight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final rrect = RRect.fromRectAndRadius(
      tailOnRight
          ? Rect.fromLTWH(0, 0, size.width - 8, size.height)
          : Rect.fromLTWH(8, 0, size.width - 8, size.height),
      const Radius.circular(14),
    );

    final tail = Path();
    if (tailOnRight) {
      tail
        ..moveTo(size.width - 8, size.height / 2 - 6)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width - 8, size.height / 2 + 6)
        ..close();
    } else {
      tail
        ..moveTo(8, size.height / 2 - 6)
        ..lineTo(0, size.height / 2)
        ..lineTo(8, size.height / 2 + 6)
        ..close();
    }

    canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadow);
    canvas.drawPath(tail.shift(const Offset(0, 2)), shadow);
    canvas.drawRRect(rrect, paint);
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.tailOnRight != tailOnRight;
}
