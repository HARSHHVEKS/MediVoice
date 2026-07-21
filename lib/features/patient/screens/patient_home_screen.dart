// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_constants.dart';
import '../../../core/services/adherence_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/adherence_ring.dart';
import '../../../core/widgets/pill_visual.dart';
import '../../../core/widgets/section_header.dart';
import 'dose_confirmation_screen.dart';
import 'patient_add_medication_screen.dart';
import 'patient_history_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final _db = DatabaseHelper.instance;

  Map<String, dynamic>? _patient;
  List<DoseSlot> _slots = [];
  int _medicineCount = 0;
  int _streak = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    try {
      setState(() => _isLoading = true);

      final patientId = await _db.getCurrentPatientId();
      if (patientId == null) {
        _bounceToRoleSelection();
        return;
      }

      final patient = await _db.getPatientById(patientId);
      if (patient == null) {
        _bounceToRoleSelection();
        return;
      }

      final now = DateTime.now();
      final slots =
          await AdherenceService.instance.todaysDoses(patientId, now: now);
      final meds = await _db.getMedicationsByPatient(patientId);
      final streak =
          await AdherenceService.instance.currentStreak(patientId, now: now);

      if (!mounted) return;
      setState(() {
        _patient = patient;
        _slots = slots;
        _medicineCount = meds.length;
        _streak = streak;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ PATIENT HOME ERROR: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _bounceToRoleSelection() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/role-selection');
  }

  Future<void> _cycleTheme() async {
    final mode = await ThemeController.instance.toggle();
    if (!mounted) return;
    final label = switch (mode) {
      ThemeMode.light => 'Light mode',
      ThemeMode.dark => 'Dark mode',
      ThemeMode.system => 'System theme',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label, style: const TextStyle(fontFamily: 'Poppins')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ── Derived groupings ────────────────────────────────────

  double get _todayProgress {
    if (_slots.isEmpty) return 1;
    final taken =
        _slots.where((s) => s.status == DBConstants.statusTaken).length;
    return taken / _slots.length;
  }

  List<DoseSlot> _bucket(DoseBucket bucket, DateTime now) =>
      _slots.where((s) => s.bucket(now) == bucket).toList();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.successGreen),
        ),
      );
    }

    final name = _patient?[DBConstants.patientFullName] as String? ?? 'Patient';
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    final now = DateTime.now();

    final dueNow = _bucket(DoseBucket.dueNow, now);
    final upcoming = _bucket(DoseBucket.upcoming, now);
    final taken = _bucket(DoseBucket.taken, now);
    final missed = _bucket(DoseBucket.missed, now);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatientAddMedicationScreen(
              patientId: _patient![DBConstants.patientId] as int,
            ),
          ),
        ).then((_) => _loadPatientData()),
        backgroundColor: AppColors.successGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Medicine',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 15,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPatientData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(name, initial)),
            if (_medicineCount == 0)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildNoMedicines(),
              )
            else if (_slots.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildNothingToday(),
              )
            else ...[
              if (dueNow.isNotEmpty)
                _buildSection(
                  'Due now',
                  Icons.notifications_active,
                  AppColors.warningOrange,
                  dueNow,
                  now,
                ),
              if (upcoming.isNotEmpty)
                _buildSection(
                  'Upcoming today',
                  Icons.schedule,
                  AppColors.primaryBlue,
                  upcoming,
                  now,
                ),
              if (taken.isNotEmpty)
                _buildSection(
                  'Taken today',
                  Icons.check_circle,
                  AppColors.successGreen,
                  taken,
                  now,
                ),
              if (missed.isNotEmpty)
                _buildSection(
                  'Missed / skipped',
                  Icons.error_outline,
                  AppColors.dangerRed,
                  missed,
                  now,
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────

  Widget _buildHeader(String name, String initial) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: const BoxDecoration(
        gradient: AppColors.patientGreenGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                _buildAvatar(initial),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.85),
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
                _headerIcon(
                  Icons.brightness_6_outlined,
                  'Change theme',
                  _cycleTheme,
                ),
                _headerIcon(
                  Icons.history,
                  'My dose history',
                  _openHistory,
                ),
                _headerIcon(
                  Icons.logout,
                  'Log out',
                  () => Navigator.pushReplacementNamed(
                      context, '/role-selection'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.lg),
            _buildProgressPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    final photo = _patient?[DBConstants.patientPhoto] as String?;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
        image: photo != null && photo.isNotEmpty
            ? DecorationImage(image: FileImage(File(photo)), fit: BoxFit.cover)
            : null,
      ),
      child: photo == null || photo.isEmpty
          ? Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  Widget _headerIcon(IconData icon, String tooltip, VoidCallback onTap) =>
      IconButton(
        icon: Icon(icon, color: Colors.white.withOpacity(0.9)),
        tooltip: tooltip,
        onPressed: onTap,
      );

  Widget _buildProgressPanel() {
    final takenCount =
        _slots.where((s) => s.status == DBConstants.statusTaken).length;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        children: [
          AdherenceRing(
            value: _todayProgress,
            size: 76,
            caption: 'today',
            trackColor: Colors.white.withOpacity(0.25),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _slots.isEmpty
                      ? 'Nothing scheduled today'
                      : '$takenCount of ${_slots.length} doses taken',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      size: 18,
                      color: Colors.orangeAccent.shade100,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _streak > 0
                          ? '$_streak day streak'
                          : 'Start your streak today',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openHistory() {
    final name = _patient?[DBConstants.patientFullName] as String? ?? 'Patient';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientHistoryScreen(
          patientId: _patient![DBConstants.patientId] as int,
          patientName: name,
        ),
      ),
    );
  }

  // ── Sections & cards ─────────────────────────────────────

  Widget _buildSection(
    String title,
    IconData icon,
    Color accent,
    List<DoseSlot> slots,
    DateTime now,
  ) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return SectionHeader(
              title: title,
              icon: icon,
              count: slots.length,
              accent: accent,
            );
          }
          final slot = slots[index - 1];
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.lg,
              0,
              AppDimensions.lg,
              AppDimensions.sm,
            ),
            child: _buildDoseCard(slot, now),
          );
        },
        childCount: slots.length + 1,
      ),
    );
  }

  Widget _buildDoseCard(DoseSlot slot, DateTime now) {
    final med = slot.medication;
    final name = slot.medicationName;
    final dosage = med[DBConstants.medDosage] as String? ?? '';
    final unit = med[DBConstants.medDosageUnit] as String? ?? '';
    final instructions = med[DBConstants.medInstructions] as String?;
    final bucket = slot.bucket(now);
    final timeLabel = _formatTime(slot.scheduledTime);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
            PillVisual(
              shape: med[DBConstants.medPillShape] as String?,
              colorName: med[DBConstants.medPillColor] as String?,
              photoPath: med[DBConstants.medPillPhoto] as String?,
              size: 64,
              animate: bucket == DoseBucket.dueNow,
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dosage $unit'.trim(),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                  if (instructions != null && instructions.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      instructions,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.55),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            _buildTrailing(slot, bucket),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailing(DoseSlot slot, DoseBucket bucket) {
    if (bucket == DoseBucket.taken) {
      return const _StatusBadge(
        icon: Icons.check_circle,
        label: 'Taken',
        color: AppColors.successGreen,
      );
    }
    if (bucket == DoseBucket.missed) {
      final skipped = slot.status == DBConstants.statusSkipped;
      return _StatusBadge(
        icon: skipped ? Icons.remove_circle_outline : Icons.cancel,
        label: skipped ? 'Skipped' : 'Missed',
        color: AppColors.dangerRed,
      );
    }
    // Due now or upcoming → actionable TAKE button.
    return GestureDetector(
      onTap: () => _openDose(slot),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: AppColors.patientGreenGradient,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.successGreen.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
            SizedBox(height: 2),
            Text(
              'TAKE',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDose(DoseSlot slot) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoseConfirmationScreen(
          medication: slot.medication,
          patientId: _patient![DBConstants.patientId] as int,
          patientName:
              _patient![DBConstants.patientFullName] as String? ?? 'Patient',
          scheduledTime: slot.scheduledTime.toIso8601String(),
        ),
      ),
    ).then((_) => _loadPatientData());
  }

  // ── Empty states ─────────────────────────────────────────

  Widget _buildNoMedicines() => _EmptyState(
        icon: Icons.medication_outlined,
        title: 'No Medicines Yet',
        message: 'Tap "Add Medicine" below\nto add your first medicine.',
      );

  Widget _buildNothingToday() => const _EmptyState(
        icon: Icons.event_available,
        title: 'All clear for today',
        message: 'No doses are scheduled for today.\nEnjoy your day!',
      );

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
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
                child: Icon(
                  icon,
                  size: 52,
                  color: AppColors.successGreen,
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  height: 1.6,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
}
