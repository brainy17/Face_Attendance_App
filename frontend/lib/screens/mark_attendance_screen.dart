import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/simple_face_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../widgets/success_animation.dart';
import '../widgets/animated_button.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({Key? key}) : super(key: key);

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _processing = false;
  bool _showSuccessOverlay = false;
  String? _recognizedName;
  String? _recognizedId;
  Timer? _successOverlayTimer;

  final SimpleFaceApiService _apiService = SimpleFaceApiService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _successOverlayTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _captureAndProcessImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    _successOverlayTimer?.cancel();

    setState(() {
      _processing = true;
      _showSuccessOverlay = false;
      _recognizedName = null;
      _recognizedId = null;
    });

    File? tempFile;
    try {
      final XFile imageFile = await _controller!.takePicture();
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/attendance_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(imageFile.path).copy(tempFile.path);

      final result = await _apiService.markAttendance(imageFile: tempFile);
      if (!mounted) return;

      if (result['success'] == true) {
        _showSuccessBanner(
          name: result['name']?.toString() ?? 'Student',
          studentId: result['student_id']?.toString(),
        );
        _showSnackMessage(
          result['message']?.toString().isNotEmpty == true
              ? result['message'].toString()
              : 'Attendance marked successfully.',
          success: true,
        );
      } else {
        _showSnackMessage(
          result['message']?.toString().isNotEmpty == true
              ? result['message'].toString()
              : 'Unable to mark attendance. Please try again.',
          success: false,
        );
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error processing attendance: $e');
        _showSnackMessage(
          'Unable to process the photo. Please try again.',
          success: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }

      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  void _showSnackMessage(String message, {required bool success}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
  backgroundColor: success ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessBanner({required String name, String? studentId}) {
    _successOverlayTimer?.cancel();
    setState(() {
      _showSuccessOverlay = true;
      _recognizedName = name;
      _recognizedId = studentId;
    });

    _successOverlayTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _showSuccessOverlay = false;
      });
    });
  }

  Widget _buildCameraView() {
    if (!_isCameraInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        CameraPreview(_controller!),
        // Overlay for face positioning guide
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
            ),
            child: Center(
              child: Container(
                width: 250,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.secondary, width: 3),
                  borderRadius: BorderRadius.circular(150),
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.35),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.face,
                      size: 60,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Center your face',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Camera controls
        Positioned(
          bottom: 30,
          child: ElevatedButton(
            onPressed: _processing ? null : _captureAndProcessImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(20),
            ),
            child: _processing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                : const Icon(
                    Icons.camera_alt,
                    color: Colors.blue,
                    size: 32,
                  ),
          ),
        ),
        // Instructions
        Positioned(
          top: 50,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Mark Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Look straight • Good lighting • Remove glasses',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 140,
          child: IgnorePointer(
            ignoring: true,
            child: AnimatedOpacity(
              opacity: _showSuccessOverlay ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.success.withOpacity(0.95),
                      AppColors.success.withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SuccessAnimation(size: 80, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'Attendance Recorded',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_recognizedName != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _recognizedName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_recognizedId != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'ID: $_recognizedId',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppGradients.cosmic),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.cosmic),
        child: SafeArea(child: _buildCameraView()),
      ),
    );
  }
}