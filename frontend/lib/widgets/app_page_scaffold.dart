import 'package:flutter/material.dart';
import '../theme/app_gradients.dart';
import '../theme/app_colors.dart';

/// Shared scaffold with gradient background and safe-area handling.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.padding,
    this.extendBodyBehindAppBar = false,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;
  final EdgeInsetsGeometry? padding;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    final resolvedPadding = padding ?? EdgeInsets.symmetric(
      horizontal: isMobile ? 12 : 20,
      vertical: isMobile ? 12 : 18,
    );

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(fontSize: isMobile ? 18 : 20),
        ),
        actions: actions,
        bottom: bottom,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppGradients.cosmic),
        ),
        backgroundColor: extendBodyBehindAppBar ? Colors.transparent : null,
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.cosmic),
        child: SafeArea(
          bottom: true,
          child: Padding(
            padding: resolvedPadding,
            child: body,
          ),
        ),
      ),
    );
  }
}
