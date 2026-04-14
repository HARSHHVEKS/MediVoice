// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_constants.dart';
import 'add_medication_screen.dart';

class MedicationListScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const MedicationListScreen({
    Key? key,
    required this.patient,
  }) : super(key: key);

  @override
  State<MedicationListScreen> createState() =>
      _MedicationListScreenState();
}

class _MedicationListScreenState
    extends State<MedicationListScreen> {
  // ── State ─────────────────────────────────────────────
  List<Map<String, dynamic>> _medications = [];
  bool _isLoading = true;

  // ── Database ──────────────────────────────────────────
  final _db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  // ── Load medications ──────────────────────────────────
  Future<void> _loadMedications() async {
    try {
      setState(() => _isLoading = true);
      final patientId =
          widget.patient[DBConstants.patientId] as int;
      final meds = await _db.getMedicationsByPatient(patientId);
      if (!mounted) return;
      setState(() {
        _medications = meds;
        _isLoading = false;
      });
      debugPrint('✅ MEDS: Loaded ${meds.length} medications');
    } catch (e) {
      debugPrint('❌ LOAD MEDS ERROR: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Delete medication ─────────────────────────────────
  Future<void> _deleteMedication(int medId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusXl),
        ),
        title: const Text(
          'Remove Medicine?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Remove "$name" from this patient\'s list?',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.dangerRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.deactivateMedication(medId);
      debugPrint('✅ MED DELETED: $name');
      _loadMedications();
    } catch (e) {
      debugPrint('❌ DELETE MED ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        widget.patient[DBConstants.patientFullName] as String;
    final initial = name.isNotEmpty
        ? name.substring(0, 1).toUpperCase()
        : '?';

    return Scaffold(
      body: Container(
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
              // ── Top Bar ────────────────────────────
              _buildTopBar(name, initial),

              // ── Content ────────────────────────────
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryBlue,
                          ),
                        )
                      : _medications.isEmpty
                          ? _buildEmptyState()
                          : _buildMedList(),
                ),
              ),
            ],
          ),
        ),
      ),

      // ── FAB ──────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddMedicationScreen(
              patientId:
                  widget.patient[DBConstants.patientId] as int,
              patientName: name,
            ),
          ),
        ).then((_) => _loadMedications()),
        backgroundColor: AppColors.primaryBlue,
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
    );
  }

  // ── Top Bar ───────────────────────────────────────────
  Widget _buildTopBar(String name, String initial) {
    final photoPath =
        widget.patient[DBConstants.patientPhoto] as String?;
    final age = widget.patient[DBConstants.patientAge];
    final ward =
        widget.patient[DBConstants.patientWard] as String?;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),

          // Patient avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2,
              ),
              image: photoPath != null
                  ? DecorationImage(
                      image: FileImage(File(photoPath)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: photoPath == null
                ? Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          ),

          const SizedBox(width: AppDimensions.sm),

          // Patient info
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
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    if (age != null) '$age yrs',
                    if (ward != null && ward.isNotEmpty) ward,
                  ].join(' • '),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),

          // Med count badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_medications.length} med${_medications.length != 1 ? 's' : ''}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────
  Widget _buildEmptyState() {
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
                color: AppColors.primaryBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.medication_outlined,
                size: 52,
                color: AppColors.primaryBlue,
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
              'Tap "Add Medicine" below\nto add this patient\'s first medicine.',
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

  // ── Medicine List ─────────────────────────────────────
  Widget _buildMedList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.lg,
        AppDimensions.md,
        100,
      ),
      itemCount: _medications.length,
      itemBuilder: (context, index) =>
          _buildMedCard(_medications[index]),
    );
  }

  // ── Medicine Card ─────────────────────────────────────
  Widget _buildMedCard(Map<String, dynamic> med) {
    final medId = med[DBConstants.medId] as int;
    final name = med[DBConstants.medName] as String;
    final dosage = med[DBConstants.medDosage] as String;
    final unit = med[DBConstants.medDosageUnit] as String;
    final frequency = med[DBConstants.medFrequency] as String;
    final colorName = med[DBConstants.medPillColor] as String?;
    final shape = med[DBConstants.medPillShape] as String?;
    final photoPath = med[DBConstants.medPillPhoto] as String?;
    final hasAudio = (med[DBConstants.medAudioPath] as String?)
            ?.isNotEmpty ==
        true;
    final instructions =
        med[DBConstants.medInstructions] as String?;

    final pillColor = _getPillColor(colorName);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.md),
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
            // ── Pill Visual ───────────────────────────
            _buildPillVisual(
              photoPath: photoPath,
              shape: shape,
              color: pillColor,
              colorName: colorName,
            ),

            const SizedBox(width: AppDimensions.md),

            // ── Info ──────────────────────────────────
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
                  const SizedBox(height: 3),
                  Text(
                    '$dosage $unit • $frequency',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (instructions != null &&
                      instructions.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      instructions,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Audio badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: hasAudio
                              ? AppColors.successGreen
                                  .withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                            color: hasAudio
                                ? AppColors.successGreen
                                    .withOpacity(0.3)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasAudio
                                  ? Icons.mic
                                  : Icons.mic_none,
                              size: 12,
                              color: hasAudio
                                  ? AppColors.successGreen
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasAudio
                                  ? 'Audio recorded'
                                  : 'No audio yet',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: hasAudio
                                    ? AppColors.successGreen
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Actions ───────────────────────────────
            Column(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddMedicationScreen(
                        patientId: widget.patient[
                            DBConstants.patientId] as int,
                        patientName: widget.patient[
                            DBConstants.patientFullName] as String,
                        existingMedication: med,
                      ),
                    ),
                  ).then((_) => _loadMedications()),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.dangerRed,
                    size: 20,
                  ),
                  onPressed: () =>
                      _deleteMedication(medId, name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Pill Visual ───────────────────────────────────────
  Widget _buildPillVisual({
    required String? photoPath,
    required String? shape,
    required Color color,
    required String? colorName,
  }) {
    // If photo exists — show it
    if (photoPath != null && photoPath.isNotEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: FileImage(File(photoPath)),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // No photo — show animated shape
    return _AnimatedPillWidget(
      shape: shape ?? 'tablet',
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
}

// ══════════════════════════════════════════════════════════
// Animated Pill Widget — Pure Flutter, no packages
// ══════════════════════════════════════════════════════════
class _AnimatedPillWidget extends StatefulWidget {
  final String shape;
  final Color color;

  const _AnimatedPillWidget({
    required this.shape,
    required this.color,
  });

  @override
  State<_AnimatedPillWidget> createState() =>
      _AnimatedPillWidgetState();
}

class _AnimatedPillWidgetState extends State<_AnimatedPillWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(
      begin: -3,
      end: 3,
    ).animate(
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
      animation: _floatAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _floatAnimation.value),
        child: child,
      ),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: _buildShape(),
        ),
      ),
    );
  }

  Widget _buildShape() {
    switch (widget.shape.toLowerCase()) {
      case 'capsule':
        return _CapsuleShape(color: widget.color);
      case 'syrup':
      case 'liquid':
        return _BottleShape(color: widget.color);
      case 'drops':
        return _DropsShape(color: widget.color);
      case 'inhaler':
        return _InhalerShape(color: widget.color);
      case 'injection':
        return _InjectionShape(color: widget.color);
      case 'patch':
        return _PatchShape(color: widget.color);
      case 'tablet':
      default:
        return _TabletShape(color: widget.color);
    }
  }
}

