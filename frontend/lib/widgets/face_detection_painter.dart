import 'dart:math';
import 'package:flutter/material.dart';

class FaceDetectionPainter extends CustomPainter {
  final Rect faceRect;
  final bool isGoodQuality;
  final double strokeWidth;
  final double animationValue;

  FaceDetectionPainter({
    required this.faceRect,
    required this.isGoodQuality,
    this.strokeWidth = 3.0,
    this.animationValue = 0.0, // 0.0 to 1.0 for animation effects
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate device aspect ratio to properly scale face rectangle
    // final double deviceAspectRatio = size.width / size.height; // Currently unused
    
    // Adjust scaling to handle different camera aspect ratios
    double scaleX, scaleY;
    if (faceRect.width > faceRect.height) {
      scaleX = size.width / faceRect.width;
      scaleY = scaleX; // Keep aspect ratio
    } else {
      scaleY = size.height / faceRect.height;
      scaleX = scaleY; // Keep aspect ratio
    }
    
    // Calculate the centered rectangle to draw
    final scaledWidth = faceRect.width * scaleX;
    final scaledHeight = faceRect.height * scaleY;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    final scaledRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: scaledWidth,
      height: scaledHeight,
    );
    
    // Colors based on quality
    final Color mainColor = isGoodQuality ? Colors.green : Colors.red;
    final Color secondaryColor = isGoodQuality ? Colors.greenAccent : Colors.redAccent;
    
    // Create a gradient for the border
    final Gradient gradient = LinearGradient(
      colors: [
        mainColor.withOpacity(0.8),
        secondaryColor.withOpacity(0.6),
        mainColor.withOpacity(0.8),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    // Main rectangle with gradient stroke
    final paint = Paint()
      ..shader = gradient.createShader(scaledRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    // Draw dashed border for poor quality or solid for good quality
    if (isGoodQuality) {
      // Solid border for good quality
      canvas.drawRect(scaledRect, paint);
      
      // Draw animated corners for good quality
      _drawAnimatedCorners(canvas, scaledRect, mainColor);
      
      // Add a glow effect
      final glowPaint = Paint()
        ..color = mainColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        
      canvas.drawRect(scaledRect.inflate(2.0), glowPaint);
      
      // Add a checkmark or success indicator for good quality faces
      _drawCheckmark(canvas, scaledRect, mainColor);
    } else {
      // Dashed border for poor quality
      _drawDashedRect(canvas, scaledRect, paint);
      
      // Add caution indicators for poor quality
      _drawCautionIndicator(canvas, scaledRect, mainColor);
    }
  }
  
  // Draw animated corner brackets
  void _drawAnimatedCorners(Canvas canvas, Rect rect, Color color) {
    final cornerLength = min(rect.width, rect.height) * 0.2; // 20% of the smaller dimension
    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 1.0
      ..strokeCap = StrokeCap.round;
    
    // Top-left corner
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft.translate(cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft.translate(0, cornerLength),
      cornerPaint,
    );
    
    // Top-right corner
    canvas.drawLine(
      rect.topRight,
      rect.topRight.translate(-cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight.translate(0, cornerLength),
      cornerPaint,
    );
    
    // Bottom-left corner
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft.translate(cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft.translate(0, -cornerLength),
      cornerPaint,
    );
    
    // Bottom-right corner
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight.translate(-cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight.translate(0, -cornerLength),
      cornerPaint,
    );
  }
  
  // Draw a checkmark for good quality faces
  void _drawCheckmark(Canvas canvas, Rect rect, Color color) {
    // Position the checkmark in the top-right of the rect
    final centerX = rect.right - 24;
    final centerY = rect.top - 24;
    
    final checkmarkPath = Path()
      ..moveTo(centerX - 10, centerY)
      ..lineTo(centerX - 2, centerY + 8)
      ..lineTo(centerX + 10, centerY - 10);
    
    final checkmarkPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    canvas.drawPath(checkmarkPath, checkmarkPaint);
    
    // Add a circular background
    canvas.drawCircle(
      Offset(centerX, centerY),
      16,
      Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );
  }
  
  // Draw caution indicators for poor quality
  void _drawCautionIndicator(Canvas canvas, Rect rect, Color color) {
    final centerX = rect.right - 24;
    final centerY = rect.top - 24;
    
    // Draw exclamation mark
    final exclPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    
    // Exclamation dot
    canvas.drawCircle(
      Offset(centerX, centerY + 8),
      2,
      Paint()..color = color,
    );
    
    // Exclamation line
    canvas.drawLine(
      Offset(centerX, centerY - 8),
      Offset(centerX, centerY + 4),
      exclPaint,
    );
    
    // Circle around exclamation
    canvas.drawCircle(
      Offset(centerX, centerY),
      16,
      Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );
    
    canvas.drawCircle(
      Offset(centerX, centerY),
      16,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }
  
  // Draw dashed rectangle
  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    final dashWidth = 10.0;
    final dashSpace = 5.0;
    
    // Helper method to draw a dashed line
    void drawDashedLine(Offset start, Offset end) {
      final double dx = end.dx - start.dx;
      final double dy = end.dy - start.dy;
      final double distance = sqrt(dx * dx + dy * dy);
      final double unitX = dx / distance;
      final double unitY = dy / distance;
      
      double currentDistance = 0;
      bool isDash = true;
      
      while (currentDistance < distance) {
        final double remainingDistance = distance - currentDistance;
        final double segmentLength = isDash 
            ? min(dashWidth, remainingDistance) 
            : min(dashSpace, remainingDistance);
        
        if (isDash) {
          final Offset segmentStart = Offset(
            start.dx + unitX * currentDistance,
            start.dy + unitY * currentDistance,
          );
          
          final Offset segmentEnd = Offset(
            start.dx + unitX * (currentDistance + segmentLength),
            start.dy + unitY * (currentDistance + segmentLength),
          );
          
          canvas.drawLine(segmentStart, segmentEnd, paint);
        }
        
        currentDistance += segmentLength;
        isDash = !isDash;
      }
    }
    
    // Draw top line
    drawDashedLine(rect.topLeft, rect.topRight);
    // Draw right line
    drawDashedLine(rect.topRight, rect.bottomRight);
    // Draw bottom line
    drawDashedLine(rect.bottomRight, rect.bottomLeft);
    // Draw left line
    drawDashedLine(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(FaceDetectionPainter oldDelegate) {
    return oldDelegate.faceRect != faceRect || 
           oldDelegate.isGoodQuality != isGoodQuality ||
           oldDelegate.animationValue != animationValue;
  }
}