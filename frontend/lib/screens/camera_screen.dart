import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/scan_overlay.dart';
import '../widgets/face_detection_painter.dart';
import '../services/attendance_api_service.dart';

enum CameraMode { register, mark }

class CameraScreen extends StatefulWidget {
  final CameraMode mode;
  const CameraScreen({required this.mode, super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _processing = false;
  late AttendanceApiService _apiService;

  @override
  void initState() {
    super.initState();
    // Initialize the API service
    _apiService = AttendanceApiService();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
    
    // Use higher resolution for better face detection quality
    _controller = CameraController(
      camera, 
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg
    );
    
    await _controller!.initialize();
    
    // Set optimal camera parameters for face detection
    await _controller!.setFlashMode(FlashMode.off);
    await _controller!.setExposureMode(ExposureMode.auto);
    await _controller!.setFocusMode(FocusMode.auto);
    
    // Start face detection if controller is available
    if (_controller != null) {
      _startFaceDetection();
    }
    
    if (mounted) setState(() {});
  }
  
  // Face detection variables
  bool _faceDetected = false;
  bool _goodLighting = true;
  Rect? _faceRect;
  Timer? _detectionTimer;

  Future<void> _captureAndSend() async {
    // Check if face is detected and has good quality before proceeding
    if (!_faceDetected) {
      _showErrorDialog(
        'No Face Detected', 
        'We couldn\'t detect your face properly in the camera frame.',
        errorType: 'face_detection_failed',
        suggestions: [
          'Position your face in the center of the frame',
          'Make sure your face is fully visible',
          'Remove any objects blocking your face',
          'Try in a well-lit area facing the light source'
        ],
      );
      return;
    }
    
    if (!_goodLighting) {
      // Use detailed feedback from the backend if available
      String detailedMessage = 'The image quality is too low for accurate face recognition.';
      List<String> customSuggestions = [];
      
      if (_lastDetectionResult != null) {
        // Extract more detailed information from the detection result
        if (_lastDetectionResult!.containsKey('quality_details')) {
          final qualityDetails = _lastDetectionResult!['quality_details'];
          
          if (qualityDetails is Map) {
            // Check limiting factors to provide specific suggestions
            final limitingFactors = qualityDetails['limiting_factors'];
            final brightnessValue = qualityDetails['brightness_value'];
            final sharpnessScore = qualityDetails['sharpness_score'] ?? 0.0;
            
            if (limitingFactors is List && limitingFactors.isNotEmpty) {
              if (limitingFactors.contains('brightness')) {
                if (brightnessValue != null && brightnessValue < 80) {
                  detailedMessage = 'The image is too dark for accurate recognition.';
                  customSuggestions.add('Move to a brighter area with more light');
                  customSuggestions.add('Face a light source directly');
                } else if (brightnessValue != null && brightnessValue > 200) {
                  detailedMessage = 'The image is too bright or overexposed.';
                  customSuggestions.add('Avoid direct strong light or glare');
                  customSuggestions.add('Move to an area with softer lighting');
                }
              }
              
              if (limitingFactors.contains('sharpness') || sharpnessScore < 0.4) {
                customSuggestions.add('Hold the camera steady to avoid blur');
                customSuggestions.add('Clean the camera lens if it appears foggy');
              }
              
              if (limitingFactors.contains('size')) {
                customSuggestions.add('Move closer to the camera');
                customSuggestions.add('Ensure your entire face is visible in the frame');
              }
            }
          }
        }
      }
      
      // If we didn't get specific suggestions from the backend, use default ones
      if (customSuggestions.isEmpty) {
        customSuggestions = [
          'Move to a well-lit area',
          'Avoid strong backlighting',
          'Hold the device steady',
          'Ensure your face is clearly visible',
        ];
      }
      
      _showErrorDialog(
        'Poor Image Quality', 
        detailedMessage,
        errorType: 'poor_quality',
        suggestions: customSuggestions,
      );
      return;
    }
    
    // Visual and haptic feedback before taking picture
    HapticFeedback.mediumImpact();
    
    setState(() => _processing = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _controller!.takePicture().then((file) => file.saveTo(filePath));
      final imageFile = File(filePath);
      
      // Verify that the file exists and is accessible
      if (!imageFile.existsSync()) {
        throw FileSystemException('Image file not found after capture');
      }

      Map<String, dynamic> response = {};
      // Handle different modes
      
      if (widget.mode == CameraMode.mark) {
        // Attendance marking mode
        response = await _apiService.markAttendance(imageFile: imageFile);
      }
      else if (widget.mode == CameraMode.register) {
        // Registration mode
        String name = await _promptForName(context);
        if (name.isEmpty) {
          setState(() => _processing = false);
          return;
        }
        
        String studentId = await _promptForStudentId(context);
        if (studentId.isEmpty) {
          setState(() => _processing = false);
          return;
        }
        
        // Validate inputs
        if (name.trim().length < 3) {
          _showErrorDialog(
            'Invalid Name',
            'Please provide a valid full name.',
            errorType: 'invalid_input',
          );
          setState(() => _processing = false);
          return;
        }
        
        if (studentId.trim().isEmpty) {
          _showErrorDialog(
            'Invalid ID',
            'Please provide a valid student ID.',
            errorType: 'invalid_input',
          );
          setState(() => _processing = false);
          return;
        }
        
        // Use the API service for registration
        response = await _apiService.registerStudent(
          imageFile: imageFile,
          studentId: studentId.trim(),
          name: name.trim(),
        );
      }

      // Handle response with enhanced error messages
      final success = response['success'] ?? false;
      final message = response['message'] ?? 'Unknown response';
      final errorType = response['error_type'];

      if (success) {
        // Success case - student registered
        // Trigger haptic feedback on success
        HapticFeedback.lightImpact();
        
        // Show success dialog
        _showSuccessDialog(message);
      } else {
        // Handle different error types with specific messaging and suggestions
        String errorTitle;
        String errorMessage;
        List<String> suggestions = [];
        
        switch (errorType) {
          case 'face_detection_failed':
            errorTitle = 'Face Not Detected';
            errorMessage = message.isNotEmpty ? message : 'The system could not detect a face in the provided image.';
            suggestions = [
              'Ensure your entire face is visible in the frame',
              'Find a location with better lighting',
              'Hold the camera steady to avoid blur',
              'Remove masks, heavy makeup, or objects covering your face'
            ];
            break;
            
          case 'recognition_failed':
            errorTitle = 'Face Not Recognized';
            errorMessage = message.isNotEmpty ? message : 'Your face couldn\'t be matched with any registered student.';
            
            // Add confidence info if available
            final requiredScore = response['required_score'] ?? response['threshold'] ?? 0.6;
            final bestScore = response['best_score'] ?? 0.0;
            
            // Only add confidence details if we have the values
            if (bestScore > 0) {
              errorMessage += '\n\nConfidence: ${(bestScore * 100).toStringAsFixed(1)}%\nRequired: ${(requiredScore * 100).toStringAsFixed(1)}%';
            }
            
            suggestions = [
              'Verify that you are registered in the system',
              'Try again with better lighting and a clear face view',
              'Remove accessories like glasses or hats if possible',
              'If the problem persists, try re-registering your face'
            ];
            break;
            
          case 'encoding_failed':
            errorTitle = 'Face Processing Failed';
            errorMessage = message.isNotEmpty ? message : 'Your face was detected, but could not be processed for recognition.';
            suggestions = [
              'Try again with better lighting',
              'Hold the camera steady to avoid blur',
              'Ensure your face is clearly visible with good contrast',
              'Position yourself to avoid shadows on your face'
            ];
            break;
            
          case 'no_students_registered':
            errorTitle = 'No Students Registered';
            errorMessage = 'There are no students registered in the system yet.';
            suggestions = [
              'Register yourself as a student first',
              'Contact the administrator to register students',
              'Use the registration feature first'
            ];
            break;
            
          case 'connection_error':
            errorTitle = 'Connection Error';
            errorMessage = message.isNotEmpty ? message : 'Failed to connect to the server.';
            suggestions = [
              'Check your internet connection',
              'Verify that the server is running',
              'Try again in a few moments',
              'Contact support if the problem persists'
            ];
            break;
            
          case 'timeout_error':
            errorTitle = 'Request Timeout';
            errorMessage = message.isNotEmpty ? message : 'The server took too long to respond.';
            suggestions = [
              'Check your internet connection speed',
              'The server might be overloaded, try again later',
              'Contact support if the problem persists'
            ];
            break;
            
          case 'invalid_image':
            errorTitle = 'Invalid Image';
            errorMessage = message.isNotEmpty ? message : 'The captured image could not be processed.';
            suggestions = [
              'Try capturing the image again',
              'Ensure good lighting conditions',
              'Restart the app if the problem persists'
            ];
            break;
            
          case 'system_error':
          default:
            errorTitle = errorType != null ? 'System Error' : 'Recognition Failed';
            errorMessage = message.isNotEmpty ? message : 'An unexpected error occurred during recognition.';
            suggestions = [
              'Try again in a few moments',
              'Restart the app if the problem persists',
              'Contact support if the issue continues'
            ];
            break;
        }
        
        _showErrorDialog(errorTitle, errorMessage, errorType: errorType, suggestions: suggestions);
      }
    } on FileSystemException catch (e) {
      debugPrint('Camera file error: ${e.message}');
      _showErrorDialog(
        'Camera Error', 
        'Failed to save or access the captured image: ${e.message}',
        errorType: 'file_error',
        suggestions: [
          'Check storage permissions',
          'Ensure your device has available storage',
          'Restart the app and try again'
        ],
      );
    } catch (e) {
      debugPrint('❌ Camera error: $e');
      _showErrorDialog(
        'Camera Error', 
        'Failed to process image: $e',
        errorType: 'system_error',
        suggestions: [
          'Restart the app and try again',
          'Check your device camera permissions',
          'Make sure your camera is working properly',
          'Contact support if the problem persists'
        ],
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              const Text('Success'),
            ],
          ),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Process images for face detection
  // Face quality feedback variables
  String _statusMessage = 'Position your face in the frame';
  String _qualityMessage = '';
  double _qualityScore = 0.0;
  Map<String, dynamic>? _lastDetectionResult;
  
  void _startFaceDetection() {
    // Cancel existing timer if it's already running
    _detectionTimer?.cancel();
    
    // Process camera frames at regular intervals - reduced interval for more responsive feedback
    _detectionTimer = Timer.periodic(Duration(milliseconds: 400), (timer) async {
      if (_controller == null || !_controller!.value.isInitialized || _processing) {
        return;
      }
      
      try {
        // Take a low resolution image for processing
        final xFile = await _controller!.takePicture();
        File imageFile = File(xFile.path);
        
        // Send to backend for face detection only (not recognition)
        Map<String, dynamic> response = await _apiService.checkFaceQuality(imageFile);
        
        if (mounted) {
          setState(() {
            _faceDetected = response['face_detected'] ?? false;
            _goodLighting = response['good_lighting'] ?? false;
            _qualityScore = (response['quality_score'] ?? 0.0) * 100;
            _lastDetectionResult = response;
            
            // Set specific feedback messages based on detection result
            if (!_faceDetected) {
              _statusMessage = 'No face detected';
              _qualityMessage = 'Position your face in the center of the frame';
            } else if (!_goodLighting) {
              _statusMessage = 'Face detected - Poor quality';
              
              // Get specific feedback from backend if available
              if (response['message'] != null && response['message'] != 'Face detection complete') {
                _qualityMessage = response['message'];
              } else if (_qualityScore < 30) {
                _qualityMessage = 'Very poor lighting conditions. Move to a brighter area';
              } else {
                _qualityMessage = 'Improve lighting or hold camera steady';
              }
            } else {
              _statusMessage = 'Face detected - Good quality';
              _qualityMessage = _qualityScore > 80 
                  ? 'Excellent quality! Ready to proceed' 
                  : 'Good quality - ready to proceed';
            }
            
            // Update face rectangle if detected
            if (_faceDetected && response['face_rect'] != null) {
              final rect = response['face_rect'];
              if (rect is List) {
                // Handle array format [left, top, right, bottom]
                _faceRect = Rect.fromLTRB(
                  rect[0].toDouble(),
                  rect[1].toDouble(), 
                  rect[2].toDouble(),
                  rect[3].toDouble()
                );
              } else if (rect is Map<String, dynamic>) {
                // Handle object format {x, y, width, height}
                _faceRect = Rect.fromLTWH(
                  rect['x']?.toDouble() ?? 0.0,
                  rect['y']?.toDouble() ?? 0.0,
                  rect['width']?.toDouble() ?? 0.0,
                  rect['height']?.toDouble() ?? 0.0,
                );
              } else {
                _faceRect = null;
              }
            } else {
              _faceRect = null;
            }
          });
        }
        
        // Clean up the temporary image file
        imageFile.delete().catchError((e) => print('Error deleting temp file: $e'));
      } catch (e) {
        debugPrint('Face detection error: $e');
        setState(() {
          _statusMessage = 'Detection error';
          _qualityMessage = 'Try again in a moment';
        });
      }
    });
  }
  
  @override
  void dispose() {
    _detectionTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _showErrorDialog(
    String title, 
    String message, {
    String? errorType,
    List<String>? suggestions,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // Choose icon based on error type
        IconData errorIcon = Icons.error;
        Color errorColor = Colors.red;
        
        if (errorType != null) {
          switch (errorType) {
            case 'face_detection_failed':
              errorIcon = Icons.face_retouching_off;
              break;
            case 'poor_quality':
              errorIcon = Icons.blur_on;
              errorColor = Colors.orange;
              break;
            case 'recognition_failed':
              errorIcon = Icons.person_off;
              break;
            case 'connection_error':
              errorIcon = Icons.signal_wifi_off;
              errorColor = Colors.orange;
              break;
            case 'timeout_error':
              errorIcon = Icons.timer_off;
              errorColor = Colors.orange;
              break;
            case 'invalid_input':
              errorIcon = Icons.warning_amber_rounded;
              errorColor = Colors.orange;
              break;
            default:
              errorIcon = Icons.error;
              break;
          }
        }
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(errorIcon, color: errorColor, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Suggestions container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            suggestions != null ? 'Suggestions:' : 'Tips for better recognition:',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, thickness: 1, color: Colors.black12),
                      const SizedBox(height: 8),
                      
                      // Custom or default suggestions
                      if (suggestions != null && suggestions.isNotEmpty) ...{
                        for (var suggestion in suggestions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    suggestion,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      } else ...{
                        const Text('• Ensure good lighting on your face', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('• Face should be clearly visible', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('• Hold camera steady to avoid blur', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('• Remove glasses/mask if possible', style: TextStyle(fontSize: 14)),
                      },
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
              child: const Text('Try Again'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<String> _promptForName(BuildContext context) async {
    String name = '';
    final TextEditingController controller = TextEditingController();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add, color: Colors.indigo, size: 24),
              SizedBox(width: 8),
              Text('Register New User'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please enter your name:'),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter your full name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                onChanged: (value) => name = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                name = controller.text.trim();
                Navigator.of(context).pop();
              },
              child: Text('Register'),
            ),
          ],
        );
      },
    );
    return name;
  }

  Future<String> _promptForStudentId(BuildContext context) async {
    String studentId = '';
    final TextEditingController controller = TextEditingController();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.badge, color: Colors.indigo, size: 24),
              SizedBox(width: 8),
              Text('Student ID Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please enter your Student ID:'),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter your student ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                onChanged: (value) => studentId = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                studentId = controller.text.trim();
                Navigator.of(context).pop();
              },
              child: Text('Continue'),
            ),
          ],
        );
      },
    );
    return studentId;
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.mode == CameraMode.register 
            ? 'Register Face' 
            : 'Mark Attendance'),
          backgroundColor: widget.mode == CameraMode.register 
            ? Colors.indigo 
            : Colors.blue,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing camera...'),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.mode == CameraMode.register 
          ? 'Register Face' 
          : 'Mark Attendance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          const ScanOverlay(),
          
          // Face detection feedback overlay
          if (_faceRect != null)
            Positioned.fill(
              child: CustomPaint(
                painter: FaceDetectionPainter(
                  faceRect: _faceRect!,
                  isGoodQuality: _faceDetected && _goodLighting,
                ),
              ),
            ),
          
          // Enhanced face detection status panel
          if (!_processing)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: !_faceDetected 
                          ? Colors.red.withOpacity(0.6) 
                          : !_goodLighting 
                              ? Colors.orange.withOpacity(0.7)
                              : Colors.green.withOpacity(0.7),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Status message
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            !_faceDetected 
                                ? Icons.face_retouching_off
                                : !_goodLighting 
                                    ? Icons.warning_amber_rounded 
                                    : Icons.check_circle_rounded,
                            color: !_faceDetected 
                                ? Colors.red 
                                : !_goodLighting 
                                    ? Colors.orange
                                    : Colors.green,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            _statusMessage,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      // Quality info and guidance message
                      if (_qualityMessage.isNotEmpty) ...[
                        SizedBox(height: 6),
                        Text(
                          _qualityMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                      
                      // Quality score indicator
                      if (_faceDetected) ...[
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: _qualityScore / 100,
                                  backgroundColor: Colors.grey.withOpacity(0.3),
                                  color: _qualityScore < 40 
                                      ? Colors.red
                                      : _qualityScore < 60
                                          ? Colors.orange
                                          : Colors.green,
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${_qualityScore.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (_processing)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          
          if (!_processing)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    Text(
                      widget.mode == CameraMode.register 
                        ? 'Tap to register your face' 
                        : 'Tap to mark attendance',
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _faceDetected && _goodLighting 
                          ? Colors.green 
                          : widget.mode == CameraMode.register ? Colors.indigo : Colors.blue,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(18),
                        elevation: 4,
                      ),
                      onPressed: _captureAndSend,
                      child: Icon(
                        _faceDetected && _goodLighting
                            ? Icons.camera_alt
                            : widget.mode == CameraMode.register 
                                ? Icons.person_add 
                                : Icons.check_circle,
                        size: 32, 
                        color: Colors.white
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}