import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';
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
  final dbWorking =
      await DatabaseHelper.instance.isDatabaseWorking();
  debugPrint(dbWorking
      ? '✅ DATABASE: Ready!'
      : '❌ DATABASE: Something went wrong!');

  runApp(const MediVoiceApp());
}

class MediVoiceApp extends StatelessWidget {
  const MediVoiceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MediVoice',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          // ── Core ──────────────────────────────────
          '/': (context) => const SplashScreen(),
          '/role-selection': (context) =>
              const RoleSelectionScreen(),

          // ── Patient ───────────────────────────────
          '/patient-register': (context) =>
              const PatientRegisterScreen(),
          '/patient-home': (context) =>
              const PatientHomeScreen(),

          // ── Caregiver ─────────────────────────────
          '/caregiver-profiles': (context) =>
              const CaregiverProfilesScreen(),
          '/add-patient': (context) =>
              const AddPatientScreen(),

          // ── Admin ─────────────────────────────────
          '/admin-login': (context) =>
              const AdminLoginScreen(),
        },
        // ── Routes that need arguments ───────────────
        // medication_list and add_medication use
        // Navigator.push with MaterialPageRoute
        // so they don't need named routes here
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => const RoleSelectionScreen(),
        ),
      );
}