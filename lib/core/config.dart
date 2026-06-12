/// Build-time configuration.
///
/// The API base URL is injected with --dart-define so the same code serves
/// both flavors:
///   dev:  flutter run --dart-define=API_BASE_URL=http://localhost:8000
///   prod: flutter run --dart-define=API_BASE_URL=https://csgcip.onrender.com
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://csgcip.onrender.com',
  );

  /// Web app origin — used to recognize invite deep links
  /// (`https://<webOrigin>/jam/:id/participate`) and to build share links that
  /// work for recipients without the app installed.
  static const String webOrigin = String.fromEnvironment(
    'WEB_ORIGIN',
    defaultValue: 'https://crowdsmart.ai',
  );
}
