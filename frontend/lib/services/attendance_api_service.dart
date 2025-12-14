/*
 * Enhanced Attendance API Service for Face Recognition Application
 * This service handles all interactions with the backend API for face recognition
 * and attendance management functions.
 */

import 'dart:convert';
import 'dart:io';
import 'dart:async';  // Added for TimeoutException
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../api_config.dart'; // Import to use the getBaseUrl function

enum FaceRecognitionError {
  connectionError,
  serverError,
  noFaceDetected,
  badLighting,
  faceNotRecognized,
  alreadyMarked,
  noStudentsRegistered,
  invalidImage,
}

/// Service for interacting with the face recognition API
class AttendanceApiService {
  final String baseUrl;
  final Duration connectTimeout;
  final Duration sendTimeout;
  final Duration receiveTimeout;
  
  /// Creates a new AttendanceApiService instance with configurable timeouts.
  /// 
  /// The [baseUrl] parameter should include the protocol and host, e.g. 'http://192.168.1.100:8001'.
  /// [connectTimeout]: Time to establish a connection (default: 5 seconds)
  /// [sendTimeout]: Time to send a request (default: 10 seconds)
  /// [receiveTimeout]: Time to receive a response (default: 15 seconds)
  AttendanceApiService({
    String? baseUrl,
    this.connectTimeout = const Duration(seconds: 5),
    this.sendTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 15),
  }) : this.baseUrl = baseUrl ?? getBaseUrl();
  
  /// Check if the backend server is running.
  /// 
  /// Returns true if the server is reachable and responds with a 200 status code.
  Future<bool> checkServerConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
      ).timeout(connectTimeout);
      
      return response.statusCode == 200;
    } on SocketException catch (e) {
      debugPrint('Connection error: ${e.message}');
      return false;
    } on TimeoutException catch (e) {
      debugPrint('Connection timeout: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Server connection error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> checkFaceQuality(File imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/check_face'));
      
      // Determine the correct MIME type from the file extension
      final mimeType = 'image/${path.extension(imageFile.path).replaceAll('.', '')}';
      
      // Add the image file to the request
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType.parse(mimeType),
      ));
      
      // Send the request with timeout
      final streamedResponse = await request.send().timeout(sendTimeout);
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(receiveTimeout);
      
      if (response.statusCode == 200) {
        // Parse the JSON response
        return json.decode(response.body);
      } else {
        debugPrint('Face quality check failed with status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        
        return {
          'face_detected': false,
          'good_lighting': false,
          'message': 'Server error: HTTP ${response.statusCode}',
          'error_type': 'server_error',
        };
      }
    } on SocketException catch (e) {
      debugPrint('Face quality check connection error: ${e.message}');
      return {
        'face_detected': false,
        'good_lighting': false,
        'message': 'Connection error: Unable to reach server. Check your network connection.',
        'error_type': 'connection_error',
      };
    } on TimeoutException catch (e) {
      debugPrint('Face quality check timeout: ${e.message}');
      return {
        'face_detected': false,
        'good_lighting': false,
        'message': 'Request timed out. Server may be overloaded or unreachable.',
        'error_type': 'timeout_error',
      };
    } catch (e) {
      debugPrint('Face quality check error: $e');
      return {
        'face_detected': false,
        'good_lighting': false,
        'message': 'An unexpected error occurred: $e',
        'error_type': 'unknown_error',
      };
    }
  }
  
  /// Register a new student with face recognition.
  Future<Map<String, dynamic>> registerStudent({
    required File imageFile,
    required String studentId,
    required String name,
    String? email,
    String? classSection,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/register'));
      
      // Add face image
      final mimeType = 'image/${path.extension(imageFile.path).replaceAll('.', '')}';
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType.parse(mimeType),
      ));
      
      // Add student information
      request.fields['student_id'] = studentId;
      request.fields['name'] = name;
      if (email != null) request.fields['email'] = email;
      if (classSection != null) request.fields['class'] = classSection;
      
      final streamedResponse = await request.send().timeout(sendTimeout);
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(receiveTimeout);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        debugPrint('Student registration failed with status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        
        // Try to parse error response if possible
        Map<String, dynamic> errorResponse = {};
        try {
          errorResponse = json.decode(response.body);
        } catch (_) {
          errorResponse = {
            'success': false,
            'message': 'Server error: HTTP ${response.statusCode}',
            'error_type': 'server_error'
          };
        }
        
        return errorResponse;
      }
    } on SocketException catch (e) {
      debugPrint('Registration connection error: ${e.message}');
      return {
        'success': false,
        'message': 'Connection error: Unable to reach server. Check your network connection.',
        'error_type': 'connection_error'
      };
    } on TimeoutException catch (e) {
      debugPrint('Registration timeout: ${e.message}');
      return {
        'success': false,
        'message': 'Request timed out. Server may be overloaded or unreachable.',
        'error_type': 'timeout_error'
      };
    } catch (e) {
      debugPrint('Registration error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
        'error_type': 'unknown_error'
      };
    }
  }
  
  /// Mark attendance using face recognition.
  Future<Map<String, dynamic>> markAttendance(File imageFile) async {
    try {
      // Check if image file exists
      if (!imageFile.existsSync()) {
        return {
          'success': false,
          'message': 'Image file not found or inaccessible',
          'error_type': 'invalid_image'
        };
      }
      
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/attendance'));
      
      // Add face image
      final mimeType = 'image/${path.extension(imageFile.path).replaceAll('.', '')}';
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType.parse(mimeType),
      ));
      
      final streamedResponse = await request.send().timeout(sendTimeout);
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(receiveTimeout);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        debugPrint('Attendance marking failed with status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        
        // Try to parse error response if possible
        Map<String, dynamic> errorResponse = {};
        try {
          errorResponse = json.decode(response.body);
        } catch (_) {
          errorResponse = {
            'success': false,
            'message': 'Server error: HTTP ${response.statusCode}',
            'error_type': 'server_error'
          };
        }
        
        return errorResponse;
      }
    } on SocketException catch (e) {
      debugPrint('Attendance marking connection error: ${e.message}');
      return {
        'success': false,
        'message': 'Connection error: Unable to reach server. Check your network connection.',
        'error_type': 'connection_error'
      };
    } on TimeoutException catch (e) {
      debugPrint('Attendance marking timeout: ${e.message}');
      return {
        'success': false,
        'message': 'Request timed out. Server may be overloaded or unreachable.',
        'error_type': 'timeout_error'
      };
    } on FileSystemException catch (e) {
      debugPrint('Attendance marking file error: ${e.message}');
      return {
        'success': false,
        'message': 'Failed to access image file: ${e.message}',
        'error_type': 'invalid_image'
      };
    } catch (e) {
      debugPrint('Attendance marking error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
        'error_type': 'unknown_error'
      };
    }
  }
  
  /// Get all registered students.
  Future<List<Map<String, dynamic>>> getAllStudents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/students'),
      ).timeout(receiveTimeout);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['students'] != null) {
          final List<dynamic> students = responseData['students'];
          return students.map((item) => item as Map<String, dynamic>).toList();
        }
        return [];
      } else {
        debugPrint('Get students failed with status code: ${response.statusCode}');
        return [];
      }
    } on SocketException catch (e) {
      debugPrint('Get students connection error: ${e.message}');
      return [];
    } on TimeoutException catch (e) {
      debugPrint('Get students timeout: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Get students error: $e');
      return [];
    }
  }
}