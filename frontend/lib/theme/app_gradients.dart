import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Signature gradients used across the UI.
class AppGradients {
  const AppGradients._();

  static const LinearGradient cosmic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF201A4D),
      AppColors.primary,
      Color(0xFF0F172A),
    ],
  );

  static const LinearGradient aurora = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1E2748),
      Color(0xFF151A33),
    ],
  );

  static const LinearGradient emerald = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.secondary,
      Color(0xFF3DDAD7),
    ],
  );

  static const LinearGradient coral = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.tertiary,
      Color(0xFFFF5C8A),
    ],
  );
}
