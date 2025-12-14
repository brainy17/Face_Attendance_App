import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../services/simple_face_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../widgets/face_scanning_animation.dart';
import '../widgets/success_animation.dart';

/// Real-time automatic face scanning and attendance marking screen
class AutoScanAttendanceScreen extends StatefulWidget {
  const AutoScanAttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AutoScanAttendanceScreen> createState() =>
      _AutoScanAttendanceScreenState();
}

class _AutoScanAttendanceScreenState extends State<AutoScanAttendanceScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isScanning = true;
  bool _showSuccessOverlay = false;

  String? _recognizedName;
  String? _recognizedId;
  String _statusMessage = 'Initializing camera...';

  Timer? _scanTimer;
  Timer? _successTimer;
  Set<String> _markedAttendanceIds = {}; // Prevent duplicate markings

  final SimpleFaceApiService _apiService = SimpleFaceApiService();

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCamera();
    _initializeFaceDetector();
  }

  @override
  void dispose() {
    _stopScanning();
    _cameraController?.dispose();
    _faceDetector?.close();
    _scanTimer?.cancel();
    _successTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = 'Position your face in the frame';
        });

        // Start automatic scanning
        _startAutoScan();
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Camera initialization failed';
        });
      }
    }
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);
  }

  void _startAutoScan() {
    // Scan every 1 second
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (_isScanning && !_isProcessing && mounted) {
        _captureAndProcessFrame();
      }
    });
  }

  void _stopScanning() {
    _scanTimer?.cancel();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _captureAndProcessFrame() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Scanning...';
    });

    File? tempFile;
    try {
      // Capture image
      final XFile imageFile = await _cameraController!.takePicture();
      final bytes = await imageFile.readAsBytes();

      // Detect faces using ML Kit
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        setState(() {
          _statusMessage = 'No face detected. Please position your face.';
          _isProcessing = false;
        });
        return;
      }

      if (faces.length > 1) {
        setState(() {
          _statusMessage = 'Multiple faces detected. Only one person allowed.';
          _isProcessing = false;
        });
        return;
      }

      // Face detected, send to backend for recognition
      setState(() {
        _statusMessage = 'Face detected! Verifying...';
      });

      // Save temporary file for API call
      final tempDir = await getTemporaryDirectory();
      tempFile = File(
          '${tempDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);

      // Call backend API
      final result = await _apiService.markAttendance(imageFile: tempFile);

      if (!mounted) return;

      if (result['success'] == true) {
        final studentId = result['student_id']?.toString() ?? '';
        final name = result['name']?.toString() ?? 'Student';

        // Check if already marked in this session
        if (_markedAttendanceIds.contains(studentId)) {
          setState(() {
            _statusMessage = 'Attendance already marked for $name';
            _isProcessing = false;
          });
          return;
        }

        // Mark as successful
        _markedAttendanceIds.add(studentId);
        _showSuccessMessage(
          name: name,
          studentId: studentId,
          message: result['message']?.toString() ??
              'Attendance marked successfully',
        );
      } else {
        setState(() {
          _statusMessage = result['message']?.toString() ??
              'Face not recognized. Please register first.';
          _isProcessing = false;
        });

        // Show snackbar for unrecognized face
        _showSnackMessage(
          result['message']?.toString() ?? 'Face not recognized',
          success: false,
        );

        // Resume scanning after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _statusMessage = 'Position your face in the frame';
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error processing frame: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Error processing image. Please try again.';
          _isProcessing = false;
        });
      }
    } finally {
      // Clean up temp file
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  void _showSuccessMessage({
    required String name,
    required String studentId,
    required String message,
  }) {
    _stopScanning(); // Stop automatic scanning

    setState(() {
      _showSuccessOverlay = true;
      _recognizedName = name;
      _recognizedId = studentId;
      _statusMessage = message;
      _isProcessing = false;
    });

    // Show success snackbar
    _showSnackMessage('Attendance marked for $name', success: true);

    // Hide success overlay and resume scanning after 4 seconds
    _successTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showSuccessOverlay = false;
          _recognizedName = null;
          _recognizedId = null;
          _statusMessage = 'Position your face in the frame';
          _isScanning = true;
        });
        _startAutoScan();
      }
    });
  }

  void _showSnackMessage(String message, {required bool success}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: success ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: success ? 3 : 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _resetSession() {
    setState(() {
      _markedAttendanceIds.clear();
      _showSuccessOverlay = false;
      _recognizedName = null;
      _recognizedId = null;
      _statusMessage = 'Position your face in the frame';
      _isScanning = true;
      _isProcessing = false;
    });
    _startAutoScan();
  }

  Widget _buildCameraView() {
    if (!_isCameraInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        CameraPreview(_cameraController!),

        // Dark overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.6),
              ],
            ),
          ),
        ),

        // Scanning animation overlay
        Center(
          child: FaceScanningAnimation(
            isScanning: _isScanning && !_showSuccessOverlay,
            size: 280,
            scanColor: AppColors.secondary,
          ),
        ),

        // Status message at top
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: _buildStatusHeader(),
        ),

        // Instructions
        Positioned(
          top: 120,
          left: 0,
          right: 0,
          child: _buildInstructions(),
        ),

        // Success overlay
        if (_showSuccessOverlay) _buildSuccessOverlay(),

        // Control buttons at bottom
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: _buildControls(),
        ),

        // Statistics
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: _buildStatistics(),
        ),
      ],
    );
  }

  Widget _buildStatusHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.secondary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isScanning
                      ? Icons.radar
                      : _showSuccessOverlay
                          ? Icons.check_circle
                          : Icons.pause_circle_outline,
                  color: _showSuccessOverlay
                      ? AppColors.success
                      : AppColors.secondary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  _isScanning
                      ? 'Auto-Scan Active'
                      : _showSuccessOverlay
                          ? 'Success!'
                          : 'Scanning Paused',
                  style: TextStyle(
                    color: _showSuccessOverlay
                        ? AppColors.success
                        : AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildInstructionItem(Icons.face_rounded, 'Look straight at camera'),
          const SizedBox(height: 8),
          _buildInstructionItem(Icons.wb_sunny_outlined, 'Ensure good lighting'),
          const SizedBox(height: 8),
          _buildInstructionItem(Icons.remove_circle_outline, 'Remove glasses'),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.secondary, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
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
              color: AppColors.success.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SuccessAnimation(size: 100, color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              'Attendance Marked!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_recognizedName != null) ...[
              const SizedBox(height: 16),
              Text(
                _recognizedName!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_recognizedId != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'ID: $_recognizedId',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: _isScanning ? Icons.pause_circle : Icons.play_circle,
          label: _isScanning ? 'Pause' : 'Resume',
          onPressed: () {
            if (_isScanning) {
              _stopScanning();
            } else {
              _resetSession();
            }
          },
        ),
        _buildControlButton(
          icon: Icons.refresh,
          label: 'Reset',
          onPressed: _resetSession,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.9),
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
      ),
    );
  }

  Widget _buildStatistics() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: 8),
          Text(
            'Marked Today: ${_markedAttendanceIds.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Auto-Scan Attendance'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.cosmic),
        child: SafeArea(child: _buildCameraView()),
      ),
    );
  }
}
