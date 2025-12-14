import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'backend_connector.dart';

class SimpleFaceApiService {
  // Use BackendConnector for API URLs
  final BackendConnector _connector = BackendConnector();
  
  // Get base URL from api_config.dart for backward compatibility
  String baseUrl = getBaseUrl();
  
  // Singleton pattern
  static final SimpleFaceApiService _instance = SimpleFaceApiService._internal();
  
  factory SimpleFaceApiService() {
    return _instance;
  }
  
  SimpleFaceApiService._internal() {
    // Initialize the connection
    _connector.initialize();
  }
  
  // Update server URL
  void updateBaseUrl(String newUrl) {
    baseUrl = newUrl;
    debugPrint('API Service: URL updated to $baseUrl');
  }
  
  // Initialize the service and check the connection
  Future<void> initialize() async {
    debugPrint('Initializing Simple Face API Service...');
    // Use the BackendConnector for initialization
    final connected = await _connector.initialize();
    
    if (connected) {
      debugPrint('✅ Connected to Simple Face Server');
    } else {
      debugPrint('⚠️ Failed to connect to server');
    }
  }

  // Check server connection
  Future<bool> checkConnection() async {
    // Use the BackendConnector for connection checks
    return await _connector.checkConnection();
  }
  
  // Get all registered students
  Future<Map<String, dynamic>> getStudents() async {
    try {
      final endpoint = _connector.getApiUrl('/api/students');
      final response = await http.get(
        Uri.parse(endpoint),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Failed to load students: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to load students',
          'students': []
        };
      }
    } catch (e) {
      debugPrint('Error getting students: $e');
      return {
        'success': false,
        'message': 'Error: $e',
        'students': []
      };
    }
  }
  
  // Register a new student
  Future<Map<String, dynamic>> registerStudent({
    required File imageFile,
    required String studentId,
    required String name,
    String? course,  // Changed className to course
  }) async {
    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(_connector.getApiUrl('/api/register'))
      );
      
      // Add text fields
      request.fields['student_id'] = studentId;
      request.fields['name'] = name;
      if (course != null) {
        request.fields['course'] = course;  // Changed class to course
      }
      
      // Add file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      
      debugPrint('Sending registration for $name (ID: $studentId)');
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Failed to register: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return {
          'success': false,
          'message': 'Registration failed: ${response.body}',
        };
      }
    } catch (e) {
      debugPrint('Error registering student: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
  
  // Mark attendance
  Future<Map<String, dynamic>> markAttendance({
    required File imageFile,
    String? studentId,  // Optional studentId parameter
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_connector.getApiUrl('/api/attendance')),
      );

      if (studentId != null) {
        request.fields['student_id'] = studentId;
      }

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: 'attendance_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      debugPrint('Sending attendance photo');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      Map<String, dynamic> body = {};
      if (response.body.isNotEmpty) {
        try {
          body = json.decode(response.body) as Map<String, dynamic>;
        } catch (decodeError) {
          debugPrint('Failed to parse attendance response: $decodeError');
        }
      }

      if (response.statusCode == 200) {
        return body.isNotEmpty
            ? body
            : {
                'success': true,
                'message': 'Attendance marked successfully.',
              };
      }

      debugPrint('Failed to mark attendance: ${response.statusCode}');
      debugPrint('Response: ${response.body}');

      final message = body['message']?.toString().isNotEmpty == true
          ? body['message'].toString()
          : 'Failed to mark attendance';

      return {
        'success': false,
        'message': message,
        'error_type': body['error_type']?.toString(),
        'status_code': response.statusCode,
      };
    } catch (e) {
      debugPrint('Error marking attendance: $e');
      return {
        'success': false,
        'message': 'Unable to contact the server. Please try again.',
        'error_type': 'network_error',
      };
    }
  }
  
  // Get attendance logs
  Future<Map<String, dynamic>> getAttendanceLogs({
    String? dateFrom,
    String? dateTo,
    String? studentId,
    String? startDate,  // Added startDate parameter
  }) async {
    try {
      // Build query parameters
      Map<String, String> queryParams = {};
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;
      if (studentId != null) queryParams['student_id'] = studentId;
      if (startDate != null) queryParams['start_date'] = startDate;
      
      final uri = Uri.parse(_connector.getApiUrl('/api/attendance')).replace(
        queryParameters: queryParams
      );
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Failed to load logs: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to load attendance logs',
          'records': []
        };
      }
    } catch (e) {
      debugPrint('Error getting logs: $e');
      return {
        'success': false,
        'message': 'Error: $e',
        'records': []
      };
    }
  }
  
  // Delete a student
  Future<Map<String, dynamic>> deleteStudent(String studentId) async {
    try {
      final response = await http.delete(
        Uri.parse(_connector.getApiUrl('/api/students/$studentId')),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Failed to delete student: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to delete student',
        };
      }
    } catch (e) {
      debugPrint('Error deleting student: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
  
  // Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse(_connector.getApiUrl('/api/dashboard/stats')),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Failed to get dashboard stats: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to get dashboard statistics',
          'stats': {
            'students_count': 0,
            'today_attendance': 0,
            'attendance_rate': 0,
          }
        };
      }
    } catch (e) {
      debugPrint('Error getting dashboard stats: $e');
      return {
        'success': false,
        'message': 'Error: $e',
        'stats': {
          'students_count': 0,
          'today_attendance': 0,
          'attendance_rate': 0,
        }
      };
    }
  }
  
  // Finalize attendance for a specific date
  Future<Map<String, dynamic>> finalizeAttendance({String? attendanceDate}) async {
    try {
      final queryParams = attendanceDate != null 
          ? {'attendance_date': attendanceDate} 
          : <String, String>{};
      
      final uri = Uri.parse(_connector.getApiUrl('/api/attendance/finalize')).replace(
        queryParameters: queryParams,
      );
      
      final response = await http.post(uri);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Failed to finalize attendance: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to finalize attendance',
        };
      }
    } catch (e) {
      debugPrint('Error finalizing attendance: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
}