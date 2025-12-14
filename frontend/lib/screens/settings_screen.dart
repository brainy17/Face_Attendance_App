import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_config.dart';
import '../theme/app_colors.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/glass_container.dart';
import '../widgets/section_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiUrlController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  late String _apiUrl;
  
  // App settings
  bool _enableHighQualityMode = true;
  bool _saveAttendanceLogs = true;
  double _confidenceThreshold = 0.6;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load API configuration
      _apiUrl = ApiConfig.getBaseUrl();
      _apiUrlController.text = _apiUrl;
      
      // Load app settings
      setState(() {
        _enableHighQualityMode = prefs.getBool('enableHighQualityMode') ?? true;
        _saveAttendanceLogs = prefs.getBool('saveAttendanceLogs') ?? true;
        _confidenceThreshold = prefs.getDouble('confidenceThreshold') ?? 0.6;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save app settings
      await prefs.setBool('enableHighQualityMode', _enableHighQualityMode);
      await prefs.setBool('saveAttendanceLogs', _saveAttendanceLogs);
      await prefs.setDouble('confidenceThreshold', _confidenceThreshold);
      
      // For demo purposes, we're not actually changing the API URL at runtime
      // In a real app, you would update your API config here
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppPageScaffold(
        title: 'Settings',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);

    return AppPageScaffold(
      title: 'Settings',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _isLoading ? null : _loadSettings,
          tooltip: 'Reload Settings',
        ),
      ],
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            GlassContainer(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'API Configuration',
                    subtitle: 'Manage backend connection details',
                    icon: Icons.api_rounded,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _apiUrlController,
                    decoration: const InputDecoration(
                      labelText: 'API Server URL',
                      prefixIcon: Icon(Icons.link_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter API URL';
                      }
                      if (!value.startsWith('http://') && !value.startsWith('https://')) {
                        return 'URL must start with http:// or https://';
                      }
                      return null;
                    },
                    enabled: false,
                    readOnly: true,
                    onChanged: (value) => _apiUrl = value,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Note: API URL can only be changed in the configuration file for now.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GlassContainer(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Face Recognition Settings',
                    subtitle: 'Control recognition precision and capture quality',
                    icon: Icons.face_retouching_natural_rounded,
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('High Quality Mode'),
                    subtitle: const Text('Enables higher resolution captures for better recognition accuracy'),
                    value: _enableHighQualityMode,
                    onChanged: (value) => setState(() => _enableHighQualityMode = value),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tune_rounded, color: AppColors.secondary),
                    title: const Text('Recognition Confidence Threshold'),
                    subtitle: Text('${(_confidenceThreshold * 100).toStringAsFixed(0)}%'),
                  ),
                  Slider(
                    value: _confidenceThreshold,
                    min: 0.3,
                    max: 0.9,
                    divisions: 12,
                    label: '${(_confidenceThreshold * 100).toStringAsFixed(0)}%',
                    onChanged: (value) => setState(() => _confidenceThreshold = value),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Lower (30%)', style: theme.textTheme.bodySmall),
                      Text('Higher (90%)', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GlassContainer(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Storage & Data',
                    subtitle: 'Retention policies for device-side data',
                    icon: Icons.storage_rounded,
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Save Attendance Logs'),
                    subtitle: const Text('Store detailed attendance metadata locally for offline review'),
                    value: _saveAttendanceLogs,
                    onChanged: (value) => setState(() => _saveAttendanceLogs = value),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    title: const Text('Clear Local Cache'),
                    subtitle: const Text('Remove temporary files and cached images from device storage'),
                    onTap: _showClearDataConfirmationDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Settings'),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Column(
                children: [
                  Text('Face Attendance App', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Version 1.0.0', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, {IconData? icon, Color? color}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: color ?? Colors.blue),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.blue,
          ),
        ),
      ],
    );
  }
  
  void _showClearDataConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.amber),
            SizedBox(width: 10),
            Text('Clear Local Cache'),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear all locally cached data? '
          'This will remove all temporary files and cached images.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: AppColors.textPrimary),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }
}