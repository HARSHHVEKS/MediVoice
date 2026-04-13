import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../database/db_constants.dart';

class AuthService {
  // ── Singleton ────────────────────────────────────────────
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  // ── Database reference ───────────────────────────────────
  final _db = DatabaseHelper.instance;

  // ══════════════════════════════════════════════════════
  // SECURITY — Hashing
  // ══════════════════════════════════════════════════════

  String _hashInput(String input) {
    const salt = 'MediVoice_Kawempe_2026';
    final bytes = utf8.encode(salt + input);
    return sha256.convert(bytes).toString();
  }

  // Public version — used by patient_pin_screen.dart
  String hashInputPublic(String input) => _hashInput(input);

  // ══════════════════════════════════════════════════════
  // CAREGIVER — Register & Login
  // ══════════════════════════════════════════════════════

  Future<AuthResult> registerCaregiver({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      if (fullName.trim().isEmpty) {
        return AuthResult.failure('Please enter your full name');
      }
      if (!_isValidEmail(email)) {
        return AuthResult.failure('Please enter a valid email address');
      }
      if (password.length < 6) {
        return AuthResult.failure('Password must be at least 6 characters');
      }

      final existing = await _db.getUserByEmail(email.trim().toLowerCase());
      if (existing != null) {
        return AuthResult.failure('An account with this email already exists');
      }

      final passwordHash = _hashInput(password);
      final now = DateTime.now().toIso8601String();

      final userId = await _db.insertUser({
        DBConstants.userFullName: fullName.trim(),
        DBConstants.userEmail: email.trim().toLowerCase(),
        DBConstants.userPasswordHash: passwordHash,
        DBConstants.userPhone: phone?.trim(),
        DBConstants.userRole: DBConstants.roleCaregiver,
        DBConstants.userLanguage: 'en',
        DBConstants.userIsLoggedIn: 0,
        DBConstants.userIsActive: 1,
        DBConstants.userCreatedAt: now,
        DBConstants.userUpdatedAt: now,
      });

      await _saveSession(userId, DBConstants.roleCaregiver);

      return AuthResult.success(
        message: 'Account created successfully',
        userId: userId,
        role: DBConstants.roleCaregiver,
      );
    } catch (e) {
      return AuthResult.failure('Registration failed. Please try again.');
    }
  }

  Future<AuthResult> loginCaregiver({
    required String email,
    required String password,
  }) async {
    try {
      if (email.trim().isEmpty || password.isEmpty) {
        return AuthResult.failure('Please enter email and password');
      }

      final user = await _db.getUserByEmail(email.trim().toLowerCase());
      if (user == null) {
        return AuthResult.failure('No account found with this email');
      }

      if (user[DBConstants.userIsActive] == 0) {
        return AuthResult.failure('This account has been deactivated');
      }

      if (user[DBConstants.userRole] != DBConstants.roleCaregiver) {
        return AuthResult.failure('This account is not a caregiver account');
      }

      final inputHash = _hashInput(password);
      if (inputHash != user[DBConstants.userPasswordHash]) {
        return AuthResult.failure('Incorrect password. Please try again.');
      }

      final userId = user[DBConstants.userId] as int;
      await _saveSession(userId, DBConstants.roleCaregiver);
      await _db.setUserLoggedIn(userId, true);

      return AuthResult.success(
        message: 'Welcome back, ${user[DBConstants.userFullName]}!',
        userId: userId,
        role: DBConstants.roleCaregiver,
        userName: user[DBConstants.userFullName] as String,
      );
    } catch (e) {
      return AuthResult.failure('Login failed. Please try again.');
    }
  }

