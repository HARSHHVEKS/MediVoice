import 'package:flutter/material.dart';

class AppColors {
  // Primary Blues
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF003C8F);
  static const Color primaryLight = Color(0xFF5E92F3);

  // Status Colors
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color warningOrange = Color(0xFFE65100);
  static const Color dangerRed = Color(0xFFC62828);

  // Background & Text
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);

  // Admin Dark Theme
  static const Color adminNavy = Color(0xFF0A1628);

  // Dark Theme surfaces
  static const Color darkBackground = Color(0xFF0E1420);
  static const Color darkSurface = Color(0xFF17202E);
  static const Color darkSurfaceAlt = Color(0xFF1F2A3A);
  static const Color darkTextPrimary = Color(0xFFECEFF4);
  static const Color darkTextSecondary = Color(0xFF9AA5B5);

  // Pill Colors
  static const Color pillRed = Color(0xFFEF5350);
  static const Color pillBlue = Color(0xFF42A5F5);
  static const Color pillGreen = Color(0xFF66BB6A);
  static const Color pillYellow = Color(0xFFFFD700);
  static const Color pillOrange = Color(0xFFFFA726);
  static const Color pillPurple = Color(0xFFAB47BC);
  static const Color pillPink = Color(0xFFEC407A);
  static const Color pillWhite = Color(0xFFEEEEEE);
  static const Color pillBrown = Color(0xFF8D6E63);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryBlue, primaryDark],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
  );

  static const LinearGradient redGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC62828), Color(0xFF7F0000)],
  );

  // Patient-facing green gradient (was hardcoded across screens)
  static const Color patientGreenLight = Color(0xFF43A047);
  static const Color patientGreenMid = Color(0xFF2E7D32);
  static const Color patientGreenDark = Color(0xFF1B5E20);

  static const LinearGradient patientGreenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [patientGreenLight, patientGreenMid],
  );

  static const LinearGradient patientGreenGradientDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [patientGreenLight, patientGreenMid, patientGreenDark],
  );
}