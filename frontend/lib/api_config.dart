import 'services/api_config.dart' show ApiConfig;

export 'services/api_config.dart' show ApiConfig, getBaseUrl;

/// Helper to access the default enhanced server URL from legacy code.
String getDefaultApiUrl() => ApiConfig.defaultBaseUrl;