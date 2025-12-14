import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../services/simple_face_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _processing = false;
  bool _cameraError = false;
  String _errorMessage = '';
  File? _capturedImageFile;
  bool _photoCaptured = false;
  
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _courseController = TextEditingController();
  
  final SimpleFaceApiService _apiService = SimpleFaceApiService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _studentIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _courseController.dispose();
    _clearCapturedPhoto(notify: false);
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _cameraError = false;
      _errorMessage = '';
      _isCameraInitialized = false;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = true;
          _errorMessage = 'No cameras found on this device';
        });
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'No cameras found on this device',
            backgroundColor: Colors.red,
          );
        }
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _cameraError = false;
        });
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      setState(() {
        _cameraError = true;
        _errorMessage = 'Camera failed to initialize: $e\n\nPlease ensure camera permission is granted in device settings.';
      });
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Camera initialization failed. Please check app permissions.',
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }

  void _clearCapturedPhoto({bool notify = true}) {
    if (_capturedImageFile != null && _capturedImageFile!.existsSync()) {
      try {
        _capturedImageFile!.deleteSync();
      } catch (_) {
        // Ignore cleanup errors
      }
    }
    if (notify && mounted) {
      setState(() {
        _capturedImageFile = null;
        _photoCaptured = false;
      });
    } else {
      _capturedImageFile = null;
      _photoCaptured = false;
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _cameraError) {
      Fluttertoast.showToast(
        msg: 'Camera not ready. Please retry.',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      final XFile imageFile = await _controller!.takePicture();
      final tempDir = await getTemporaryDirectory();
      final File tempFile = File(
        '${tempDir.path}/registration_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await File(imageFile.path).copy(tempFile.path);

      // Remove previous capture if any
      if (_capturedImageFile != null && _capturedImageFile!.existsSync()) {
        try {
          _capturedImageFile!.deleteSync();
        } catch (_) {
          // Ignore cleanup issues
        }
      }

      if (mounted) {
        setState(() {
          _capturedImageFile = tempFile;
          _photoCaptured = true;
        });
      } else {
        _capturedImageFile = tempFile;
        _photoCaptured = true;
      }

      Fluttertoast.showToast(
        msg: 'Photo captured! Fill the form and tap Register.',
        backgroundColor: Colors.green,
        toastLength: Toast.LENGTH_SHORT,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to capture photo: $e',
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      } else {
        _processing = false;
      }
    }
  }

  Future<void> _captureAndRegister() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      Fluttertoast.showToast(
        msg: 'Please fill all required fields',
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (_capturedImageFile == null || !_capturedImageFile!.existsSync()) {
      Fluttertoast.showToast(
        msg: 'Please capture a photo before registering.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      final file = _capturedImageFile!;
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('Captured image is empty or missing');
      }

      // Show loading toast
      Fluttertoast.showToast(
        msg: 'Processing... Please wait',
        backgroundColor: Colors.blue,
        toastLength: Toast.LENGTH_SHORT,
      );
      
      // Register with API
      final response = await _apiService.registerStudent(
        imageFile: file,
        studentId: _studentIdController.text.trim(),
        name: _nameController.text.trim(),
        course: _courseController.text.trim().isEmpty ? null : _courseController.text.trim(),
      );

      setState(() {
        _processing = false;
      });

      if (response['success'] == true) {
        // Success
        Fluttertoast.showToast(
          msg: '✅ Registration successful!\n${response['message'] ?? 'Student registered'}',
          backgroundColor: Colors.green,
          toastLength: Toast.LENGTH_LONG,
        );
        
        // Clean up captured photo so it cannot be reused accidentally
        try {
          await _capturedImageFile?.delete();
        } catch (_) {
          // Ignore cleanup errors
        }
        if (mounted) {
          setState(() {
            _capturedImageFile = null;
            _photoCaptured = false;
          });
        } else {
          _capturedImageFile = null;
          _photoCaptured = false;
        }
        
        _formKey.currentState?.reset();
        _studentIdController.clear();
        _nameController.clear();
        _emailController.clear();
        _courseController.clear();
        
        
        // Navigate back after delay
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        // Error from API
        Fluttertoast.showToast(
          msg: '❌ ${response['message'] ?? 'Registration failed'}',
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (e) {
      setState(() {
        _processing = false;
      });
      
      debugPrint('Registration error: $e');
      Fluttertoast.showToast(
        msg: '❌ Registration error: $e',
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.cosmic),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildCameraSection(),
                      const SizedBox(height: 24),
                      _buildForm(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Registration',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Position face in circle and fill details',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Camera preview
          if (_isCameraInitialized && _controller != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: CameraPreview(_controller!),
              ),
            ),
          
          // Loading indicator
          if (!_isCameraInitialized && !_cameraError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 48,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Initializing Camera...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          
          // Dark overlay
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ),
          
          // Circular face guide with clear center
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // White border circle
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
                // Clear circular area using ClipOval
                if ((_isCameraInitialized && _controller != null) ||
                    (_photoCaptured && _capturedImageFile != null))
                  ClipOval(
                    child: Container(
                      width: 240,
                      height: 240,
                      child: OverflowBox(
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: 240,
                            height: 240 /
                                (_controller != null
                                    ? _controller!.value.aspectRatio
                                    : 1.0),
                            child: _photoCaptured &&
                                    _capturedImageFile != null
                                ? Image.file(
                                    _capturedImageFile!,
                                    fit: BoxFit.cover,
                                  )
                                : (_controller != null
                                    ? CameraPreview(_controller!)
                                    : const SizedBox.shrink()),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_photoCaptured && _capturedImageFile != null)
            Positioned(
              top: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: _processing
                    ? null
                    : () {
                        _clearCapturedPhoto();
                        Fluttertoast.showToast(
                          msg: 'Photo cleared. Capture again if needed.',
                          backgroundColor: Colors.blueGrey,
                          toastLength: Toast.LENGTH_SHORT,
                        );
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('Retake'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  foregroundColor: const Color(0xFF5B7FFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _photoCaptured
                        ? 'Photo captured! You can retake or register.'
                        : 'Align the face inside the circle and tap the camera button.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            child: ElevatedButton(
              onPressed: _processing ? null : _capturePhoto,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(20),
                elevation: 6,
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
                  : Icon(
                      _photoCaptured ? Icons.check : Icons.camera_alt,
                      color: _photoCaptured ? Colors.green : Colors.blue,
                      size: 32,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _studentIdController,
            icon: Icons.badge,
            hintText: 'Student ID',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter student ID';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _nameController,
            icon: Icons.person,
            hintText: 'Full Name',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            icon: Icons.email,
            hintText: 'Email (Optional)',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _courseController,
            icon: Icons.school,
            hintText: 'Class/Section',
          ),
          const SizedBox(height: 32),
          if (!_photoCaptured)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Capture a clear face photo to enable registration.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF5B7FFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF5B7FFF),
              size: 20,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: (_processing || !_photoCaptured)
                  ? null
                  : _captureAndRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _processing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Register',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
