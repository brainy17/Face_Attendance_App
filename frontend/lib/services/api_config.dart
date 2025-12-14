import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Centralized API configuration used by the frontend to talk to the
/// enhanced backend server.
class ApiConfig {
  ApiConfig._();

  static late final String _defaultBaseUrl = _resolveDefaultBaseUrl();
  static String _baseUrl = _resolveDefaultBaseUrl();
  static bool _isInitialized = false;

  /// Default endpoint exposed by the enhanced backend server.
  static String get defaultBaseUrl => _defaultBaseUrl;

  /// Current API base URL. Call [initialize] before using in production code.
  static String get baseUrl => _baseUrl;

  /// Convenience getter used by legacy imports.
  static String getBaseUrl() => _baseUrl;

  /// Load the persisted API endpoint from shared preferences.
  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final storedUrl = prefs.getString('api_url');
      if (storedUrl != null && storedUrl.isNotEmpty) {
        _baseUrl = storedUrl;
        debugPrint('ApiConfig: Loaded persisted URL => $_baseUrl');
      } else {
        _baseUrl = _defaultBaseUrl;
        debugPrint('ApiConfig: Using default enhanced server URL => $_baseUrl');
      }
    } catch (e) {
      debugPrint('ApiConfig: Failed to load stored URL ($e). Falling back to default.');
      _baseUrl = _defaultBaseUrl;
    }

    _isInitialized = true;
  }

  /// Persist a custom endpoint for the API.
  static Future<bool> saveBaseUrl(String url) async {
    if (url.isEmpty) {
      return false;
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_url', url);
      _baseUrl = url;
      debugPrint('ApiConfig: Updated API URL => $_baseUrl');
      return true;
    } catch (e) {
      debugPrint('ApiConfig: Error saving API URL ($e)');
      return false;
    }
  }

  /// Reset the endpoint to the enhanced server default.
  static Future<bool> resetToDefault() async {
    return await saveBaseUrl(_defaultBaseUrl);
  }

  static String _resolveDefaultBaseUrl() {
    const int enhancedServerPort = BackendConfig.port;
    const String pcLanIp = BackendConfig.pcLanIp;

    if (kIsWeb) {
      // When running in a browser we assume the backend is reachable via localhost.
      return 'http://${BackendConfig.localhostIp}:$enhancedServerPort';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Physical Android device: use PC's LAN IP (both on same WiFi network)
        // Android emulator would use: http://10.0.2.2:$enhancedServerPort
        return 'http://$pcLanIp:$enhancedServerPort';
      case TargetPlatform.iOS:
        return 'http://${BackendConfig.localhostIp}:$enhancedServerPort';
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://${BackendConfig.localhostIp}:$enhancedServerPort';
    }
  }
}

/// Backwards compatibility helper for older imports.
String getBaseUrl() => ApiConfig.getBaseUrl();