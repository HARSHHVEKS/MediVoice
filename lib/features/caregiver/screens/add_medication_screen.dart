// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_constants.dart';
import '../../../core/services/alarm_audio_service.dart';
import '../../../core/services/notification_service.dart'; // ← NEW

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({
    required this.patientId,
    required this.patientName,
    super.key,
    this.existingMedication,
  });
  final int patientId;
  final String patientName;
  final Map<String, dynamic>? existingMedication;

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionsController = TextEditingController();

  String _selectedUnit = 'mg';
  String _selectedFrequency = 'Once daily';
  String _selectedShape = 'tablet';
  String? _selectedColor;
  bool _isLoading = false;
  bool _isRecording = false;
  bool _isPlayingAudio = false;
  bool get _isEditing => widget.existingMedication != null;

  File? _pillPhoto;
  String? _existingPhotoPath;
  String? _existingAudioPath;

  final List<TimeOfDay> _timeslots = [
    const TimeOfDay(hour: 8, minute: 0),
  ];

  final _imagePicker = ImagePicker();
  final _db = DatabaseHelper.instance;

  final List<String> _units = [
    'mg',
    'ml',
    'g',
    'mcg',
    'tablet(s)',
    'capsule(s)',
    'drop(s)',
    'puff(s)',
    'patch(es)',
  ];

  final List<String> _frequencies = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'Four times daily',
    'Every 6 hours',
    'Every 8 hours',
    'Every 12 hours',
    'As needed',
    'Weekly',
  ];

  final List<Map<String, dynamic>> _shapes = [
    {'value': 'tablet', 'label': 'Tablet', 'icon': Icons.circle},
    {'value': 'capsule', 'label': 'Capsule', 'icon': Icons.medication},
    {'value': 'syrup', 'label': 'Syrup', 'icon': Icons.local_drink},
    {'value': 'drops', 'label': 'Drops', 'icon': Icons.water_drop},
    {'value': 'inhaler', 'label': 'Inhaler', 'icon': Icons.air},
    {'value': 'injection', 'label': 'Injection', 'icon': Icons.colorize},
    {'value': 'patch', 'label': 'Patch', 'icon': Icons.square},
  ];

  final List<Map<String, dynamic>> _colors = [
    {'value': 'white', 'color': AppColors.pillWhite, 'label': 'White'},
    {'value': 'red', 'color': AppColors.pillRed, 'label': 'Red'},
    {'value': 'blue', 'color': AppColors.pillBlue, 'label': 'Blue'},
    {'value': 'green', 'color': AppColors.pillGreen, 'label': 'Green'},
    {'value': 'yellow', 'color': AppColors.pillYellow, 'label': 'Yellow'},
    {'value': 'orange', 'color': AppColors.pillOrange, 'label': 'Orange'},
    {'value': 'purple', 'color': AppColors.pillPurple, 'label': 'Purple'},
    {'value': 'pink', 'color': AppColors.pillPink, 'label': 'Pink'},
    {'value': 'brown', 'color': AppColors.pillBrown, 'label': 'Brown'},
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) _prefillFields();
  }

  void _prefillFields() {
    final med = widget.existingMedication!;
    _nameController.text = med[DBConstants.medName] ?? '';
    _dosageController.text = med[DBConstants.medDosage] ?? '';
    _instructionsController.text = med[DBConstants.medInstructions] ?? '';
    _selectedUnit = med[DBConstants.medDosageUnit] ?? 'mg';
    _selectedFrequency = med[DBConstants.medFrequency] ?? 'Once daily';
    _selectedShape = med[DBConstants.medPillShape] ?? 'tablet';
    _selectedColor = med[DBConstants.medPillColor];
    _existingPhotoPath = med[DBConstants.medPillPhoto];
    _existingAudioPath = med[DBConstants.medAudioPath];
  }

  @override
  void dispose() {
    AlarmAudioService.instance.stopPlayback();
    if (_isRecording) {
      AlarmAudioService.instance.stopRecording();
    }
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _startVoiceRecording() async {
    try {
      await AlarmAudioService.instance.stopPlayback();
      await AlarmAudioService.instance.startRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _isPlayingAudio = false;
      });
      _showSnack(
        'Recording started. Tap stop when the doctor finishes.',
        AppColors.primaryBlue,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not start recording: $e', AppColors.dangerRed);
    }
  }

  Future<void> _stopVoiceRecording() async {
    try {
      final path = await AlarmAudioService.instance.stopRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        if (path != null && path.isNotEmpty) {
          _existingAudioPath = path;
        }
      });
      if (path != null && path.isNotEmpty) {
        _showSnack('Doctor voice note saved.', AppColors.successGreen);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRecording = false);
      _showSnack('Could not stop recording: $e', AppColors.dangerRed);
    }
  }

  Future<void> _toggleAudioPreview() async {
    final audioPath = _existingAudioPath;
    if (audioPath == null || audioPath.isEmpty) return;

    try {
      if (_isPlayingAudio) {
        await AlarmAudioService.instance.stopPlayback();
        if (!mounted) return;
        setState(() => _isPlayingAudio = false);
        return;
      }

      await AlarmAudioService.instance.stopPlayback();
      await AlarmAudioService.instance.playRecording(audioPath);
      if (!mounted) return;
      setState(() => _isPlayingAudio = true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not play recording: $e', AppColors.dangerRed);
    }
  }

  void _removeAudio() {
    AlarmAudioService.instance.stopPlayback();
    setState(() {
      _existingAudioPath = null;
      _isPlayingAudio = false;
      _isRecording = false;
    });
  }

  // ══════════════════════════════════════════════════════
  //  SAVE — only this method changed
  // ══════════════════════════════════════════════════════
  Future<void> _saveMedication() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_selectedColor == null) {
      _showSnack('Please select a pill color', AppColors.warningOrange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now().toIso8601String();
      final photoPath = _pillPhoto?.path ?? _existingPhotoPath;

      final data = {
        DBConstants.medPatientId: widget.patientId,
        DBConstants.medName: _nameController.text.trim(),
        DBConstants.medDosage: _dosageController.text.trim(),
        DBConstants.medDosageUnit: _selectedUnit,
        DBConstants.medFrequency: _selectedFrequency,
        DBConstants.medInstructions: _instructionsController.text.trim(),
        DBConstants.medPillColor: _selectedColor,
        DBConstants.medPillShape: _selectedShape,
        DBConstants.medPillPhoto: photoPath,
        DBConstants.medAudioPath: _existingAudioPath,
        DBConstants.medStartDate: now.substring(0, 10),
        DBConstants.medIsActive: 1,
        DBConstants.medUpdatedAt: now,
      };

      int medId;

      if (_isEditing) {
        medId = widget.existingMedication![DBConstants.medId] as int;
        await _db.updateMedication(medId, data);

        // Cancel old alarms before rescheduling
        await NotificationService.instance.cancelMedicineReminders(
          medicationId: medId,
          slotCount: 10,
        );

        debugPrint('✅ MED UPDATED: ${_nameController.text}');
      } else {
        data[DBConstants.medCreatedAt] = now;
        medId = await _db.insertMedication(data);
        debugPrint(
          '✅ MED CREATED: ${_nameController.text} '
          '(ID: $medId)',
        );
      }

      // Save time slots to DB
      await _db.deleteSchedulesByMedication(medId);
      for (final time in _timeslots) {
        final timeStr = '${time.hour.toString().padLeft(2, '0')}:'
            '${time.minute.toString().padLeft(2, '0')}';
        await _db.insertSchedule({
          DBConstants.schedMedId: medId,
          DBConstants.schedPatientId: widget.patientId,
          DBConstants.schedTime: timeStr,
          DBConstants.schedDays: '1,2,3,4,5,6,7',
          DBConstants.schedIsEnabled: 1,
          DBConstants.schedCreatedAt: now,
        });
      }

      // ── Schedule alarms ← NEW ──────────────────────
      await NotificationService.instance.scheduleAllReminders(
        patientId: widget.patientId,
        medicationId: medId,
        medicineName: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        unit: _selectedUnit,
        timeSlots: _timeslots,
      );

      if (!mounted) return;
      _showSnack(
        _isEditing ? '✅ Medicine updated!' : '✅ Medicine added!',
        AppColors.successGreen,
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ SAVE MED ERROR: $e');
      if (!mounted) return;
      _showSnack('Error: $e', AppColors.dangerRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() => _pillPhoto = File(picked.path));
      }
    } catch (e) {
      debugPrint('❌ PHOTO ERROR: $e');
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            const Text('Add Pill Photo',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: AppDimensions.lg),
            _photoOption(
              icon: Icons.camera_alt,
              label: 'Take Photo',
              color: AppColors.primaryBlue,
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: AppDimensions.md),
            _photoOption(
              icon: Icons.photo_library,
              label: 'Choose from Gallery',
              color: AppColors.successGreen,
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_pillPhoto != null || _existingPhotoPath != null) ...[
              const SizedBox(height: AppDimensions.md),
              _photoOption(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                color: AppColors.dangerRed,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _pillPhoto = null;
                    _existingPhotoPath = null;
                  });
                },
              ),
            ],
            const SizedBox(height: AppDimensions.md),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textSecondary,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: AppDimensions.md),
                Text(label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color,
                    )),
              ],
            ),
          ),
        ),
      );

  Future<void> _addTimeSlot() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) setState(() => _timeslots.add(picked));
  }

  void _removeTimeSlot(int index) {
    if (_timeslots.length > 1) {
      setState(() => _timeslots.removeAt(index));
    }
  }

  Future<void> _editTimeSlot(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeslots[index],
    );
    if (picked != null) {
      setState(() => _timeslots[index] = picked);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primaryBlue,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _isEditing ? 'Edit Medicine' : 'Add Medicine',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(32),
            child: Container(
              padding: const EdgeInsets.only(
                left: AppDimensions.lg,
                bottom: AppDimensions.sm,
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                'For: ${widget.patientName}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCard(
                  title: 'Medicine Details',
                  icon: Icons.medication_outlined,
                  children: [
                    _buildLabel('Medicine Name *'),
                    const SizedBox(height: AppDimensions.sm),
                    TextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                      style:
                          const TextStyle(fontFamily: 'Poppins', fontSize: 15),
                      decoration: _inputDeco(
                        hint: 'e.g. Paracetamol',
                        icon: Icons.medication_outlined,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter medicine name'
                          : null,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Row(children: [
                      Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Dosage *'),
                              const SizedBox(height: AppDimensions.sm),
                              TextFormField(
                                controller: _dosageController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp('[0-9.]')),
                                ],
                                style: const TextStyle(
                                    fontFamily: 'Poppins', fontSize: 15),
                                decoration: _inputDeco(
                                  hint: 'e.g. 500',
                                  icon: Icons.scale_outlined,
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ],
                          )),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Unit'),
                              const SizedBox(height: AppDimensions.sm),
                              DropdownButtonFormField<String>(
                                value: _selectedUnit,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: _inputDeco(
                                    hint: 'Unit', icon: Icons.straighten),
                                items: _units
                                    .map((u) => DropdownMenuItem(
                                        value: u, child: Text(u)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedUnit = v!),
                              ),
                            ],
                          )),
                    ]),
                    const SizedBox(height: AppDimensions.md),
                    _buildLabel('Frequency'),
                    const SizedBox(height: AppDimensions.sm),
                    DropdownButtonFormField<String>(
                      value: _selectedFrequency,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      decoration:
                          _inputDeco(hint: 'How often?', icon: Icons.repeat),
                      items: _frequencies
                          .map(
                              (f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedFrequency = v!),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _buildLabel('Instructions'),
                    const SizedBox(height: AppDimensions.sm),
                    TextFormField(
                      controller: _instructionsController,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      style:
                          const TextStyle(fontFamily: 'Poppins', fontSize: 15),
                      decoration: _inputDeco(
                        hint: 'e.g. Take with food and water',
                        icon: Icons.notes_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.lg),
                _buildCard(
                  title: 'Reminder Times',
                  icon: Icons.access_time,
                  children: [
                    ..._timeslots.asMap().entries.map((entry) {
                      final i = entry.key;
                      final time = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppDimensions.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.05),
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(
                            color: AppColors.primaryBlue.withOpacity(0.2),
                          ),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.access_time,
                              color: AppColors.primaryBlue),
                          title: Text(time.format(context),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryBlue,
                              )),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.primaryBlue,
                                  size: 20,
                                ),
                                onPressed: () => _editTimeSlot(i),
                              ),
                              if (_timeslots.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: AppColors.dangerRed,
                                    size: 20,
                                  ),
                                  onPressed: () => _removeTimeSlot(i),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: AppDimensions.sm),
                    OutlinedButton.icon(
                      onPressed: _addTimeSlot,
                      icon: const Icon(Icons.add, color: AppColors.primaryBlue),
                      label: const Text('Add Another Time',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600,
                          )),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.lg),
                _buildCard(
                  title: 'Pill Appearance',
                  icon: Icons.palette_outlined,
                  children: [
                    _buildLabel('Shape'),
                    const SizedBox(height: AppDimensions.sm),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _shapes.length,
                        itemBuilder: (context, index) {
                          final shape = _shapes[index];
                          final isSelected = _selectedShape == shape['value'];
                          return GestureDetector(
                            onTap: () => setState(() =>
                                _selectedShape = shape['value'] as String),
                            child: Container(
                              margin: const EdgeInsets.only(
                                  right: AppDimensions.sm),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.md,
                                vertical: AppDimensions.sm,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMd),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryBlue
                                      : Colors.grey.shade300,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primaryBlue
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(shape['icon'] as IconData,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      size: 24),
                                  const SizedBox(height: 4),
                                  Text(shape['label'] as String,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      )),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _buildLabel('Pill Color *'),
                    const SizedBox(height: AppDimensions.sm),
                    Wrap(
                      spacing: AppDimensions.sm,
                      runSpacing: AppDimensions.sm,
                      children: _colors.map((c) {
                        final isSelected = _selectedColor == c['value'];
                        final color = c['color'] as Color;
                        return GestureDetector(
                          onTap: () => setState(
                              () => _selectedColor = c['value'] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : Colors.grey.shade300,
                                width: isSelected ? 3 : 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _buildLabel('Pill Photo (Optional)'),
                    const SizedBox(height: AppDimensions.sm),
                    GestureDetector(
                      onTap: _showPhotoOptions,
                      child: Container(
                        width: double.infinity,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(color: Colors.grey.shade300),
                          image: _pillPhoto != null
                              ? DecorationImage(
                                  image: FileImage(_pillPhoto!),
                                  fit: BoxFit.cover)
                              : _existingPhotoPath != null
                                  ? DecorationImage(
                                      image:
                                          FileImage(File(_existingPhotoPath!)),
                                      fit: BoxFit.cover)
                                  : null,
                        ),
                        child:
                            (_pillPhoto == null && _existingPhotoPath == null)
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined,
                                          color: Colors.grey.shade400,
                                          size: 32),
                                      const SizedBox(height: 6),
                                      Text('Tap to add pill photo',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 13,
                                            color: Colors.grey.shade400,
                                          )),
                                    ],
                                  )
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.lg),
                _buildCard(
                  title: 'Doctor Voice Reminder',
                  icon: Icons.mic_none_rounded,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                        border: Border.all(
                          color: AppColors.successGreen.withOpacity(0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _existingAudioPath?.isNotEmpty == true
                                ? 'Recorded prescription ready'
                                : 'Record the doctor saying when to take this medicine.',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          Text(
                            'This voice note will play after the reminder alarm.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.md),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isRecording
                                      ? _stopVoiceRecording
                                      : _startVoiceRecording,
                                  icon: Icon(
                                    _isRecording ? Icons.stop : Icons.mic,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    _isRecording
                                        ? 'Stop Recording'
                                        : 'Record Voice',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isRecording
                                        ? AppColors.dangerRed
                                        : AppColors.primaryBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMd,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppDimensions.sm),
                              IconButton.filledTonal(
                                onPressed:
                                    _existingAudioPath?.isNotEmpty == true
                                        ? _toggleAudioPreview
                                        : null,
                                icon: Icon(
                                  _isPlayingAudio
                                      ? Icons.stop_circle
                                      : Icons.play_arrow,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton.filledTonal(
                                onPressed:
                                    _existingAudioPath?.isNotEmpty == true
                                        ? _removeAudio
                                        : null,
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.xl),
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonLarge,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveMedication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save_outlined,
                                  color: Colors.white, size: 22),
                              const SizedBox(width: AppDimensions.sm),
                              Text(
                                _isEditing
                                    ? 'UPDATE MEDICINE'
                                    : 'SAVE MEDICINE',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: AppDimensions.xl),
              ],
            ),
          ),
        ),
      );

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) =>
      Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.primaryBlue, size: 20),
              const SizedBox(width: AppDimensions.sm),
              Text(title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
            ]),
            const SizedBox(height: AppDimensions.md),
            const Divider(height: 1),
            const SizedBox(height: AppDimensions.md),
            ...children,
          ],
        ),
      );

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ));

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'Poppins',
          color: Colors.grey.shade400,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: AppColors.primaryBlue, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.dangerRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.dangerRed, width: 2),
        ),
      );

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),
    );
  }
}
