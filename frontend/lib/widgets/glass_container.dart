import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Creates a subtle glassmorphism surface suitable for dashboards.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius = 24,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    final content = Container(
      margin: margin,
      padding: padding ?? EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: gradient ?? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isMobile ? 0.1 : 0.15),
            blurRadius: isMobile ? 12 : 18,
            offset: Offset(0, isMobile ? 8 : 12),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: AppColors.secondary.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.04),
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }
}
