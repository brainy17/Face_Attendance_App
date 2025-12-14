import 'package:flutter/material.dart';

import '../services/attendance_api_service.dart';
import '../services/attendance_service_extension.dart';
import '../theme/app_colors.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/glass_container.dart';
import '../widgets/section_header.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AttendanceApiService _apiService = AttendanceApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceRecords = [];
  String _errorMessage = '';
  DateTime _selectedDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }
  
  Future<void> _loadAttendanceData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final response = await _apiService.getAttendanceRecords(
        date: _selectedDate.toIso8601String().split('T')[0],
      );
      
      if (!mounted) return;
      
      if (response['success'] == true) {
        final records = response['records'];
        setState(() {
          _attendanceRecords = List<Map<String, dynamic>>.from(records);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load attendance records';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Error loading attendance: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadAttendanceData();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      title: 'Attendance Reports',
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_today_rounded),
          onPressed: () => _selectDate(context),
          tooltip: 'Select date',
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadAttendanceData,
          tooltip: 'Refresh',
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export feature will be available soon!')),
          );
        },
        tooltip: 'Export report',
        child: const Icon(Icons.file_download_rounded),
      ),
      body: Column(
        children: [
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const SectionHeader(
                  title: 'Selected date',
                  subtitle: 'Choose a day to review attendance records',
                  icon: Icons.calendar_month_rounded,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.edit_calendar_rounded),
                  label: Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAttendanceData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_attendanceRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 48, color: AppColors.secondary),
            const SizedBox(height: 16),
            Text(
              'No Records Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No attendance records for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: const [
                SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Student ID', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 40),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _attendanceRecords.length,
              separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.08), height: 1),
              itemBuilder: (context, index) {
                final record = _attendanceRecords[index];
                final studentId = record['student_id'] ?? 'Unknown';
                final name = record['name'] ?? 'Unknown';
                final timestamp = record['timestamp'] ?? '';
                final time = timestamp.isNotEmpty ? timestamp.toString().split(' ').last.substring(0, 5) : 'Unknown';

                return ListTile(
                  leading: SizedBox(
                    width: 40,
                    child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  title: Row(
                    children: [
                      Expanded(flex: 2, child: Text(studentId)),
                      Expanded(flex: 3, child: Text(name)),
                      Expanded(flex: 2, child: Text(time, style: const TextStyle(fontWeight: FontWeight.w500))),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.info_outline_rounded, size: 20),
                    onPressed: () => _showRecordDetails(record),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Records:', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _attendanceRecords.length.toString(),
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showRecordDetails(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Attendance Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Student ID', record['student_id'] ?? 'Unknown'),
              _buildDetailRow('Name', record['name'] ?? 'Unknown'),
              _buildDetailRow('Date', record['date'] ?? 'Unknown'),
              _buildDetailRow('Time', record['timestamp']?.toString().split(' ').last.substring(0, 5) ?? 'Unknown'),
              _buildDetailRow('Confidence', record['confidence'] != null 
                  ? '${(record['confidence'] * 100).toStringAsFixed(1)}%' 
                  : 'Unknown'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}