import 'package:flutter/material.dart';

/// Custom page transitions for smoother navigation
class PageTransitions {
  /// Slide transition from right to left
  static Route slideFromRight(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  /// Fade and scale transition
  static Route fadeScale(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;

        var fadeAnimation = CurvedAnimation(parent: animation, curve: curve);
        var scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: curve),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Slide up from bottom
  static Route slideUp(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  /// Shared axis transition (Material Design)
  static Route sharedAxis(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;

        var fadeInAnimation = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.3, 1.0, curve: curve),
        );

        var fadeOutAnimation = CurvedAnimation(
          parent: secondaryAnimation,
          curve: const Interval(0.0, 0.7, curve: curve),
        );

        var slideInAnimation = Tween<Offset>(
          begin: const Offset(0.05, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        var slideOutAnimation = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.05, 0.0),
        ).animate(CurvedAnimation(parent: secondaryAnimation, curve: curve));

        return SlideTransition(
          position: slideOutAnimation,
          child: FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(fadeOutAnimation),
            child: SlideTransition(
              position: slideInAnimation,
              child: FadeTransition(
                opacity: fadeInAnimation,
                child: child,
              ),
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }
}
