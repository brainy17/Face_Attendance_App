import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/simple_face_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../widgets/glass_container.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_chip.dart';
import '../widgets/animated_stat_card.dart';
import '../widgets/animated_button.dart';
import '../widgets/shimmer_loading.dart';
import '../utils/page_transitions.dart';
import 'attendance_logs_screen.dart';
import 'face_registration_screen.dart';
import 'auto_scan_attendance_screen.dart';
import 'student_list_screen.dart';

class ModernHomeScreen extends StatefulWidget {
  const ModernHomeScreen({Key? key}) : super(key: key);

  @override
  State<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends State<ModernHomeScreen> with SingleTickerProviderStateMixin {
  final SimpleFaceApiService _apiService = SimpleFaceApiService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  bool _isConnected = false;
  Map<String, dynamic> _stats = const {
    'total_students': 0,
    'present_count': 0,
    'absent_count': 0,
    'attendance_percentage': 0.0,
  };
  String _lastUpdated = 'Never';
  Timer? _refreshTimer;

  late final List<_HomeAction> _actions = [
    _HomeAction(
      title: 'Auto-Scan Attendance',
      subtitle: 'Real-time face detection',
      icon: Icons.camera_enhance_rounded,
      accent: AppColors.secondary,
      builder: (context) => const AutoScanAttendanceScreen(),
    ),
    _HomeAction(
      title: 'Register Student',
      subtitle: 'Capture and enroll faces',
      icon: Icons.person_add_alt_1_rounded,
      accent: AppColors.tertiary,
      builder: (context) => const FaceRegistrationScreen(),
    ),
    _HomeAction(
      title: 'Attendance Logs',
      subtitle: 'Finalize sessions & export',
      icon: Icons.fact_check_rounded,
      accent: AppColors.primary,
      builder: (context) => const AttendanceLogsScreen(),
    ),
    _HomeAction(
      title: 'Student Registry',
      subtitle: 'Manage enrolled profiles',
      icon: Icons.people_alt_rounded,
      accent: const Color(0xFF55C2FF),
      builder: (context) => const StudentListScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _checkConnection();
    _loadStats();

    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _loadStats());
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _initAnimation() {
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
  }

  Future<void> _checkConnection() async {
    try {
      final isConnected = await _apiService.checkConnection().timeout(
        const Duration(seconds: 5),
        onTimeout: () => true,
      );
      if (mounted) {
        setState(() => _isConnected = isConnected);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isConnected = true);
      }
    }
  }

  Future<void> _loadStats() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      await _checkConnection();

      if (_isConnected) {
        final result = await _apiService.getDashboardStats().timeout(
          const Duration(seconds: 5),
          onTimeout: () => {
            'success': true,
            'stats': {
              'students_count': _stats['total_students'] ?? 0,
              'today_attendance': _stats['present_count'] ?? 0,
              'attendance_rate': _stats['attendance_percentage'] ?? 0.0,
            },
          },
        );

        if (!mounted) return;

        if (result['success'] == true) {
          final stats = Map<String, dynamic>.from(result['stats'] ?? {});
          final int totalStudents = (stats['students_count'] ?? 0) is num
              ? (stats['students_count'] as num).round()
              : int.tryParse('${stats['students_count'] ?? 0}') ?? 0;
          final int presentToday = (stats['today_attendance'] ?? 0) is num
              ? (stats['today_attendance'] as num).round()
              : int.tryParse('${stats['today_attendance'] ?? 0}') ?? 0;
          final double attendanceRate = (stats['attendance_rate'] ?? 0.0) is num
              ? (stats['attendance_rate'] as num).toDouble()
              : double.tryParse('${stats['attendance_rate'] ?? 0.0}') ?? 0.0;
          final int absentToday = totalStudents > presentToday ? totalStudents - presentToday : 0;

          setState(() {
            _stats = {
              'total_students': totalStudents,
              'present_count': presentToday,
              'absent_count': absentToday,
              'attendance_percentage': attendanceRate,
            };
            _isLoading = false;
            _lastUpdated = DateFormat('HH:mm:ss').format(DateTime.now());
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    // Responsive padding
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final verticalPadding = isMobile ? 12.0 : 18.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.cosmic),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: RefreshIndicator(
              onRefresh: _loadStats,
              color: AppColors.textPrimary,
              backgroundColor: AppColors.surfaceLight.withOpacity(0.9),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, isMobile ? 8 : 12, horizontalPadding, 0),
                    sliver: SliverToBoxAdapter(child: _buildHeroHeader(theme)),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                    sliver: SliverToBoxAdapter(child: _buildStatisticsSection(theme)),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, isMobile ? 16 : 24),
                    sliver: SliverToBoxAdapter(child: _buildQuickActions(theme)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(ThemeData theme) {
    final now = DateTime.now();
    final greeting = _resolveGreeting(now);
    final formattedDate = DateFormat('EEEE, MMM d').format(now);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GlassContainer(
              padding: EdgeInsets.all(isMobile ? 14 : 18),
              borderRadius: isMobile ? 20 : 26,
              child: Icon(Icons.face_rounded, color: AppColors.textPrimary, size: isMobile ? 22 : 28),
            ),
            SizedBox(width: isMobile ? 12 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: isMobile ? 12 : null),
                  ),
                  SizedBox(height: isMobile ? 2 : 4),
                  Text(
                    'Face Attendance',
                    style: theme.textTheme.headlineSmall?.copyWith(fontSize: isMobile ? 18 : null),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isMobile ? 2 : 6),
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: isMobile ? 12 : null),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 14 : 20),
        Wrap(
          spacing: isMobile ? 8 : 12,
          runSpacing: isMobile ? 8 : 12,
          children: [
            _buildConnectionBadge(),
            _buildLastUpdatedChip(theme),
            if (!isMobile) const Spacer(),
            IconButton(
              onPressed: _loadStats,
              icon: Icon(Icons.refresh_rounded, color: AppColors.textPrimary, size: isMobile ? 20 : 24),
              tooltip: 'Refresh dashboard',
              padding: EdgeInsets.all(isMobile ? 8 : 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionBadge() {
    final color = _isConnected ? AppColors.success : AppColors.danger;
    final label = _isConnected ? 'Connected' : 'Offline';
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return GlassContainer(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 16,
        vertical: isMobile ? 6 : 10,
      ),
      borderRadius: isMobile ? 18 : 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isMobile ? 8 : 10,
            height: isMobile ? 8 : 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: isMobile ? 6 : 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdatedChip(ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: GlassContainer(
        key: ValueKey(_lastUpdated),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 16,
          vertical: isMobile ? 6 : 10,
        ),
        borderRadius: isMobile ? 18 : 24,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: isMobile ? 14 : 18,
              color: AppColors.textPrimary,
            ),
            SizedBox(width: isMobile ? 6 : 8),
            Text(
              'Updated $_lastUpdated',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontSize: isMobile ? 11 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Today at a glance',
          subtitle: 'Live metrics from the recognition engine',
          icon: Icons.dashboard_customize_rounded,
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _isLoading
              ? _buildStatsLoadingState()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    
                    // Responsive grid layout
                    if (width >= 900) {
                      // Large screens: 4 columns
                      return _buildStatsGrid(4, theme);
                    } else if (width >= 600) {
                      // Tablets: 2 columns
                      return _buildStatsGrid(2, theme);
                    } else {
                      // Mobile: 2 columns (compact)
                      return _buildStatsGrid(2, theme, isCompact: true);
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatsLoadingState() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: List.generate(
        4,
        (index) => ShimmerCard(
          height: 120,
          margin: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildStatsGrid(int crossAxisCount, ThemeData theme, {bool isCompact = false}) {
    final totalStudents = _stats['total_students'] ?? 0;
    final presentToday = _stats['present_count'] ?? 0;
    final absentToday = _stats['absent_count'] ?? 0;
    final attendanceRate = _stats['attendance_percentage'] ?? 0.0;

    final cards = [
      AnimatedStatCard(
        icon: Icons.people_alt_rounded,
        label: 'Students',
        value: totalStudents,
        color: const Color(0xFF7C3AED),
        isCompact: isCompact,
      ),
      AnimatedStatCard(
        icon: Icons.verified_rounded,
        label: 'Present',
        value: presentToday,
        color: AppColors.secondary,
        isCompact: isCompact,
      ),
      AnimatedStatCard(
        icon: Icons.sentiment_dissatisfied_rounded,
        label: 'Absent',
        value: absentToday,
        color: AppColors.tertiary,
        isCompact: isCompact,
      ),
      AnimatedStatCard(
        icon: Icons.stacked_line_chart_rounded,
        label: 'Rate',
        value: attendanceRate,
        color: const Color(0xFF60A5FA),
        suffix: '%',
        isCompact: isCompact,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: isCompact ? 10 : 12,
      crossAxisSpacing: isCompact ? 10 : 12,
      childAspectRatio: isCompact ? 1.4 : 1.3,
      children: cards,
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Quick actions',
          subtitle: 'Jump into the workflows you need right now',
          icon: Icons.flash_on_rounded,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            // Use GridView for better responsive layout
            if (width >= 900) {
              // Large screens: 2 columns
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.5,
                children: _actions
                    .map((action) => QuickActionButton(
                          icon: action.icon,
                          label: action.title,
                          subtitle: action.subtitle,
                          color: action.accent,
                          onPressed: () => _navigateTo(action.builder),
                        ))
                    .toList(),
              );
            } else {
              // Mobile/Tablet: Single column list
              return Column(
                children: _actions
                    .map((action) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: QuickActionButton(
                            icon: action.icon,
                            label: action.title,
                            subtitle: action.subtitle,
                            color: action.accent,
                            onPressed: () => _navigateTo(action.builder),
                          ),
                        ))
                    .toList(),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildActionBody(_HomeAction action, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [action.accent.withOpacity(0.9), action.accent.withOpacity(0.5)],
            ),
          ),
          child: Icon(action.icon, color: AppColors.textPrimary, size: 26),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(action.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(action.subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      ],
    );
  }

  String _resolveGreeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  Future<void> _navigateTo(WidgetBuilder builder) async {
    await Navigator.of(context).push(PageTransitions.fadeScale(builder(context)));
    // Refresh stats when coming back.
    if (mounted) {
      _loadStats();
    }
  }
}

class _HomeAction {
  const _HomeAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final WidgetBuilder builder;
}