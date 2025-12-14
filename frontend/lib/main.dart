import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:permission_handler/permission_handler.dart'; // Temporarily disabled
import 'screens/modern_home_screen.dart';
import 'services/api_config.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the persisted backend endpoint before the UI boots.
  await ApiConfig.initialize();
  
  // Force portrait orientation (not applicable on web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Request camera permission (not needed for web)
    // await Permission.camera.request(); // Temporarily disabled
  }
  
  runApp(const FaceAttendanceApp());
}

class FaceAttendanceApp extends StatelessWidget {
  const FaceAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Attendance',
      theme: AppTheme.light,
      home: const ModernHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}