  // ══════════════════════════════════════════════════════
// PATIENT — Self Registration
// Patient creates their own account
// OR caregiver creates it for them
// ══════════════════════════════════════════════════════

Future<AuthResult> registerPatient({
  required String fullName,
  required String pin,
  required String alertPhone,
  int? age,
  String? gender,
  String language = 'lg',
  bool isCaregiverManaged = false,
  int? caregiverId,
}) async {
  try {
    // Validate name
    if (fullName.trim().isEmpty) {
      return AuthResult.failure('Please enter patient name');
    }

    // Validate PIN
    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      return AuthResult.failure('PIN must be exactly 4 digits');
    }

    // Validate alert phone
    if (alertPhone.trim().isEmpty) {
      return AuthResult.failure('Please enter an alert phone number');
    }

    // Hash PIN before saving — never plain text
    final pinHash = _hashInput(pin);
    final now = DateTime.now().toIso8601String();

    // Save to patients table
    final patientId = await _db.insertPatient({
      DBConstants.patientFullName:    fullName.trim(),
      DBConstants.patientAge:         age,
      DBConstants.patientGender:      gender,
      DBConstants.patientLanguage:    language,
      DBConstants.patientPinHash:     pinHash,
      DBConstants.patientAlertPhone:  alertPhone.trim(),
      DBConstants.patientIsCaregiver: isCaregiverManaged ? 1 : 0,
      DBConstants.patientCaregiverId: caregiverId,
      DBConstants.patientIsActive:    1,
      DBConstants.patientCreatedAt:   now,
      DBConstants.patientUpdatedAt:   now,
    });

    debugPrint('✅ PATIENT REGISTERED: $fullName (ID: $patientId)');

    // Save session immediately after register
    await _savePatientSession(patientId);

    return AuthResult.success(
      message: 'Profile created successfully!',
      userId: patientId,
      role: DBConstants.rolePatient,
      userName: fullName.trim(),
    );
  } catch (e) {
    debugPrint('❌ PATIENT REGISTER ERROR: $e');
    return AuthResult.failure('Registration failed. Please try again.');
  }
}

// Verify patient PIN
Future<AuthResult> loginPatient(String pin) async {
  try {
    if (pin.length != 4) {
      return AuthResult.failure('PIN must be 4 digits');
    }

    // Get all active patients
    final db = await _db.database;
    final patients = await db.query(
      DBConstants.tablePatients,
      where: '${DBConstants.patientIsActive} = 1',
    );

    if (patients.isEmpty) {
      return AuthResult.failure(
        'No profile found.\nPlease register first.',
      );
    }

    // Check PIN against patients
    final inputHash = _hashInput(pin);
    for (final patient in patients) {
      if (patient[DBConstants.patientPinHash] == inputHash) {
        final patientId = patient[DBConstants.patientId]! as int;
        final name = patient[DBConstants.patientFullName]! as String;

        // Save session
        await _savePatientSession(patientId);

        debugPrint('✅ PATIENT LOGIN: $name');

        return AuthResult.success(
          message: 'Welcome, $name!',
          userId: patientId,
          role: DBConstants.rolePatient,
          userName: name,
        );
      }
    }

    return AuthResult.failure('Wrong PIN. Please try again.');
  } catch (e) {
    debugPrint('❌ PATIENT LOGIN ERROR: $e');
    return AuthResult.failure('Login failed. Please try again.');
  }
}

// Save patient session
Future<void> _savePatientSession(int patientId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('session_user_id', patientId);
  await prefs.setString('session_user_role', DBConstants.rolePatient);
  await prefs.setBool('is_logged_in', true);
  await prefs.setInt('patient_id', patientId);
}

