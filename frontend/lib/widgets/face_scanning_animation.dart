import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 3D-style face scanning animation overlay
class FaceScanningAnimation extends StatefulWidget {
  const FaceScanningAnimation({
    super.key,
    this.isScanning = false,
    this.size = 280,
    this.scanColor = const Color(0xFF14C8C1),
  });

  final bool isScanning;
  final double size;
  final Color scanColor;

  @override
  State<FaceScanningAnimation> createState() => _FaceScanningAnimationState();
}

class _FaceScanningAnimationState extends State<FaceScanningAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    // Scanning line animation (moves up and down)
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    // Pulse animation for frame
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotation animation for corner markers
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    if (widget.isScanning) {
      _startAnimations();
    }
  }

  @override
  void didUpdateWidget(FaceScanningAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !oldWidget.isScanning) {
      _startAnimations();
    } else if (!widget.isScanning && oldWidget.isScanning) {
      _stopAnimations();
    }
  }

  void _startAnimations() {
    _scanController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);
    _rotateController.repeat();
  }

  void _stopAnimations() {
    _scanController.stop();
    _pulseController.stop();
    _rotateController.stop();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.2,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _scanController,
          _pulseController,
          _rotateController,
        ]),
        builder: (context, child) {
          return CustomPaint(
            painter: _ScanningPainter(
              scanProgress: _scanAnimation.value,
              pulseScale: _pulseAnimation.value,
              rotationAngle: _rotateAnimation.value,
              scanColor: widget.scanColor,
              isScanning: widget.isScanning,
            ),
          );
        },
      ),
    );
  }
}

class _ScanningPainter extends CustomPainter {
  final double scanProgress;
  final double pulseScale;
  final double rotationAngle;
  final Color scanColor;
  final bool isScanning;

  _ScanningPainter({
    required this.scanProgress,
    required this.pulseScale,
    required this.rotationAngle,
    required this.scanColor,
    required this.isScanning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final frameWidth = size.width * 0.85;
    final frameHeight = size.height * 0.75;

    // Main frame with rounded corners
    _drawFrame(canvas, centerX, centerY, frameWidth, frameHeight);

    // Corner markers (rotating)
    _drawCornerMarkers(canvas, centerX, centerY, frameWidth, frameHeight);

    // Grid overlay
    _drawGrid(canvas, centerX, centerY, frameWidth, frameHeight);

    // Scanning line
    if (isScanning) {
      _drawScanLine(canvas, centerX, centerY, frameWidth, frameHeight);
    }

    // Center crosshair
    _drawCrosshair(canvas, centerX, centerY);
  }

  void _drawFrame(Canvas canvas, double cx, double cy, double w, double h) {
    final framePaint = Paint()
      ..color = scanColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final frameRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
      const Radius.circular(20),
    );

    // Outer glow
    final glowPaint = Paint()
      ..color = scanColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawRRect(frameRect, glowPaint);
    canvas.drawRRect(frameRect, framePaint);

    // Pulsing inner frame
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: w * pulseScale * 0.95,
        height: h * pulseScale * 0.95,
      ),
      const Radius.circular(18),
    );

    final innerPaint = Paint()
      ..color = scanColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(innerRect, innerPaint);
  }

  void _drawCornerMarkers(
      Canvas canvas, double cx, double cy, double w, double h) {
    final markerPaint = Paint()
      ..color = scanColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final halfW = w / 2;
    final halfH = h / 2;
    final markerLength = 20.0;

    // Define corners
    final corners = [
      Offset(cx - halfW, cy - halfH), // Top-left
      Offset(cx + halfW, cy - halfH), // Top-right
      Offset(cx - halfW, cy + halfH), // Bottom-left
      Offset(cx + halfW, cy + halfH), // Bottom-right
    ];

    for (int i = 0; i < corners.length; i++) {
      canvas.save();
      canvas.translate(corners[i].dx, corners[i].dy);
      canvas.rotate(rotationAngle + (i * math.pi / 2));

      // Draw L-shape marker
      final path = Path()
        ..moveTo(-markerLength, 0)
        ..lineTo(0, 0)
        ..lineTo(0, -markerLength);

      canvas.drawPath(path, markerPaint);
      canvas.restore();
    }
  }

  void _drawGrid(Canvas canvas, double cx, double cy, double w, double h) {
    final gridPaint = Paint()
      ..color = scanColor.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final left = cx - w / 2;
    final right = cx + w / 2;
    final top = cy - h / 2;
    final bottom = cy + h / 2;

    // Horizontal lines
    for (int i = 1; i < 4; i++) {
      final y = top + (h * i / 4);
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }

    // Vertical lines
    for (int i = 1; i < 3; i++) {
      final x = left + (w * i / 3);
      canvas.drawLine(Offset(x, top), Offset(x, bottom), gridPaint);
    }
  }

  void _drawScanLine(Canvas canvas, double cx, double cy, double w, double h) {
    final top = cy - h / 2;
    final bottom = cy + h / 2;
    final scanY = top + (h * scanProgress);

    // Scan line with gradient
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          scanColor.withOpacity(0.0),
          scanColor.withOpacity(0.8),
          scanColor.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(cx - w / 2, scanY - 5, w, 10))
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(cx - w / 2, scanY - 2, w, 4),
      scanPaint,
    );

    // Glow effect for scan line
    final glowPaint = Paint()
      ..color = scanColor.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawRect(
      Rect.fromLTWH(cx - w / 2, scanY - 3, w, 6),
      glowPaint,
    );
  }

  void _drawCrosshair(Canvas canvas, double cx, double cy) {
    final crosshairPaint = Paint()
      ..color = scanColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const crossSize = 15.0;

    // Horizontal line
    canvas.drawLine(
      Offset(cx - crossSize, cy),
      Offset(cx + crossSize, cy),
      crosshairPaint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(cx, cy - crossSize),
      Offset(cx, cy + crossSize),
      crosshairPaint,
    );

    // Center dot
    final dotPaint = Paint()
      ..color = scanColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx, cy), 3, dotPaint);
  }

  @override
  bool shouldRepaint(_ScanningPainter oldDelegate) {
    return oldDelegate.scanProgress != scanProgress ||
        oldDelegate.pulseScale != pulseScale ||
        oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.isScanning != isScanning;
  }
}
