import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// An animated statistics card with count-up animation
class AnimatedStatCard extends StatefulWidget {
  const AnimatedStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.suffix = '',
    this.animationDuration = const Duration(milliseconds: 1200),
    this.isCompact = false,
  });

  final IconData icon;
  final String label;
  final num value;
  final Color? color;
  final String suffix;
  final Duration animationDuration;
  final bool isCompact;

  @override
  State<AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<AnimatedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _valueAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _valueAnimation = Tween<double>(
      begin: 0,
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedStatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _valueAnimation = Tween<double>(
        begin: _valueAnimation.value,
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = widget.color ?? AppColors.secondary;
    
    // Responsive sizing based on compact mode
    final iconSize = widget.isCompact ? 40.0 : 56.0;
    final iconInnerSize = widget.isCompact ? 20.0 : 28.0;
    final padding = widget.isCompact ? 12.0 : 20.0;
    final borderRadius = widget.isCompact ? 16.0 : 24.0;
    final labelFontSize = widget.isCompact ? 11.0 : 13.0;
    final valueFontSize = widget.isCompact ? 24.0 : 36.0;
    final spacing = widget.isCompact ? 8.0 : 16.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: resolvedColor.withOpacity(0.3),
                width: widget.isCompact ? 1.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: resolvedColor.withOpacity(0.2),
                  blurRadius: widget.isCompact ? 12 : 20,
                  offset: Offset(0, widget.isCompact ? 6 : 10),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: widget.isCompact ? 6 : 10,
                  offset: Offset(0, widget.isCompact ? 3 : 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        resolvedColor.withOpacity(0.9),
                        resolvedColor.withOpacity(0.6),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: resolvedColor.withOpacity(0.4),
                        blurRadius: widget.isCompact ? 8 : 12,
                        offset: Offset(0, widget.isCompact ? 2 : 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                    size: iconInnerSize,
                  ),
                ),
                SizedBox(height: spacing),
                Flexible(
                  child: Text(
                    widget.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: labelFontSize,
                      letterSpacing: 0.3,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: widget.isCompact ? 4 : 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_valueAnimation.value.toStringAsFixed(widget.suffix == '%' ? 1 : 0)}${widget.suffix}',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
