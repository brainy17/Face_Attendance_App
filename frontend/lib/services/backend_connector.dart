import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';

class BackendConnector {
  static final BackendConnector _instance = BackendConnector._internal();
  
  factory BackendConnector() {
    return _instance;
  }
  
  BackendConnector._internal();
  
  // Status variables
  bool _isInitialized = false;
  bool _isConnected = false;
  String _serverStatus = "Unknown";
  String _serverVersion = "Unknown";
  
  // Getters
  bool get isConnected => _isConnected;
  String get serverStatus => _serverStatus;
  String get serverVersion => _serverVersion;
  
  // Initialize connection to backend
  Future<bool> initialize() async {
    if (_isInitialized) return _isConnected;
    
    try {
      final result = await checkConnection();
      _isInitialized = true;
      _isConnected = result;
      return result;
    } catch (e) {
      debugPrint('⚠️ Error initializing backend connection: $e');
      _isInitialized = true;
      _isConnected = false;
      return false;
    }
  }
  
  // Check server connection
  Future<bool> checkConnection() async {
    try {
      final baseUrl = getBaseUrl();
      final endpoint = '${baseUrl}/api/health';
      
      debugPrint('🔄 Checking connection to: $endpoint');
      
      final response = await http.get(
        Uri.parse(endpoint),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          _serverStatus = data['message'] ?? 'OK';
          _serverVersion = data['version'] ?? 'Unknown';
        } catch (e) {
          debugPrint('⚠️ Failed to parse server response: $e');
        }
        
        _isConnected = true;
        debugPrint('✅ Connected to backend server');
        return true;
      } else {
        _isConnected = false;
        debugPrint('❌ Failed to connect to backend: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _isConnected = false;
      debugPrint('❌ Connection error: $e');
      return false;
    }
  }
  
  // Provides the correct URL for API requests based on platform
  String getApiUrl(String endpoint) {
    final baseUrl = getBaseUrl();
    
    // Ensure endpoint always starts with "/"
    String normalizedEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    
    // Make sure we're preserving the /api prefix in the endpoint if needed
    if (!normalizedEndpoint.contains('/api') && !normalizedEndpoint.contains('/health')) {
      normalizedEndpoint = '/api$normalizedEndpoint';
    }
    
    // Use full URL for all platforms including web now
    return '$baseUrl$normalizedEndpoint';
  }
}