// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_constants.dart';
import 'medication_list_screen.dart';

class CaregiverProfilesScreen extends StatefulWidget {
  const CaregiverProfilesScreen({Key? key}) : super(key: key);

  @override
  State<CaregiverProfilesScreen> createState() =>
      _CaregiverProfilesScreenState();
}

class _CaregiverProfilesScreenState
    extends State<CaregiverProfilesScreen> {

  // ── State ────────────────────────────────────────────────
  List<Map<String, dynamic>> _patients = [];
  Map<int, int> _medicationCounts = {};
  bool _isLoading = true;

  // ── Database ─────────────────────────────────────────────
  final _db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  // ── Load all patients + their medicine counts ────────────
  Future<void> _loadPatients() async {
    try {
      setState(() => _isLoading = true);

      final patients = await _db.getCaregiverPatients();

      // Get medicine count for each patient
      final Map<int, int> counts = {};
      for (final patient in patients) {
        final id = patient[DBConstants.patientId] as int;
        final meds = await _db.getMedicationsByPatient(id);
        counts[id] = meds.length;
      }

      if (!mounted) return;
      setState(() {
        _patients = patients;
        _medicationCounts = counts;
        _isLoading = false;
      });

      debugPrint('✅ CAREGIVER: Loaded ${patients.length} patients');
    } catch (e) {
      debugPrint('❌ LOAD PATIENTS ERROR: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Select patient to manage ─────────────────────────────
  Future<void> _selectPatient(
    Map<String, dynamic> patient,
  ) async {
    final patientId = patient[DBConstants.patientId] as int;
    await _db.setCurrentPatient(patientId);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationListScreen(
          patient: patient,
        ),
      ),
    ).then((_) => _loadPatients());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryBlue,
              AppColors.primaryDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Bar ──────────────────────────────
              _buildTopBar(),

              // ── Content ──────────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      )
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),

      // ── FAB — Add New Patient ─────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(
          context,
          '/add-patient',
        ).then((_) => _loadPatients()),
        backgroundColor: AppColors.successGreen,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Add Patient',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 15,
          ),
        ),
      ),
    );

  // ── Top Bar ──────────────────────────────────────────────
  Widget _buildTopBar() => Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),

          // Title
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Caregiver Mode',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Select a patient to manage',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadPatients,
          ),
        ],
      ),
    );

  // ── Main Content ─────────────────────────────────────────
  Widget _buildContent() {
    if (_patients.isEmpty) {
      return _buildEmptyState();
    }
    return _buildPatientList();
  }

  // ── Empty State ──────────────────────────────────────────
Widget _buildEmptyState() => Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.people_outline,
                size: 56,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            const Text(
              'No Patients Yet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Tap the green button below\nto add your first patient profile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                color: Colors.white.withOpacity(0.7),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );

  // ── Patient List ─────────────────────────────────────────
  Widget _buildPatientList() => ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        100, // space for FAB
      ),
      itemCount: _patients.length,
      itemBuilder: (context, index) {
        return _buildPatientCard(_patients[index]);
      },
    );

  // ── Patient Card ─────────────────────────────────────────
  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final name = patient[DBConstants.patientFullName] as String;
    final ward = patient[DBConstants.patientWard] as String? ?? '';
    final age = patient[DBConstants.patientAge];
    final patientId = patient[DBConstants.patientId] as int;
    final medCount = _medicationCounts[patientId] ?? 0;
    final initial = name.isNotEmpty
      ? name.substring(0, 1).toUpperCase() : '?';

    // Pick avatar color based on name
    final colors = [
      AppColors.pillBlue,
      AppColors.pillGreen,
      AppColors.pillOrange,
      AppColors.pillPurple,
      AppColors.pillPink,
    ];
    final color = colors[name.length % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectPatient(patient),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              children: [
                // ── Avatar ──────────────────────────────
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: color.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: AppDimensions.md),

                // ── Info ─────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (age != null) ...[
                            _buildTag(
                              '$age yrs',
                              Icons.cake_outlined,
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (ward.isNotEmpty)
                            _buildTag(ward, Icons.local_hospital_outlined),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.medication_outlined,
                            size: 14,
                            color: medCount > 0
                                ? AppColors.successGreen
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            medCount > 0
                                ? '$medCount medicine${medCount > 1 ? 's' : ''} added'
                                : 'No medicines added yet',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: medCount > 0
                                  ? AppColors.successGreen
                                  : AppColors.textSecondary,
                              fontWeight: medCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Arrow ────────────────────────────────
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Small tag widget ─────────────────────────────────────
  Widget _buildTag(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}