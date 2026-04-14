// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_constants.dart';

class AddPatientScreen extends StatefulWidget {
  final Map<String, dynamic>? existingPatient;

  const AddPatientScreen({
    Key? key,
    this.existingPatient,
  }) : super(key: key);

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  // ── Form ─────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ──────────────────────────────────────────
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _wardController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  // ── State ────────────────────────────────────────────────
  String? _selectedGender;
  String _selectedLanguage = 'lg';
  bool _isLoading = false;
  File? _selectedPhoto;
  String? _existingPhotoPath;
  bool _isDevicePatient = false;
  bool get _isEditing => widget.existingPatient != null;

  // ── Image Picker ─────────────────────────────────────────
  final _imagePicker = ImagePicker();

  // ── Language options ─────────────────────────────────────
  final List<Map<String, String>> _languages = [
    {'code': 'lg', 'name': 'Luganda'},
    {'code': 'en', 'name': 'English'},
    {'code': 'sw', 'name': 'Swahili'},
    {'code': 'ac', 'name': 'Acholi'},
    {'code': 'rn', 'name': 'Runyankole'},
    {'code': 'at', 'name': 'Ateso'},
  ];

  // ── Database ─────────────────────────────────────────────
  final _db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _prefillFields();
  }

  // ── Prefill when editing ─────────────────────────────────
  void _prefillFields() {
    final p = widget.existingPatient!;
    _nameController.text = p[DBConstants.patientFullName] ?? '';
    _ageController.text =
        p[DBConstants.patientAge]?.toString() ?? '';
    _wardController.text = p[DBConstants.patientWard] ?? '';
    _phoneController.text = p[DBConstants.patientAlertPhone] ?? '';
    _notesController.text = p[DBConstants.patientNotes] ?? '';
    _selectedGender = p[DBConstants.patientGender];
    _selectedLanguage = p[DBConstants.patientLanguage] ?? 'lg';
    _existingPhotoPath = p[DBConstants.patientPhoto];
    _isDevicePatient =
        (p[DBConstants.patientIsDevicePatient] ?? 0) == 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _wardController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Pick photo ───────────────────────────────────────────
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _selectedPhoto = File(picked.path));
        debugPrint('✅ PHOTO: Selected ${picked.path}');
      }
    } catch (e) {
      debugPrint('❌ PHOTO ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not access photo: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: AppColors.dangerRed,
          ),
        );
      }
    }
  }

  // ── Show photo options ───────────────────────────────────
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
            const Text(
              'Add Patient Photo',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            _buildPhotoOption(
              icon: Icons.camera_alt,
              label: 'Take Photo',
              sublabel: 'Use camera to take a photo now',
              color: AppColors.primaryBlue,
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: AppDimensions.md),
            _buildPhotoOption(
              icon: Icons.photo_library,
              label: 'Choose from Gallery',
              sublabel: 'Pick an existing photo',
              color: AppColors.successGreen,
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_selectedPhoto != null ||
                _existingPhotoPath != null) ...[
              const SizedBox(height: AppDimensions.md),
              _buildPhotoOption(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                sublabel: 'Use initials instead',
                color: AppColors.dangerRed,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedPhoto = null;
                    _existingPhotoPath = null;
                  });
                },
              ),
            ],
            const SizedBox(height: AppDimensions.lg),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Photo option row ─────────────────────────────────────
  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      sublabel,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: color.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Save Patient ─────────────────────────────────────────
  Future<void> _savePatient() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now().toIso8601String();
      final photoPath = _selectedPhoto?.path ?? _existingPhotoPath;

      final data = {
        DBConstants.patientFullName: _nameController.text.trim(),
        DBConstants.patientAge: _ageController.text.isNotEmpty
            ? int.tryParse(_ageController.text)
            : null,
        DBConstants.patientGender: _selectedGender,
        DBConstants.patientWard: _wardController.text.trim(),
        DBConstants.patientAlertPhone: _phoneController.text.trim(),
        DBConstants.patientNotes: _notesController.text.trim(),
        DBConstants.patientLanguage: _selectedLanguage,
        DBConstants.patientPhoto: photoPath,
        
        DBConstants.patientIsDevicePatient: 0,
        DBConstants.patientIsActive: 1,
        DBConstants.patientUpdatedAt: now,
      };

      if (_isEditing) {
        final id =
            widget.existingPatient![DBConstants.patientId] as int;
        await _db.updatePatient(id, data);
        debugPrint('✅ PATIENT UPDATED: ${_nameController.text}');
      } else {
        data[DBConstants.patientCreatedAt] = now;
        final id = await _db.insertPatient(data);
        await _db.setCurrentPatient(id);
        debugPrint(
            '✅ PATIENT CREATED: ${_nameController.text} (ID: $id)');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? '✅ Profile updated!'
                : '✅ Patient profile created!',
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusMd),
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ SAVE PATIENT ERROR: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
    @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Patient' : 'Add New Patient',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
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
              // ── Photo Section ────────────────────────
              _buildPhotoSection(),

              const SizedBox(height: AppDimensions.xl),

              // ── Basic Info Card ──────────────────────
              _buildSectionCard(
                title: 'Basic Information',
                icon: Icons.person_outline,
                children: [
                  _buildLabel('Full Name *'),
                  const SizedBox(height: AppDimensions.sm),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                    ),
                    decoration: _inputDeco(
                      hint: 'e.g. Sarah Nakato',
                      icon: Icons.person_outline,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter patient name';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppDimensions.md),

                  // Age + Gender
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Age'),
                            const SizedBox(height: AppDimensions.sm),
                            TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter
                                    .digitsOnly,
                              ],
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                              ),
                              decoration: _inputDeco(
                                hint: 'Age',
                                icon: Icons.cake_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Gender'),
                            const SizedBox(height: AppDimensions.sm),
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                              decoration: _inputDeco(
                                hint: 'Select',
                                icon: Icons.people_outline,
                              ),
                              items: ['Male', 'Female', 'Other']
                                  .map((g) => DropdownMenuItem(
                                        value: g,
                                        child: Text(g),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(
                                  () => _selectedGender = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.md),

                  _buildLabel('Ward / Location'),
                  const SizedBox(height: AppDimensions.sm),
                  TextFormField(
                    controller: _wardController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                    ),
                    decoration: _inputDeco(
                      hint: 'e.g. Ward 3, Outpatient',
                      icon: Icons.local_hospital_outlined,
                    ),
                  ),

                  const SizedBox(height: AppDimensions.md),

                  _buildLabel('Preferred Language'),
                  const SizedBox(height: AppDimensions.sm),
                  DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    decoration: _inputDeco(
                      hint: 'Select language',
                      icon: Icons.language,
                    ),
                    items: _languages
                        .map((l) => DropdownMenuItem(
                              value: l['code'],
                              child: Text(l['name']!),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedLanguage = v!),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.lg),

              
              const SizedBox(height: AppDimensions.lg),

              // ── SMS Alert Card ───────────────────────
              _buildSectionCard(
                title: 'SMS Alert Contact',
                icon: Icons.sms_outlined,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd),
                      border: Border.all(
                        color:
                            AppColors.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.primaryBlue,
                          size: 18,
                        ),
                        const SizedBox(width: AppDimensions.sm),
                        Expanded(
                          child: Text(
                            'SMS sent here if patient misses a dose.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: AppColors.primaryBlue
                                  .withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  _buildLabel('Phone Number *'),
                  const SizedBox(height: AppDimensions.sm),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                    ),
                    decoration: _inputDeco(
                      hint: 'e.g. 0771234567',
                      icon: Icons.phone_outlined,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter alert phone number';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.lg),

              // ── Medical Notes Card ───────────────────
              _buildSectionCard(
                title: 'Medical Notes',
                icon: Icons.notes_outlined,
                children: [
                  _buildLabel('Notes (Optional)'),
                  const SizedBox(height: AppDimensions.sm),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Any important medical notes...',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMd),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMd),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMd),
                        borderSide: const BorderSide(
                          color: AppColors.primaryBlue,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.xl),

              // ── Save Button ──────────────────────────
              SizedBox(
                width: double.infinity,
                height: AppDimensions.buttonLarge,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePatient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd),
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
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.save_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: AppDimensions.sm),
                            Text(
                              _isEditing
                                  ? 'UPDATE PROFILE'
                                  : 'SAVE PATIENT PROFILE',
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
  }

  // ── Photo Section ────────────────────────────────────────
  Widget _buildPhotoSection() {
    final name = _nameController.text;
    final initial =
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showPhotoOptions,
            child: Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(55),
                    border: Border.all(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      width: 2,
                    ),
                    image: _selectedPhoto != null
                        ? DecorationImage(
                            image: FileImage(_selectedPhoto!),
                            fit: BoxFit.cover,
                          )
                        : _existingPhotoPath != null
                            ? DecorationImage(
                                image: FileImage(
                                  File(_existingPhotoPath!),
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                  ),
                  child: (_selectedPhoto == null &&
                          _existingPhotoPath == null)
                      ? Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Tap to add photo',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Card ─────────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
          Row(
            children: [
              Icon(icon, color: AppColors.primaryBlue, size: 20),
              const SizedBox(width: AppDimensions.sm),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          const Divider(height: 1),
          const SizedBox(height: AppDimensions.md),
          ...children,
        ],
      ),
    );
  }

  // ── Label ────────────────────────────────────────────────
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ── Input decoration ─────────────────────────────────────
  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
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
        borderSide: const BorderSide(
          color: AppColors.primaryBlue,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppColors.dangerRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(
          color: AppColors.dangerRed,
          width: 2,
        ),
      ),
    );
  }
}