// ── Tablet Shape ──────────────────────────────────────────
class _TabletShape extends StatelessWidget {
  final Color color;
  const _TabletShape({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 24,
            height: 2,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      );
}

// ── Capsule Shape ─────────────────────────────────────────
class _CapsuleShape extends StatelessWidget {
  final Color color;
  const _CapsuleShape({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.5),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Bottle Shape (Syrup) ──────────────────────────────────
class _BottleShape extends StatelessWidget {
  final Color color;
  const _BottleShape({required this.color});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 28,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.8),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      );
}

// ── Drops Shape ───────────────────────────────────────────
class _DropsShape extends StatelessWidget {
  final Color color;
  const _DropsShape({required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(28, 38),
        painter: _DropPainter(color: color),
      );
}

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
        size.width, size.height * 0.5, size.width / 2, size.height);
    path.quadraticBezierTo(
        0, size.height * 0.5, size.width / 2, 0);

    canvas.drawPath(path, paint);

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.35),
      4,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(_DropPainter old) => old.color != color;
}

// ── Inhaler Shape ─────────────────────────────────────────
class _InhalerShape extends StatelessWidget {
  final Color color;
  const _InhalerShape({required this.color});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 6,
            decoration: BoxDecoration(
              color: color.withOpacity(0.6),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: 24,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      );
}

// ── Injection Shape ───────────────────────────────────────
class _InjectionShape extends StatelessWidget {
  final Color color;
  const _InjectionShape({required this.color});

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -0.5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 28,
              height: 12,
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                border: Border.all(color: color, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 14,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      );
}

// ── Patch Shape ───────────────────────────────────────────
class _PatchShape extends StatelessWidget {
  final Color color;
  const _PatchShape({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
}