// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_constants.dart';
import 'patient_add_medication_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({Key? key}) : super(key: key);

  @override
  State<PatientHomeScreen> createState() =>
      _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  // ── State ─────────────────────────────────────────────
  Map<String, dynamic>? _patient;
  List<Map<String, dynamic>> _medications = [];
  bool _isLoading = true;

  // ── Database ──────────────────────────────────────────
  final _db = DatabaseHelper.instance;

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
        if (!mounted) return;
        Navigator.pushReplacementNamed(
            context, '/role-selection');
        return;
      }

      final patient = await _db.getPatientById(patientId);
      if (patient == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
            context, '/role-selection');
        return;
      }

      final meds =
          await _db.getMedicationsByPatient(patientId);

      if (!mounted) return;
      setState(() {
        _patient = patient;
        _medications = meds;
        _isLoading = false;
      });

      debugPrint(
        '✅ PATIENT HOME: Loaded ${meds.length} medications',
      );
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

    final name =
        _patient?[DBConstants.patientFullName] ?? 'Patient';
    final initial = name.isNotEmpty
        ? name.substring(0, 1).toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatientAddMedicationScreen(
              patientId:
                  _patient![DBConstants.patientId] as int,
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(name, initial),
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

  // ── Header ────────────────────────────────────────────
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
                  image: _patient?[DBConstants.patientPhoto] !=
                          null
                      ? DecorationImage(
                          image: FileImage(
                            File(
                              _patient![DBConstants.patientPhoto]
                                  as String,
                            ),
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child:
                    _patient?[DBConstants.patientPhoto] == null
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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
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

              // Logout
              IconButton(
                icon: Icon(
                  Icons.logout,
                  color: Colors.white.withOpacity(0.8),
                ),
                onPressed: () =>
                    Navigator.pushReplacementNamed(
                  context,
                  '/role-selection',
                ),
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
              borderRadius: BorderRadius.circular(
                AppDimensions.radiusMd,
              ),
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

  // ── No medicines ──────────────────────────────────────
  Widget _buildNoMedicines() => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color:
                      AppColors.successGreen.withOpacity(0.1),
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
                'Tap "Add Medicine" below\nto add your first medicine.',
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

  // ── Medicine List ─────────────────────────────────────
  Widget _buildMedicineList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.lg,
            AppDimensions.lg,
            AppDimensions.sm,
          ),
          child: Text(
            'Your Medicines Today',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.lg,
              0,
              AppDimensions.lg,
              100,
            ),
            itemCount: _medications.length,
            itemBuilder: (context, index) =>
                _buildMedicineCard(_medications[index]),
          ),
        ),
      ],
    );
  }

  // ── Medicine Card ─────────────────────────────────────
  Widget _buildMedicineCard(Map<String, dynamic> med) {
    final name = med[DBConstants.medName] as String;
    final dosage = med[DBConstants.medDosage] as String;
    final unit = med[DBConstants.medDosageUnit] as String;
    final instructions =
        med[DBConstants.medInstructions] as String?;
    final colorName =
        med[DBConstants.medPillColor] as String?;
    final shape = med[DBConstants.medPillShape] as String?;
    final photoPath =
        med[DBConstants.medPillPhoto] as String?;
    final pillColor = _getPillColor(colorName);

    return Container(
      margin:
          const EdgeInsets.only(bottom: AppDimensions.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(AppDimensions.radiusLg),
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
            // ── Pill Visual ────────────────────────
            _buildPillVisual(
              photoPath: photoPath,
              shape: shape ?? 'tablet',
              color: pillColor,
            ),

            const SizedBox(width: AppDimensions.md),

            // ── Medicine Info ──────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
                  Text(
                    '$dosage $unit',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
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

            const SizedBox(width: AppDimensions.sm),

            // ── TAKE Button ────────────────────────
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Dose confirmation coming soon!',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                      ),
                    ),
                    backgroundColor: AppColors.successGreen,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF43A047),
                      Color(0xFF2E7D32),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMd,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.successGreen
                          .withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 24,
                    ),
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
            ),
          ],
        ),
      ),
    );
  }

  // ── Pill Visual ───────────────────────────────────────
  Widget _buildPillVisual({
    required String? photoPath,
    required String shape,
    required Color color,
  }) {
    if (photoPath != null && photoPath.isNotEmpty) {
      final file = File(photoPath);
      if (file.existsSync()) {
        return Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              AppDimensions.radiusMd,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            image: DecorationImage(
              image: FileImage(file),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    }

    return _PatientPillWidget(
      shape: shape,
      color: color,
    );
  }

  // ── Get pill color ────────────────────────────────────
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

  // ── Today's date ──────────────────────────────────────
  String _getTodayDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    final day = days[now.weekday - 1];
    final month = months[now.month - 1];
    return '$day, ${now.day} $month ${now.year}';
  }
} // ← _PatientHomeScreenState ENDS HERE

// ══════════════════════════════════════════════════════════
// Animated Pill Widget — OUTSIDE the state class
// ══════════════════════════════════════════════════════════
class _PatientPillWidget extends StatefulWidget {
  final String shape;
  final Color color;

  const _PatientPillWidget({
    required this.shape,
    required this.color,
  });

  @override
  State<_PatientPillWidget> createState() =>
      _PatientPillWidgetState();
}

class _PatientPillWidgetState
    extends State<_PatientPillWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _float = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _float.value),
        child: child,
      ),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(
            AppDimensions.radiusMd,
          ),
          border: Border.all(
            color: widget.color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Center(child: _buildShape()),
      ),
    );
  }

  Widget _buildShape() {
    switch (widget.shape.toLowerCase()) {
      case 'capsule':
        return _buildCapsule();
      case 'syrup':
      case 'liquid':
        return _buildBottle();
      case 'drops':
        return _buildDrop();
      case 'inhaler':
        return _buildInhaler();
      case 'injection':
        return _buildInjection();
      case 'patch':
        return _buildPatch();
      case 'tablet':
      default:
        return _buildTablet();
    }
  }

  Widget _buildTablet() => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 28,
            height: 2.5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _buildCapsule() => Container(
        width: 46,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
                child: Container(color: widget.color)),
            Expanded(
              child: Container(
                color: widget.color.withOpacity(0.45),
              ),
            ),
          ],
        ),
      );

  Widget _buildBottle() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: 30,
            height: 34,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.85),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildDrop() => CustomPaint(
        size: const Size(30, 42),
        painter: _DropPainter(color: widget.color),
      );

  Widget _buildInhaler() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 7,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.6),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: 26,
            height: 32,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildInjection() => Transform.rotate(
        angle: -0.5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 30,
              height: 13,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.25),
                border: Border.all(
                  color: widget.color,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 15,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      );

  Widget _buildPatch() => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: widget.color,
            width: 2.5,
          ),
        ),
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
}

// ── Drop Painter ──────────────────────────────────────────
class _DropPainter extends CustomPainter {
  final Color color;
  _DropPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.quadraticBezierTo(
      size.width,
      size.height * 0.5,
      size.width / 2,
      size.height,
    );
    path.quadraticBezierTo(
      0,
      size.height * 0.5,
      size.width / 2,
      0,
    );
    canvas.drawPath(path, paint);

    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.3),
      4,
      Paint()
        ..color = Colors.white.withOpacity(0.45)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_DropPainter old) =>
      old.color != color;
}