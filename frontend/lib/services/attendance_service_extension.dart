import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/attendance_api_service.dart';

extension AttendanceServiceExtension on AttendanceApiService {
  /// Get attendance records for a specific date
  Future<Map<String, dynamic>> getAttendanceRecords({String? date}) async {
    try {
      // Build the query URL with the date parameter if provided
      String url = '$baseUrl/api/logs/daily';
      if (date != null && date.isNotEmpty) {
        url += '?date=$date';
      }
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(receiveTimeout);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'records': responseData['records'] ?? [],
        };
      } else {
        debugPrint('Get attendance records failed with status code: ${response.statusCode}');
        
        // Try to parse error response if possible
        Map<String, dynamic> errorResponse = {};
        try {
          errorResponse = json.decode(response.body);
          errorResponse['success'] = false;
          return errorResponse;
        } catch (_) {
          return {
            'success': false,
            'message': 'Failed to load attendance records (HTTP ${response.statusCode})',
            'records': []
          };
        }
      }
    } catch (e) {
      debugPrint('Get attendance records error: $e');
      return {
        'success': false,
        'message': 'Error loading attendance records: $e',
        'records': []
      };
    }
  }
  
  /// Get monthly attendance statistics
  Future<Map<String, dynamic>> getMonthlyAttendance({required String month, required String year}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/logs/monthly?month=$month&year=$year'),
      ).timeout(receiveTimeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Get monthly attendance failed with status code: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to load monthly attendance',
          'data': {}
        };
      }
    } catch (e) {
      debugPrint('Get monthly attendance error: $e');
      return {
        'success': false,
        'message': 'Error: $e',
        'data': {}
      };
    }
  }

  /// Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dashboard/stats'),
      ).timeout(receiveTimeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Get dashboard stats failed with status code: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to load dashboard statistics',
          'stats': {}
        };
      }
    } catch (e) {
      debugPrint('Get dashboard stats error: $e');
      return {
        'success': false,
        'message': 'Error: $e',
        'stats': {}
      };
    }
  }
  
  /// Download attendance report
  Future<Map<String, dynamic>> downloadAttendanceReport({
    required String fromDate,
    required String toDate,
    String? format = 'pdf'
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/reports/download?from_date=$fromDate&to_date=$toDate&format=$format'),
      ).timeout(const Duration(seconds: 30)); // Longer timeout for report generation
      
      if (response.statusCode == 200) {
        // For binary data like PDF, we'd handle it differently in a real app
        // Here we'll just return a success status
        return {
          'success': true,
          'message': 'Report downloaded successfully',
          'contentType': response.headers['content-type'],
          'contentLength': response.contentLength,
        };
      } else {
        debugPrint('Report download failed with status code: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to download report',
        };
      }
    } catch (e) {
      debugPrint('Report download error: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
}