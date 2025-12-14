import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Animated success checkmark
class SuccessAnimation extends StatefulWidget {
  const SuccessAnimation({
    super.key,
    this.size = 100,
    this.color = Colors.green,
    this.duration = const Duration(milliseconds: 800),
  });

  final double size;
  final Color color;
  final Duration duration;

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _circleAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _circleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _SuccessPainter(
                circleProgress: _circleAnimation.value,
                checkProgress: _checkAnimation.value,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuccessPainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;
  final Color color;

  _SuccessPainter({
    required this.circleProgress,
    required this.checkProgress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw circle
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      -math.pi / 2,
      2 * math.pi * circleProgress,
      false,
      circlePaint,
    );

    // Draw checkmark
    if (checkProgress > 0) {
      final checkPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      final path = Path();
      final checkStartX = size.width * 0.25;
      final checkStartY = size.height * 0.5;
      final checkMiddleX = size.width * 0.45;
      final checkMiddleY = size.height * 0.7;
      final checkEndX = size.width * 0.75;
      final checkEndY = size.height * 0.3;

      path.moveTo(checkStartX, checkStartY);

      if (checkProgress < 0.5) {
        // First part of check
        final progress = checkProgress * 2;
        path.lineTo(
          checkStartX + (checkMiddleX - checkStartX) * progress,
          checkStartY + (checkMiddleY - checkStartY) * progress,
        );
      } else {
        // Complete first part, animate second part
        path.lineTo(checkMiddleX, checkMiddleY);
        final progress = (checkProgress - 0.5) * 2;
        path.lineTo(
          checkMiddleX + (checkEndX - checkMiddleX) * progress,
          checkMiddleY + (checkEndY - checkMiddleY) * progress,
        );
      }

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_SuccessPainter oldDelegate) {
    return oldDelegate.circleProgress != circleProgress ||
        oldDelegate.checkProgress != checkProgress;
  }
}

/// Pulsing dot indicator for loading states
class PulsingDot extends StatefulWidget {
  const PulsingDot({
    super.key,
    this.size = 12,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color ?? Colors.white,
              boxShadow: [
                BoxShadow(
                  color: (widget.color ?? Colors.white).withOpacity(0.5),
                  blurRadius: 8 * _animation.value,
                  spreadRadius: 2 * _animation.value,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
