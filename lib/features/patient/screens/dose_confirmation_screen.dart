// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_constants.dart';
import '../../../core/services/alarm_audio_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/sms_service.dart';

class DoseConfirmationScreen extends StatefulWidget {
  const DoseConfirmationScreen({
    super.key,
    required this.medication,
    required this.patientId,
    required this.patientName,
    this.scheduledTime,
    this.autoPlayReminder = false,
    this.reminderStage = 1,
  });

  final Map<String, dynamic> medication;
  final int patientId;
  final String patientName;
  final String? scheduledTime;
  final bool autoPlayReminder;
  final int reminderStage;

  @override
  State<DoseConfirmationScreen> createState() => _DoseConfirmationScreenState();
}

class _DoseConfirmationScreenState extends State<DoseConfirmationScreen>
    with TickerProviderStateMixin {
  final _db = DatabaseHelper.instance;

  bool _isLoading = false;
  bool _showSuccess = false;
  bool _showMissed = false;
  bool _isReminderLoopActive = false;
  bool _isEscalating = false;
  int? _doseLogId;
  String? _alertPhone;

  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _successController;

  late Animation<double> _floatAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _successScaleAnim;
  late Animation<double> _successFadeAnim;

  bool get _isSecondReminder => widget.reminderStage == 2;
  String get _takeButtonText => 'TAKEN';
  String get _laterButtonText => _isSecondReminder ? 'Close' : 'Later';

  @override
  void initState() {
    super.initState();

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

    _prepareReminderState();
  }

  @override
  void dispose() {
    AlarmAudioService.instance.stopAlarm();
    AlarmAudioService.instance.stopPlayback();
    AlarmAudioService.instance.stopVibration();
    _floatController.dispose();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _prepareReminderState() async {
    final medId = widget.medication[DBConstants.medId] as int;
    final scheduledDateTime = _scheduledDateTime();

    final logId = await _db.ensurePendingDoseLog(
      medicationId: medId,
      patientId: widget.patientId,
      scheduledTime: scheduledDateTime.toIso8601String(),
    );

    final alertPhone = await _db.getPrimaryAlertPhone(widget.patientId);

    if (!mounted) return;
    setState(() {
      _doseLogId = logId;
      _alertPhone = alertPhone;
    });

    if (widget.autoPlayReminder) {
      unawaited(_startReminderLoop());
    }
  }

  DateTime _scheduledDateTime() {
    final raw = widget.scheduledTime;
    if (raw == null || raw.isEmpty) {
      final now = DateTime.now();
      return DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      );
    }

    return DateTime.tryParse(raw) ?? DateTime.now();
  }

  Future<void> _startReminderLoop() async {
    if (_isReminderLoopActive || _showSuccess || _showMissed) return;

    final audioPath = widget.medication[DBConstants.medAudioPath] as String?;
    final reminderDeadline = DateTime.now().add(
      const Duration(minutes: 1),
    );

    setState(() => _isReminderLoopActive = true);

    try {
      await AlarmAudioService.instance.stopPlayback();
      await AlarmAudioService.instance.stopAlarm();
      await AlarmAudioService.instance.startVibration();

      while (_isReminderLoopActive &&
          mounted &&
          DateTime.now().isBefore(reminderDeadline)) {
        final alarmRemaining = reminderDeadline.difference(DateTime.now());
        if (alarmRemaining <= Duration.zero) break;

        await AlarmAudioService.instance.playAlarm();
        final alarmStep = await _waitForReminderStep(
          alarmRemaining < const Duration(seconds: 6)
              ? alarmRemaining
              : const Duration(seconds: 6),
        );
        await AlarmAudioService.instance.stopAlarm();
        if (!alarmStep) break;

        if (audioPath != null && audioPath.isNotEmpty) {
          final durationMs =
              await AlarmAudioService.instance.playRecording(audioPath);
          final voiceRemaining = reminderDeadline.difference(DateTime.now());
          if (voiceRemaining <= Duration.zero) break;

          final voiceLength = Duration(
            milliseconds: (durationMs ?? 5000).clamp(1000, 600000),
          );
          final voiceStep = await _waitForReminderStep(
            voiceRemaining < voiceLength ? voiceRemaining : voiceLength,
          );
          await AlarmAudioService.instance.stopPlayback();
          if (!voiceStep) break;
        } else {
          final keepLooping = await _waitForReminderStep(
            const Duration(milliseconds: 400),
          );
          if (!keepLooping) break;
        }
      }
    } catch (e) {
      debugPrint('❌ REMINDER LOOP ERROR: $e');
    } finally {
      await AlarmAudioService.instance.stopAlarm();
      await AlarmAudioService.instance.stopPlayback();
      await AlarmAudioService.instance.stopVibration();
      if (!mounted) return;
      setState(() => _isReminderLoopActive = false);
    }

    if (_showSuccess || _showMissed || _isEscalating || !mounted) {
      return;
    }

    if (_isSecondReminder) {
      await _markDoseMissedAndSendSms();
    } else {
      await _scheduleSecondReminderAndExit();
    }
  }

  Future<bool> _waitForReminderStep(Duration duration) async {
    var remaining = duration;
    const tick = Duration(milliseconds: 200);

    while (_isReminderLoopActive && remaining > Duration.zero) {
      final delay = remaining < tick ? remaining : tick;
      await Future<void>.delayed(delay);
      remaining -= delay;
    }

    return _isReminderLoopActive;
  }

  Future<void> _stopReminderLoop() async {
    _isReminderLoopActive = false;
    await AlarmAudioService.instance.stopAlarm();
    await AlarmAudioService.instance.stopPlayback();
    await AlarmAudioService.instance.stopVibration();
  }

  Future<void> _scheduleSecondReminderAndExit() async {
    if (_isEscalating) return;
    _isEscalating = true;

    try {
      await _stopReminderLoop();

      final med = widget.medication;
      await NotificationService.instance.scheduleSecondReminder(
        patientId: widget.patientId,
        medicationId: med[DBConstants.medId] as int,
        medicineName: med[DBConstants.medName] as String? ?? 'Medicine',
        dosage: med[DBConstants.medDosage] as String? ?? '',
        unit: med[DBConstants.medDosageUnit] as String? ?? '',
        originalScheduledTime: _scheduledDateTime(),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      _isEscalating = false;
    }
  }

  Future<void> _markDoseMissedAndSendSms() async {
    if (_isEscalating || _showSuccess || _showMissed) return;
    _isEscalating = true;

    try {
      await _stopReminderLoop();

      final logId = _doseLogId;
      if (logId != null) {
        await _db.updateDoseLog(
          logId,
          {
            DBConstants.logStatus: DBConstants.statusMissed,
            DBConstants.logMethod: 'second-alarm-missed',
            DBConstants.logSmsAlert: 0,
          },
        );
      }

      final smsSent = await _sendMissedDoseSms();

      if (logId != null) {
        await _db.updateDoseLog(
          logId,
          {
            DBConstants.logSmsAlert: smsSent ? 1 : 0,
          },
        );
      }

      if (!mounted) return;
      setState(() => _showMissed = true);
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      _isEscalating = false;
    }
  }

  Future<bool> _sendMissedDoseSms() async {
    final phone = _alertPhone;
    if (phone == null || phone.isEmpty) return false;

    final medName =
        widget.medication[DBConstants.medName] as String? ?? 'medicine';
    final dosage = widget.medication[DBConstants.medDosage] as String? ?? '';
    final unit = widget.medication[DBConstants.medDosageUnit] as String? ?? '';

    final message = 'Missed dose alert: ${widget.patientName} has not taken '
        '$medName $dosage $unit.';

    try {
      return await SmsService.instance.sendSms(
        phoneNumber: phone,
        message: message,
      );
    } catch (e) {
      debugPrint('❌ SMS SEND ERROR: $e');
      return false;
    }
  }

  Future<void> _confirmDoseTaken() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final nowStr = DateTime.now().toIso8601String();
      final medId = widget.medication[DBConstants.medId] as int;
      final scheduledTime = _scheduledDateTime();

      await _stopReminderLoop();
      await NotificationService.instance.cancelSecondReminder(
        medicationId: medId,
        originalScheduledTime: scheduledTime,
      );

      final existingLogId = _doseLogId ??
          await _db.ensurePendingDoseLog(
            medicationId: medId,
            patientId: widget.patientId,
            scheduledTime: scheduledTime.toIso8601String(),
            method: widget.autoPlayReminder ? 'notification' : 'manual-open',
          );

      await _db.updateDoseLog(
        existingLogId,
        {
          DBConstants.logConfirmedTime: nowStr,
          DBConstants.logStatus: DBConstants.statusTaken,
          DBConstants.logMethod: _isSecondReminder
              ? 'second-alarm-confirmation'
              : 'alarm-confirmation',
          DBConstants.logSmsAlert: 0,
        },
      );

      _floatController.stop();
      _pulseController.stop();

      setState(() {
        _isLoading = false;
        _showSuccess = true;
      });

      _successController.forward();
      await Future<void>.delayed(const Duration(milliseconds: 1800));

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

  Future<void> _handleLater() async {
    if (_isSecondReminder) {
      await _markDoseMissedAndSendSms();
      return;
    }

    await _scheduleSecondReminderAndExit();
  }

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

  @override
  Widget build(BuildContext context) {
    final med = widget.medication;
    final name = med[DBConstants.medName] as String? ?? 'Medicine';
    final dosage = med[DBConstants.medDosage] as String? ?? '';
    final unit = med[DBConstants.medDosageUnit] as String? ?? '';
    final instructions = med[DBConstants.medInstructions] as String?;
    final colorName = med[DBConstants.medPillColor] as String?;
    final shape = med[DBConstants.medPillShape] as String? ?? 'tablet';
    final photoPath = med[DBConstants.medPillPhoto] as String?;
    final hasAudio =
        (med[DBConstants.medAudioPath] as String?)?.isNotEmpty == true;
    final pillColor = _getPillColor(colorName);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1B5E20),
                  Color(0xFF2E7D32),
                  Color(0xFF43A047),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
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
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isSecondReminder
                                      ? 'Medicine time again'
                                      : 'Medicine time',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          AnimatedBuilder(
                            animation: _floatAnim,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(0, _floatAnim.value),
                              child: child,
                            ),
                            child: _buildLargePillVisual(
                              photoPath: photoPath,
                              shape: shape,
                              color: pillColor,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.xl,
                            ),
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$dosage $unit',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          if (instructions != null &&
                              instructions.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.lg,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.md,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMd,
                                  ),
                                ),
                                child: Text(
                                  instructions,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white.withOpacity(0.85),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (hasAudio) ...[
                            const SizedBox(height: 12),
                            Text(
                              _isReminderLoopActive
                                  ? 'Voice playing'
                                  : 'Doctor note ready',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
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
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(
                          bottom: AppDimensions.lg,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, child) => Transform.scale(
                          scale: _pulseAnim.value,
                          child: child,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 88,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _confirmDoseTaken,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.successGreen,
                              disabledBackgroundColor:
                                  Colors.white.withOpacity(0.7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusXl,
                                ),
                              ),
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.3),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      color: AppColors.successGreen,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Text(
                                    _takeButtonText,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.successGreen,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: TextButton.icon(
                          onPressed: _handleLater,
                          icon: Icon(
                            _isSecondReminder
                                ? Icons.close_rounded
                                : Icons.schedule,
                            color: Colors.white.withOpacity(0.8),
                            size: 18,
                          ),
                          label: Text(
                            _laterButtonText,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd,
                              ),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        widget.patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_showSuccess)
            AnimatedBuilder(
              animation: _successFadeAnim,
              builder: (context, child) => Opacity(
                opacity: _successFadeAnim.value,
                child: child,
              ),
              child: Container(
                color: AppColors.successGreen.withOpacity(0.95),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _successScaleAnim,
                    builder: (context, child) => Transform.scale(
                      scale: _successScaleAnim.value,
                      child: child,
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 96,
                          color: Colors.white,
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Taken',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_showMissed)
            Container(
              color: AppColors.dangerRed.withOpacity(0.94),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sms_failed_outlined,
                      size: 72,
                      color: Colors.white,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Dose missed',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Alert sent',
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
        ],
      ),
    );
  }

  Widget _buildLargePillVisual({
    required String? photoPath,
    required String shape,
    required Color color,
  }) {
    if (photoPath != null && photoPath.isNotEmpty) {
      final file = File(photoPath);
      if (file.existsSync()) {
        return Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
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

    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
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
              width: 24,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              width: 54,
              height: 60,
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
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: color.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 3.5),
          ),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
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
          width: 76,
          height: 76,
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
              width: 52,
              height: 4,
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
      Offset(size.width * 0.35, size.height * 0.28),
      7,
      Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_LargeDropPainter old) => old.color != color;
}
