import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../api_config.dart';
import '../services/simple_face_api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/glass_container.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_chip.dart';

class AttendanceLogsScreen extends StatefulWidget {
  const AttendanceLogsScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceLogsScreen> createState() => _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen>
    with SingleTickerProviderStateMixin {
  final SimpleFaceApiService _apiService = SimpleFaceApiService();
  final List<dynamic> _logs = [];
  bool _isLoading = true;
  bool _isDownloading = false;
  DateTime _selectedDate = DateTime.now();
  String _viewMode = 'daily';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadLogs();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    final mode = _tabController.index == 0 ? 'daily' : 'monthly';
    if (mode != _viewMode) {
      setState(() {
        _viewMode = mode;
      });
      _loadLogs();
    }
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_viewMode == 'daily') {
        final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
        final result = await _apiService.getAttendanceLogs(
          dateFrom: formattedDate,
          dateTo: formattedDate,
        );

        if (!mounted) return;
        setState(() {
          _logs
            ..clear()
            ..addAll(result['success']
                ? (result['records'] ?? result['logs'] ?? [])
                : []);
          _isLoading = false;
        });
      } else {
        final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
        final lastDay =
            DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

        final formattedFirst = DateFormat('yyyy-MM-dd').format(firstDay);
        final formattedLast = DateFormat('yyyy-MM-dd').format(lastDay);

        final result = await _apiService.getAttendanceLogs(
          dateFrom: formattedFirst,
          dateTo: formattedLast,
        );

        if (!mounted) return;
        setState(() {
          _logs
            ..clear()
            ..addAll(result['success']
                ? (result['records'] ?? result['logs'] ?? [])
                : []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logs.clear();
        _isLoading = false;
      });
      _showToast('Failed to load logs: $e', Colors.red);
    }
  }

  void _showToast(String message, Color backgroundColor) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _downloadReport(String format) async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final baseUrl = getBaseUrl();
      final String url;

      if (_viewMode == 'daily') {
        final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
        url =
            '$baseUrl/api/reports/download?report_type=daily&format=$format&date=$formattedDate';
      } else {
        final month = DateFormat('MMMM').format(_selectedDate);
        final year = _selectedDate.year;
        url =
            '$baseUrl/api/reports/download?report_type=monthly&format=$format&month=$month&year=$year';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to download report');
      }

      final directory = await _resolveDownloadDirectory();
      if (directory == null) {
        throw Exception('No writable download directory available');
      }

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final fileName = _viewMode == 'daily'
          ? 'attendance_${DateFormat('yyyy_MM_dd').format(_selectedDate)}.$format'
          : 'attendance_${DateFormat('yyyy_MM').format(_selectedDate)}.$format';