// Public version for external use
Future<void> savePatientSession(int patientId) async {
  await _savePatientSession(patientId);
}

  // ══════════════════════════════════════════════════════
  // PATIENT — PIN Setup & Verification
  // ══════════════════════════════════════════════════════

  Future<AuthResult> setPatientPin({
    required int userId,
    required String pin,
  }) async {
    try {
      if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
        return AuthResult.failure('PIN must be exactly 4 numbers');
      }

      final pinHash = _hashInput(pin);
      await _db.updateUser(userId, {
        DBConstants.userPinHash: pinHash,
      });

      return AuthResult.success(message: 'PIN set successfully');
    } catch (e) {
      return AuthResult.failure('Failed to set PIN. Please try again.');
    }
  }

  Future<AuthResult> verifyPatientPin({
    required int userId,
    required String pin,
  }) async {
    try {
      final user = await _db.getUserById(userId);
      if (user == null) {
        return AuthResult.failure('Patient not found');
      }

      final inputHash = _hashInput(pin);
      if (inputHash != user[DBConstants.userPinHash]) {
        return AuthResult.failure('Wrong PIN. Please try again.');
      }

      await _saveSession(userId, DBConstants.rolePatient);

      return AuthResult.success(
        message: 'PIN correct',
        userId: userId,
        role: DBConstants.rolePatient,
        userName: user[DBConstants.userFullName] as String,
      );
    } catch (e) {
      return AuthResult.failure('Verification failed. Please try again.');
    }
  }

  // ══════════════════════════════════════════════════════
  // ADMIN — PIN Verification
  // ══════════════════════════════════════════════════════

  Future<AuthResult> verifyAdminPin(String pin) async {
    try {
      if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
        return AuthResult.failure('Admin PIN must be 6 digits');
      }

      final storedPin = await _db.getSetting(DBConstants.keyAdminPin);
      if (storedPin == null) {
        return AuthResult.failure('Admin PIN not configured');
      }

      if (pin != storedPin) {
        return AuthResult.failure('Incorrect admin PIN');
      }

      await _saveSession(0, DBConstants.roleAdmin);

      return AuthResult.success(
        message: 'Admin access granted',
        userId: 0,
        role: DBConstants.roleAdmin,
      );
    } catch (e) {
      return AuthResult.failure('Verification failed. Please try again.');
    }
  }

  Future<AuthResult> changeAdminPin({
    required String currentPin,
    required String newPin,
  }) async {
    try {
      final verify = await verifyAdminPin(currentPin);
      if (!verify.success) {
        return AuthResult.failure('Current PIN is incorrect');
      }

      if (newPin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(newPin)) {
        return AuthResult.failure('New PIN must be 6 digits');
      }

      await _db.setSetting(DBConstants.keyAdminPin, newPin);
      return AuthResult.success(message: 'Admin PIN changed successfully');
    } catch (e) {
      return AuthResult.failure('Failed to change PIN. Please try again.');
    }
  }

  // ══════════════════════════════════════════════════════
  // SESSION MANAGEMENT
  // ══════════════════════════════════════════════════════

  Future<void> _saveSession(int userId, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('session_user_id', userId);
    await prefs.setString('session_user_role', role);
    await prefs.setBool('is_logged_in', true);
  }

  Future<int?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    if (!isLoggedIn) return null;
    return prefs.getInt('session_user_id');
  }

  Future<String?> getCurrentUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    if (!isLoggedIn) return null;
    return prefs.getString('session_user_role');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('session_user_id');

    if (userId != null && userId != 0) {
      await _db.setUserLoggedIn(userId, false);
    }

    await prefs.remove('session_user_id');
    await prefs.remove('session_user_role');
    await prefs.setBool('is_logged_in', false);
  }

  // ══════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════

  bool _isValidEmail(String email) => RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  ).hasMatch(email.trim());

} // ← AuthService ends here

// ══════════════════════════════════════════════════════════
// AuthResult — Clean result object
// ══════════════════════════════════════════════════════════

class AuthResult {

  AuthResult._({
    required this.success,
    required this.message,
    this.userId,
    this.role,
    this.userName,
  });

  factory AuthResult.success({
    required String message,
    int? userId,
    String? role,
    String? userName,
  }) {
    return AuthResult._(
      success: true,
      message: message,
      userId: userId,
      role: role,
      userName: userName,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(
      success: false,
      message: message,
    );
  }
  final bool success;
  final String message;
  final int? userId;
  final String? role;
  final String? userName;

  @override
  String toString() => 'AuthResult(success: $success, '
      'message: $message, userId: $userId, role: $role)';

} // ← AuthResult ends here