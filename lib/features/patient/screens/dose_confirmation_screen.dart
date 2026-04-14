// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_constants.dart';

class DoseConfirmationScreen extends StatefulWidget {

  const DoseConfirmationScreen({
    super.key,
    required this.medication,
    required this.patientId,
    required this.patientName,
  });
  final Map<String, dynamic> medication;
  final int patientId;
  final String patientName;

  @override
  State<DoseConfirmationScreen> createState() =>
      _DoseConfirmationScreenState();
}

class _DoseConfirmationScreenState
    extends State<DoseConfirmationScreen>
    with TickerProviderStateMixin {

  // ── Database ──────────────────────────────────────────
  final _db = DatabaseHelper.instance;

  // ── State ─────────────────────────────────────────────
  bool _isLoading     = false;
  bool _showSuccess   = false;

  // ── Animations ────────────────────────────────────────
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _successController;

  late Animation<double> _floatAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _successScaleAnim;
  late Animation<double> _successFadeAnim;

  @override
  void initState() {
    super.initState();

    // Pill floating up/down
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(
      begin: -8,
      end: 8,
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));

    // Button gentle pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 1,
      end: 1.04,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Success tick animation
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _successScaleAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    ));

    _successFadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════
  //  TAKE DOSE — logs to DB then shows success
  // ══════════════════════════════════════════════════════
  Future<void> _confirmDoseTaken() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final nowStr = now.toIso8601String();

      // Build scheduled time string for today
      // We use current time as scheduled time
      // (notification phase will pass exact scheduled time)
      final scheduledStr =
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';

      await _db.insertDoseLog({
        DBConstants.logMedId:
            widget.medication[DBConstants.medId] as int,
        DBConstants.logPatientId:   widget.patientId,
        DBConstants.logScheduledTime: scheduledStr,
        DBConstants.logConfirmedTime: nowStr,
        DBConstants.logStatus:      DBConstants.statusTaken,
        DBConstants.logMethod:      'button',
        DBConstants.logSmsAlert:    0,
        DBConstants.logCreatedAt:   nowStr,
        DBConstants.logUpdatedAt:   nowStr,
      });

      debugPrint(
        '✅ DOSE LOGGED: ${widget.medication[DBConstants.medName]}'
        ' → taken at $nowStr',
      );

      // Stop pill float, stop button pulse
      _floatController.stop();
      _pulseController.stop();

      // Show success overlay
      setState(() {
        _isLoading   = false;
        _showSuccess = true;
      });

      _successController.forward();

      // Wait 1.8s showing success, then pop back
      await Future.delayed(const Duration(milliseconds: 1800));

      if (!mounted) return;
      Navigator.pop(context);

    } catch (e) {
      debugPrint('❌ DOSE LOG ERROR: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving dose: $e',
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════
  //  SNOOZE — just go back, notification phase handles it
  // ══════════════════════════════════════════════════════
  void _snooze() {
    debugPrint('⏰ SNOOZE: Will remind in 30 minutes');
    Navigator.pop(context);
  }

  // ══════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════
  Color _getPillColor(String? colorName) {
    switch (colorName?.toLowerCase()) {
      case 'red':    return AppColors.pillRed;
      case 'blue':   return AppColors.pillBlue;
      case 'green':  return AppColors.pillGreen;
      case 'yellow': return AppColors.pillYellow;
      case 'orange': return AppColors.pillOrange;
      case 'purple': return AppColors.pillPurple;
      case 'pink':   return AppColors.pillPink;
      case 'white':  return AppColors.pillWhite;
      case 'brown':  return AppColors.pillBrown;
      default:       return AppColors.primaryBlue;
    }
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final med         = widget.medication;
    final name        = med[DBConstants.medName]
        as String? ?? 'Medicine';
    final dosage      = med[DBConstants.medDosage]
        as String? ?? '';
    final unit        = med[DBConstants.medDosageUnit]
        as String? ?? '';
    final instructions = med[DBConstants.medInstructions]
        as String?;
    final frequency   = med[DBConstants.medFrequency]
        as String? ?? '';
    final colorName   = med[DBConstants.medPillColor]
        as String?;
    final shape       = med[DBConstants.medPillShape]
        as String? ?? 'tablet';
    final photoPath   = med[DBConstants.medPillPhoto]
        as String?;
    final pillColor   = _getPillColor(colorName);

    return Scaffold(
      body: Stack(
        children: [

          // ── Background gradient ──────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1B5E20), // deep green top
                  Color(0xFF2E7D32), // mid green
                  Color(0xFF43A047), // lighter green bottom
                ],
              ),
            ),
          ),

          // ── Main content ─────────────────────────
          SafeArea(
            child: Column(
              children: [

                // Back button row
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // ── TOP: Pill visual area ────────────
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [

                        // "Time to take your medicine"
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withOpacity(0.15),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Time for your medicine',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Floating pill visual
                        AnimatedBuilder(
                          animation: _floatAnim,
                          builder: (context, child) =>
                              Transform.translate(
                            offset:
                                Offset(0, _floatAnim.value),
                            child: child,
                          ),
                          child: _buildLargePillVisual(
                            photoPath: photoPath,
                            shape: shape,
                            color: pillColor,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Medicine name
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.xl,
                          ),
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Dosage
                        Text(
                          '$dosage $unit',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white
                                .withOpacity(0.9),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Frequency
                        Text(
                          frequency,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            color: Colors.white
                                .withOpacity(0.75),
                          ),
                        ),

                        // Instructions
                        if (instructions != null &&
                            instructions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: AppDimensions.xl,
                            ),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal:
                                    AppDimensions.md,
                                vertical:
                                    AppDimensions.sm,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withOpacity(0.12),
                                borderRadius:
                                    BorderRadius.circular(
                                  AppDimensions.radiusMd,
                                ),
                              ),
                              child: Text(
                                instructions,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white
                                      .withOpacity(0.85),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── BOTTOM: Buttons area ─────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg,
                    AppDimensions.xl,
                    AppDimensions.lg,
                    AppDimensions.xl,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // Drag handle
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(
                          bottom: AppDimensions.lg,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withOpacity(0.3),
                          borderRadius:
                              BorderRadius.circular(2),
                        ),
                      ),

                      // ── BIG TAKE BUTTON ────────────
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, child) =>
                            Transform.scale(
                          scale: _pulseAnim.value,
                          child: child,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 100,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : _confirmDoseTaken,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor:
                                  AppColors.successGreen,
                              disabledBackgroundColor:
                                  Colors.white
                                      .withOpacity(0.7),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  AppDimensions.radiusXl,
                                ),
                              ),
                              elevation: 8,
                              shadowColor: Colors.black
                                  .withOpacity(0.3),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child:
                                        CircularProgressIndicator(
                                      color: AppColors
                                          .successGreen,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                    children: [
                                      Icon(
                                        Icons
                                            .check_circle_rounded,
                                        size: 36,
                                        color: AppColors
                                            .successGreen,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '✓  I TOOK MY MEDICINE',
                                        style: TextStyle(
                                          fontFamily:
                                              'Poppins',
                                          fontSize: 18,
                                          fontWeight:
                                              FontWeight.w800,
                                          color: AppColors
                                              .successGreen,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(
                          height: AppDimensions.md),

                      // ── SNOOZE button ──────────────
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: TextButton.icon(
                          onPressed: _snooze,
                          icon: Icon(
                            Icons.snooze,
                            color: Colors.white
                                .withOpacity(0.8),
                            size: 20,
                          ),
                          label: Text(
                            'Remind me in 30 minutes',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white
                                  .withOpacity(0.8),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                AppDimensions.radiusMd,
                              ),
                              side: BorderSide(
                                color: Colors.white
                                    .withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                          height: AppDimensions.sm),

                      // Patient name reminder
                      Text(
                        'For: ${widget.patientName}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color:
                              Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── SUCCESS OVERLAY ───────────────────────
          if (_showSuccess)
            AnimatedBuilder(
              animation: _successFadeAnim,
              builder: (context, child) => Opacity(
                opacity: _successFadeAnim.value,
                child: child,
              ),
              child: Container(
                color: AppColors.successGreen
                    .withOpacity(0.95),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _successScaleAnim,
                    builder: (context, child) =>
                        Transform.scale(
                      scale: _successScaleAnim.value,
                      child: child,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 72,
                            color: AppColors.successGreen,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Well done! 🎉',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Dose recorded successfully',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  LARGE PILL VISUAL — 120x120, same logic as home screen
  // ══════════════════════════════════════════════════════
  Widget _buildLargePillVisual({
    required String? photoPath,
    required String shape,
    required Color color,
  }) {
    // If photo exists — show it large
    if (photoPath != null && photoPath.isNotEmpty) {
      final file = File(photoPath);
      if (file.existsSync()) {
        return Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
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

    // No photo — draw the shape large
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius:
            BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: _buildLargeShape(shape, color),
      ),
    );
  }

  Widget _buildLargeShape(String shape, Color color) {
    switch (shape.toLowerCase()) {
      case 'capsule':
        return Container(
          width: 84,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Expanded(child: Container(color: color)),
              Expanded(
                child: Container(
                  color: color.withOpacity(0.5),
                ),
              ),
            ],
          ),
        );

      case 'syrup':
      case 'liquid':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24, height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              width: 54, height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'drops':
        return CustomPaint(
          size: const Size(54, 76),
          painter: _LargeDropPainter(color: color),
        );

      case 'patch':
        return Container(
          width: 76, height: 76,
          decoration: BoxDecoration(
            color: color.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 3.5),
          ),
          child: Center(
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.55),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        );

      case 'tablet':
      default:
        return Container(
          width: 76, height: 76,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 52, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
    }
  }
}

// ── Large Drop Painter ────────────────────────────────────
class _LargeDropPainter extends CustomPainter {
  _LargeDropPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.quadraticBezierTo(
      size.width, size.height * 0.5,
      size.width / 2, size.height,
    );
    path.quadraticBezierTo(
      0, size.height * 0.5,
      size.width / 2, 0,
    );
    canvas.drawPath(path, paint);

    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.28),
      7,
      Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_LargeDropPainter old) =>
      old.color != color;
}