      final filePath = '${directory.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
      });

      _showToast('✅ Report downloaded successfully!', Colors.green);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Download Complete'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('File saved to:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  filePath,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
      });
      _showToast('❌ Download failed: $e', Colors.red);
    }
  }

  Future<Directory?> _resolveDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        final directories = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (directories != null && directories.isNotEmpty) {
          return directories.first;
        }

        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          return dir;
        }
      } else if (Platform.isIOS) {
        return await getApplicationDocumentsDirectory();
      } else {
        final desktopDir = await getDownloadsDirectory();
        if (desktopDir != null) {
          return desktopDir;
        }
        return await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      debugPrint('Failed to resolve download directory: $e');
    }
    return null;
  }

  void _showDownloadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Download ${_viewMode == 'daily' ? 'Daily' : 'Monthly'} Report',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _viewMode == 'daily'
                  ? DateFormat('MMMM dd, yyyy').format(_selectedDate)
                  : DateFormat('MMMM yyyy').format(_selectedDate),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            _buildDownloadOption(
              icon: Icons.picture_as_pdf,
              title: 'PDF Format',
              subtitle: 'Download as PDF document',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _downloadReport('pdf');
              },
            ),
            const SizedBox(height: 12),
            _buildDownloadOption(
              icon: Icons.table_chart,
              title: 'Excel Format',
              subtitle: 'Download as Excel spreadsheet',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _downloadReport('excel');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmFinalizeAttendance() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_rounded,
                  color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Finalize Attendance?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'After finalizing, no additional attendance records can be added for this session. '
          'Make sure everyone has been marked before continuing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _finalizeAttendance();
    }
  }

  Future<void> _finalizeAttendance() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final result =
          await _apiService.finalizeAttendance(attendanceDate: formattedDate);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success']) {
        // Reload logs to show absent students
        await _loadLogs();
        _showFinalizedBottomSheet(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to finalize attendance'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFinalizedBottomSheet(Map<String, dynamic> result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.check_circle, color: Colors.blue, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Attendance Finalized',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${result['total_students']} | Present: ${result['present']} | Absent: ${result['absent']}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text(
              'The attendance window has been finalized. Records are now locked in.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.done_all),
              label: const Text('Great!'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B7FFF),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: color.withOpacity(0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final finalizeAction = isMobile
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              onPressed: _confirmFinalizeAttendance,
              tooltip: 'Finalize attendance',
              icon: const Icon(Icons.lock_clock_rounded),
              splashRadius: 20,
            ),
          )
        : Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade600, Colors.orange.shade700],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _confirmFinalizeAttendance,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_clock_rounded,
                          size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Finalize',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

    final downloadAction = isMobile
        ? Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: _isDownloading ? null : _showDownloadOptions,
              tooltip: 'Export attendance',
              splashRadius: 20,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isDownloading
                    ? const SizedBox(
                        key: ValueKey('downloading-mobile'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded,
                        key: ValueKey('download-mobile')),
              ),
            ),
          )
        : Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isDownloading ? null : _showDownloadOptions,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isDownloading
                            ? const SizedBox(
                                key: ValueKey('downloading-desktop'),
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.download_rounded,
                                key: ValueKey('download-desktop'),
                                size: 18,
                                color: Colors.white,
                              ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Export',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

    return AppPageScaffold(
      title: 'Attendance Logs',
      actions: [
        finalizeAction,
        downloadAction,
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(isMobile ? 46 : 52),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 20,
            0,
            isMobile ? 12 : 20,
            isMobile ? 6 : 10,
          ),
          child: GlassContainer(
            padding: EdgeInsets.all(isMobile ? 3 : 4),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              ),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  height: isMobile ? 36 : 40,
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.today_rounded, size: isMobile ? 16 : 17),
                      SizedBox(width: isMobile ? 4 : 6),
                      const Text('Daily'),
                    ],
                  ),
                ),
                Tab(
                  height: isMobile ? 36 : 40,
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: isMobile ? 16 : 17),
                      SizedBox(width: isMobile ? 4 : 6),
                      const Text('Monthly'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadLogs,
        color: AppColors.secondary,
        backgroundColor: AppColors.surfaceLight,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 20,
              isMobile ? 12 : 20,
              isMobile ? 12 : 20,
              isMobile ? 16 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateSelector(theme),
                SizedBox(height: isMobile ? 16 : 20),
                _buildMetricsRow(theme),
                SizedBox(height: isMobile ? 18 : 24),
                const SectionHeader(
                  title: 'Attendance activity',
                  icon: Icons.list_alt_rounded,
                ),
                SizedBox(height: isMobile ? 14 : 18),
                _buildLogsSection(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(ThemeData theme) {
    final displayDate = _viewMode == 'daily'
        ? DateFormat('EEEE, MMM d, yyyy').format(_selectedDate)
        : DateFormat('MMMM yyyy').format(_selectedDate);
    final helperText = _viewMode == 'daily'
        ? 'Tap to choose another day'
        : 'Tap to choose another month';
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    Future<void> openPicker() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: AppColors.primary),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        setState(() => _selectedDate = picked);
        await _loadLogs();
      }
    }

    return GlassContainer(
      onTap: openPicker,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 18,
        vertical: isMobile ? 12 : 16,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF7C3AED)],
              ),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: AppColors.textPrimary,
              size: isMobile ? 14 : 18,
            ),
          ),
          SizedBox(width: isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayDate,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: isMobile ? 13 : 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 2 : 3),
                Text(
                  helperText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: isMobile ? 10 : 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: isMobile ? 18 : 22,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(ThemeData theme) {
    Widget buildResponsiveWrap(List<Widget> items, BoxConstraints constraints) {
      final width = constraints.maxWidth;
      const spacing = 12.0;
      const runSpacing = 12.0;

      int columns;
      if (width >= 980) {
        columns = 4;
      } else if (width >= 740) {
        columns = 3;
      } else if (width >= 520) {
        columns = 2;
      } else {
        columns = 1;
      }

      final availableSpace = width - (spacing * (columns - 1));
      final itemWidth = (availableSpace / columns).clamp(0.0, width).toDouble();

      return LayoutBuilder(
        builder: (context, _) {
          return Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: items
                .map(
                  (widget) => SizedBox(
                    width: itemWidth,
                    child: widget,
                  ),
                )
                .toList(),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isLoading && _logs.isEmpty) {
          final placeholders = List<Widget>.generate(
            4,
            (index) => GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      height: 10,
                      width: 60,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 8),
                  Container(
                      height: 14,
                      width: 80,
                      decoration: BoxDecoration(
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(10))),
                ],
              ),
            ),
          );

          return buildResponsiveWrap(placeholders, constraints);
        }

        final totalRecords = _logs.length;
        final presentCount = _logs.where((entry) {
          final status = (entry['status'] ?? entry['attendance_status'] ?? '')
              .toString()
              .toLowerCase();
          return status == 'present';
        }).length;
        final absentCount = totalRecords - presentCount;
        final attendanceRate =
            totalRecords == 0 ? 0.0 : (presentCount / totalRecords) * 100;

        final chips = [
          StatChip(
            icon: Icons.fact_check_rounded,
            label: 'Total Logs',
            value: '$totalRecords',
            color: AppColors.primary,
          ),
          StatChip(
            icon: Icons.verified_user_rounded,
            label: 'Present',
            value: '$presentCount',
            color: AppColors.secondary,
          ),
          StatChip(
            icon: Icons.cancel_schedule_send_rounded,
            label: 'Absent',
            value: '$absentCount',
            color: AppColors.tertiary,
          ),
          StatChip(
            icon: Icons.percent_rounded,
            label: 'Rate',
            value: '${attendanceRate.toStringAsFixed(1)}%',
            color: const Color(0xFF60A5FA),
          ),
        ];

        return buildResponsiveWrap(chips, constraints);
      },
    );
  }

  Widget _buildLogsSection(ThemeData theme) {
    if (_isLoading) {
      return _buildLogsLoadingSkeleton();
    }

    if (_logs.isEmpty) {
      return _buildEmptyState(theme);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final Map<String, dynamic> log =
            Map<String, dynamic>.from(_logs[index]);
        return _buildLogTile(theme, log);
      },
    );
  }

  Widget _buildLogsLoadingSkeleton() {
    return Column(
      children: List.generate(
        4,
        (index) => GlassContainer(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 16,
                        width: 180,
                        decoration: BoxDecoration(
                            color: Colors.white30,
                            borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 10),
                    Container(
                        height: 12,
                        width: 140,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 8),
                    Container(
                        height: 12,
                        width: 120,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.08),
                ],
              ),
            ),
            child: const Icon(Icons.inbox_outlined,
                size: 48, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Text('No records found', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'No attendance logs for this ${_viewMode == 'daily' ? 'date' : 'month'} yet.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String? _resolvePhotoUrl(Map<String, dynamic> log) {
    final dynamic raw =
        log['photo_url'] ?? log['photoPath'] ?? log['photo_path'];
    if (raw == null) {
      return null;
    }

    final String value = raw.toString();
    if (value.isEmpty) {
      return null;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final String base = getBaseUrl();
    if (value.startsWith('/')) {
      return '$base$value';
    }
    return '$base/$value';
  }

  Widget _buildInitialsAvatar({
    required String initials,
    required bool isPresent,
  }) {
    final gradientColors = isPresent
        ? [AppColors.secondary, const Color(0xFF38BDF8)]
        : [AppColors.tertiary, const Color(0xFFFF5C8A)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentAvatar({
    required String name,
    required bool isPresent,
    String? photoUrl,
    double size = 64,
  }) {
    final initials = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    Widget avatar =
        _buildInitialsAvatar(initials: initials, isPresent: isPresent);

    if (photoUrl != null) {
      avatar = Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _buildInitialsAvatar(initials: initials, isPresent: isPresent),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return Container(
            color: Colors.white.withOpacity(0.08),
            child: Center(
              child: SizedBox(
                width: size * 0.3,
                height: size * 0.3,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }

    final statusColor = isPresent ? AppColors.success : AppColors.danger;
    final borderRadius = size * 0.3125; // Maintains 20/64 ratio

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: size * 0.21875, // Maintains 14/64 ratio
                offset: Offset(0, size * 0.125), // Maintains 8/64 ratio
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: avatar,
          ),
        ),
        Positioned(
          right: size * 0.03125, // Maintains 2/64 ratio
          bottom: size * 0.03125,
          child: Container(
            padding: EdgeInsets.all(size * 0.0625), // Maintains 4/64 ratio
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textPrimary, width: 2),
            ),
            child: Icon(
              isPresent ? Icons.check : Icons.close,
              size: size * 0.1875, // Maintains 12/64 ratio
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogTile(ThemeData theme, Map<String, dynamic> log) {
    final String name =
        (log['name'] ?? log['student_name'] ?? 'Unknown').toString();
    final String studentId =
        (log['student_id'] ?? log['roll_no'] ?? 'N/A').toString();
    final String status =
        (log['status'] ?? log['attendance_status'] ?? 'Unknown').toString();
    final bool isPresent = status.toLowerCase() == 'present';
    final String timestamp = (log['time'] ?? log['timestamp'] ?? '').toString();
    final String confidence = log['confidence'] != null
        ? '${(double.tryParse(log['confidence'].toString()) ?? 0).toStringAsFixed(2)}'
        : '';
    final String? photoUrl = _resolvePhotoUrl(log);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return GlassContainer(
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 14),
      padding: EdgeInsets.all(isMobile ? 10 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStudentAvatar(
            name: name,
            isPresent: isPresent,
            photoUrl: photoUrl,
            size: isMobile ? 44 : 56,
          ),
          SizedBox(width: isMobile ? 8 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: isMobile ? 13 : 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: isMobile ? 4 : 6),
                    _buildStatusBadge(status, isPresent),
                  ],
                ),
                SizedBox(height: isMobile ? 4 : 7),
                Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: isMobile ? 12 : 15,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: isMobile ? 3 : 5),
                    Flexible(
                      child: Text(
                        'ID: $studentId',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: isMobile ? 10 : 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (timestamp.isNotEmpty) ...[
                  SizedBox(height: isMobile ? 3 : 5),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: isMobile ? 12 : 15,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: isMobile ? 3 : 5),
                      Flexible(
                        child: Text(
                          timestamp,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: isMobile ? 10 : 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (confidence.isNotEmpty && !isMobile) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.insights_rounded,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('Confidence: $confidence',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isPresent) {
    final Color baseColor = isPresent ? AppColors.success : AppColors.danger;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(color: baseColor.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: isMobile ? 10 : 11,
        ),
      ),
    );
  }
}
