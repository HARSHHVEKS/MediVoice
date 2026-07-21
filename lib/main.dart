import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/database/database_helper.dart';
import 'core/navigation/app_navigator.dart';
import 'core/services/notification_service.dart'; // ← NEW
import 'core/services/tts_service.dart'; // ← NEW
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/screens/admin_login_screen.dart';
import 'features/auth/screens/role_selection_screen.dart';
import 'features/caregiver/screens/add_patient_screen.dart';
import 'features/caregiver/screens/caregiver_profiles_screen.dart';
import 'features/patient/screens/patient_home_screen.dart';
import 'features/patient/screens/patient_register_screen.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize database on startup
  final dbWorking = await DatabaseHelper.instance.isDatabaseWorking();
  debugPrint(
      dbWorking ? '✅ DATABASE: Ready!' : '❌ DATABASE: Something went wrong!');

  // Initialize notifications ← NEW
  await NotificationService.instance.initialize();

  // Initialize text-to-speech (spoken reminders) ← NEW
  await TtsService.instance.initialize();

  // Load persisted theme preference ← NEW
  await ThemeController.instance.load();

  runApp(const MediVoiceApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService.instance.processPendingLaunchPayload();
  });
}

class MediVoiceApp extends StatelessWidget {
  const MediVoiceApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance.mode,
        builder: (context, themeMode, _) => MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'MediVoice',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/role-selection': (context) => const RoleSelectionScreen(),
            '/patient-register': (context) => const PatientRegisterScreen(),
            '/patient-home': (context) => const PatientHomeScreen(),
            '/caregiver-profiles': (context) =>
                const CaregiverProfilesScreen(),
            '/add-patient': (context) => const AddPatientScreen(),
            '/admin-login': (context) => const AdminLoginScreen(),
          },
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (_) => const RoleSelectionScreen(),
          ),
        ),
      );
}
