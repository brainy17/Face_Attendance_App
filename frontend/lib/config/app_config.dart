
class BackendConfig {
  const BackendConfig();
  
 
  static const int port = 8001;
  
  
  static const String pcLanIp = 'localhost';
  
  
  static const String localhostIp = 'localhost';
  
  
  static const String emulatorGateway = '10.0.2.2';
}


class AppMetadata {
  const AppMetadata();
  
  static const String appName = 'Face Attendance';
  static const String appVersion = '1.0.0';
  static const String appBuild = '1';
}


class CameraConfig {
  const CameraConfig();
  
  
  static const double minRecognitionConfidence = 0.5;
  
  
  static const int cameraWidth = 1280;
  
  /// Camera resolution height
  static const int cameraHeight = 720;
}

// Timeout settings
class TimeoutConfig {
  const TimeoutConfig();
  
  /// Network request timeout in seconds
  static const int networkTimeout = 30;
  
  /// Face detection timeout in seconds
  static const int faceDetectionTimeout = 10;
}

class AppConfig {
  const AppConfig();
  
  // Static instances for convenience
  static const backendConfig = BackendConfig();
  static const appMetadata = AppMetadata();
  static const cameraConfig = CameraConfig();
  static const timeoutConfig = TimeoutConfig();
}
