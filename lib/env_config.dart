import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  /// Load .env values before app startup.
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String getBaseUrl() {
    return dotenv.env['APP_BASE_URL']?.trim() ?? 'https://namsor-99e7d.web.app';
  }

  static String getApiUrl() {
    return dotenv.env['API_BASE_URL']?.trim() ?? 'https://api.namsor-99e7d.web.app';
  }

  static String getFlutterWebRenderer() {
    return dotenv.env['FLUTTER_WEB_RENDERER']?.trim() ?? 'canvaskit';
  }

  static String getFirebaseProject() {
    return dotenv.env['FIREBASE_PROJECT']?.trim() ?? 'namsor-99e7d';
  }
}
