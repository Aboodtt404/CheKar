class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
  static const String apiPrefix = '/api/v1';
  static const Duration timeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(seconds: 60);
  static const Duration pollInterval = Duration(seconds: 3);
}
