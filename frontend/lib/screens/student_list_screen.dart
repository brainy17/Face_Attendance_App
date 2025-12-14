import 'package:flutter/material.dart';

import '../api_config.dart';
import '../services/simple_face_api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/glass_container.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_dialog.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({Key? key}) : super(key: key);

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final SimpleFaceApiService _apiService = SimpleFaceApiService();
  List<dynamic> _students = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.getStudents();
      
      if (mounted) {
        setState(() {
          _students = result['success'] ? (result['students'] ?? []) : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _students = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load students: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(dynamic student) async {
    final shouldDelete = await GlassDialog.showConfirmation(
      context: context,
      title: 'Remove Student',
      message: 'Are you sure you want to remove ${student['name']} from the system? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      icon: Icons.person_remove_rounded,
      isDangerous: true,
    );

    if (shouldDelete) {
      _deleteStudent(student['student_id']);
    }
  }

  Future<void> _deleteStudent(String studentId) async {
    try {
      final result = await _apiService.deleteStudent(studentId);
      
      if (result['success']) {
        _loadStudents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete student: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _resolvePhotoUrl(dynamic student) {
    if (student['face_image_path'] == null) {
      return null;
    }

    final String value = student['face_image_path'].toString();
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

  Widget _buildStudentAvatar(String name, String? photoUrl) {
    final initials = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    if (photoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Image.network(
          photoUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialsAvatar(initials),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      );
    }

    return _buildInitialsAvatar(initials);
  }

  Widget _buildInitialsAvatar(String initials) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3366FF).withOpacity(0.8),
            const Color(0xFF3366FF),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      title: 'Student Registry',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Reload students',
          onPressed: _loadStudents,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Row(
              children: [
                const SectionHeader(
                  title: 'Registered Students',
                  subtitle: 'Manage active enrolments',
                  icon: Icons.people_alt_rounded,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Total ${_students.length}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: 5,
                    itemBuilder: (context, index) => const ShimmerListTile(),
                  )
                : _students.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'No Students Yet',
                        message: 'Start by registering your first student using the face registration screen.',
                        actionLabel: 'Register Student',
                        onAction: () => Navigator.of(context).pop(),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          final student = _students[index];
                          final String name = student['name'] ?? 'Unknown';
                          final String? photoUrl = _resolvePhotoUrl(student);

                          return GlassContainer(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStudentAvatar(name, photoUrl),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text('ID: ${student['student_id'] ?? 'N/A'}', style: theme.textTheme.bodySmall),
                                      if (student['course'] != null && student['course'].toString().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text('Course: ${student['course']}', style: theme.textTheme.bodySmall),
                                      ],
                                      const SizedBox(height: 4),
                                      Text('Registered: ${student['registration_date'] ?? 'N/A'}', style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                                  onPressed: () => _confirmDelete(student),
                                  tooltip: 'Delete student',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}