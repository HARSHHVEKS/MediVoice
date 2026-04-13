// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_constants.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({Key? key}) : super(key: key);

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  // ── State ────────────────────────────────────────────────
  Map<String, dynamic>? _patient;
  List<Map<String, dynamic>> _medications = [];
  bool _isLoading = true;

  // ── Database ─────────────────────────────────────────────
  final _db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  // ── Load patient + medicines ─────────────────────────────
  Future<void> _loadPatientData() async {
    try {
      setState(() => _isLoading = true);

      // Get current patient ID
      final patientId = await _db.getCurrentPatientId();
      if (patientId == null) {
        if (!mounted) return;
        // No patient set — go back to role selection
        Navigator.pushReplacementNamed(context, '/role-selection');
        return;
      }

      // Load patient profile
      final patient = await _db.getPatientById(patientId);
      if (patient == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/role-selection');
        return;
      }

      // Load medications
      final meds = await _db.getMedicationsByPatient(patientId);

      if (!mounted) return;
      setState(() {
        _patient = patient;
        _medications = meds;
        _isLoading = false;
      });

      debugPrint('✅ PATIENT HOME: Loaded ${meds.length} medications');
    } catch (e) {
      debugPrint('❌ PATIENT HOME ERROR: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.successGreen,
          ),
        ),
      );
    }

    final name = _patient?[DBConstants.patientFullName] ?? 'Patient';
    final initial = name.substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────
            _buildHeader(name, initial),

            // ── Content ─────────────────────────────────
            Expanded(
              child: _medications.isEmpty
                  ? _buildNoMedicines()
                  : _buildMedicineList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader(String name, String initial) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF43A047),
            Color(0xFF2E7D32),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 2,
                ),
                image: _patient?[DBConstants.patientPhoto] != null
                    ? DecorationImage(
                        image: FileImage(
                          File(_patient![DBConstants.patientPhoto] as String),
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _patient?[DBConstants.patientPhoto] == null
                  ? Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),

              const SizedBox(width: AppDimensions.md),

              // Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Back to role selection
              IconButton(
                icon: Icon(
                  Icons.logout,
                  color: Colors.white.withOpacity(0.8),
                ),
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    '/role-selection',
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.lg),

          // Today's date
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  _getTodayDate(),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── No medicines yet ─────────────────────────────────────
  Widget _buildNoMedicines() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.medication_outlined,
                size: 52,
                color: AppColors.successGreen,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            const Text(
              'No Medicines Yet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Your nurse or doctor will add\nyour medicines here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Medicine List ────────────────────────────────────────
  Widget _buildMedicineList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.lg,
            AppDimensions.lg,
            AppDimensions.sm,
          ),
          child: Text(
            'Your Medicines Today',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.lg,
            ),
            itemCount: _medications.length,
            itemBuilder: (context, index) {
              return _buildMedicineCard(_medications[index]);
            },
          ),
        ),
      ],
    );
  }

  // ── Medicine Card ────────────────────────────────────────
  Widget _buildMedicineCard(Map<String, dynamic> med) {
    final name = med[DBConstants.medName] as String;
    final dosage = med[DBConstants.medDosage] as String;
    final unit = med[DBConstants.medDosageUnit] as String;
    final instructions = med[DBConstants.medInstructions] as String?;
    final colorName = med[DBConstants.medPillColor] as String?;

    // Pill color
    final pillColor = _getPillColor(colorName);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Row(
          children: [
            // Pill icon with color
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: pillColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.medication,
                color: pillColor,
                size: 30,
              ),
            ),

            const SizedBox(width: AppDimensions.md),

            // Medicine info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dosage $unit',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (instructions != null &&
                      instructions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      instructions,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Take button — coming in dose confirmation step
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: AppDimensions.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.successGreen,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: const Text(
                'TAKE',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Get pill color ────────────────────────────────────────
  Color _getPillColor(String? colorName) {
    switch (colorName?.toLowerCase()) {
      case 'red':
        return AppColors.pillRed;
      case 'blue':
        return AppColors.pillBlue;
      case 'green':
        return AppColors.pillGreen;
      case 'yellow':
        return AppColors.pillYellow;
      case 'orange':
        return AppColors.pillOrange;
      case 'purple':
        return AppColors.pillPurple;
      case 'pink':
        return AppColors.pillPink;
      case 'white':
        return AppColors.pillWhite;
      case 'brown':
        return AppColors.pillBrown;
      default:
        return AppColors.primaryBlue;
    }
  }

  // ── Today's date formatted ────────────────────────────────
  String _getTodayDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    final day = days[now.weekday - 1];
    final month = months[now.month - 1];
    return '$day, ${now.day} $month ${now.year}';
  }
}