// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_constants.dart';

class PatientRegisterScreen extends StatefulWidget {
  const PatientRegisterScreen({super.key});

  @override
  State<PatientRegisterScreen> createState() =>
      _PatientRegisterScreenState();
}

class _PatientRegisterScreenState
    extends State<PatientRegisterScreen> {
  // ── Form ───────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ────────────────────────────────────────
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();

  // ── State ──────────────────────────────────────────────
  String? _selectedGender;
  String _selectedLanguage = 'lg';
  bool _isLoading = false;
  File? _selectedPhoto;

  // ── Image Picker ───────────────────────────────────────
  final _imagePicker = ImagePicker();

  // ── Database ───────────────────────────────────────────
  final _db = DatabaseHelper.instance;

  // ── Language options ───────────────────────────────────
  final List<Map<String, String>> _languages = [
    {'code': 'lg', 'name': 'Luganda'},
    {'code': 'en', 'name': 'English'},
    {'code': 'sw', 'name': 'Swahili'},
    {'code': 'ac', 'name': 'Acholi'},
    {'code': 'rn', 'name': 'Runyankole'},
    {'code': 'at', 'name': 'Ateso'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Pick photo ─────────────────────────────────────────
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
      }
    } catch (e) {
      debugPrint('❌ PHOTO ERROR: $e');
    }
  }

  // ── Photo options sheet ────────────────────────────────
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
              'Add Your Photo',
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
              color: AppColors.successGreen,
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: AppDimensions.lg),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
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

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(AppDimensions.radiusLg),
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
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );

  // ── Save patient profile ───────────────────────────────
  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now().toIso8601String();

      final patientId = await _db.insertPatient({
      DBConstants.patientFullName: _nameController.text.trim(),
      DBConstants.patientAge: _ageController.text.isNotEmpty
          ? int.tryParse(_ageController.text)
          : null,
      DBConstants.patientGender: _selectedGender,
      DBConstants.patientLanguage: _selectedLanguage,
      DBConstants.patientAlertPhone:
          _phoneController.text.trim(),
      DBConstants.patientPhoto: _selectedPhoto?.path,
      DBConstants.patientWard: '',
      DBConstants.patientNotes: '',
      DBConstants.patientIsDevicePatient: 1,
      DBConstants.patientIsActive: 1,
      DBConstants.patientCreatedAt: now,
      DBConstants.patientUpdatedAt: now,
    });

      // Save as current patient — stays forever
      await _db.setCurrentPatient(patientId);

      debugPrint(
        '✅ PATIENT CREATED: ${_nameController.text} '
        '(ID: $patientId)',
      );

      if (!mounted) return;

      // Go straight to patient home — no login ever again
      Navigator.pushReplacementNamed(context, '/patient-home');
    } catch (e) {
      debugPrint('❌ SAVE PROFILE ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving profile: $e',
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
  Widget build(BuildContext context) => Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF43A047),
              Color(0xFF2E7D32),
              Color(0xFF1B5E20),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Bar ──────────────────────────────
              _buildTopBar(),

              // ── Scrollable Form ───────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Header
                        const Text(
                          'Create Your Profile',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Only done once — your profile stays saved',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),

                        const SizedBox(height: AppDimensions.xl),

                        // ── Photo ─────────────────────
                        _buildPhotoSection(),

                        const SizedBox(height: AppDimensions.xl),

                        // ── White Card ────────────────
                        Container(
                          padding: const EdgeInsets.all(
                            AppDimensions.lg,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusXl,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Full Name
                              _buildLabel('Full Name *'),
                              const SizedBox(
                                  height: AppDimensions.sm),
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                keyboardType: TextInputType.name,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                ),
                                decoration: _inputDeco(
                                  hint: 'Enter your full name',
                                  icon: Icons.person_outline,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Phone number is required for missed dose alerts';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(
                                  height: AppDimensions.md),

                              // Age
                              _buildLabel('Age'),
                              const SizedBox(
                                  height: AppDimensions.sm),
                              TextFormField(
                                controller: _ageController,
                                keyboardType:
                                    TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .digitsOnly,
                                ],
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                ),
                                decoration: _inputDeco(
                                  hint: 'Your age (optional)',
                                  icon: Icons.cake_outlined,
                                ),
                              ),

                              const SizedBox(
                                  height: AppDimensions.md),

                              // Gender
                              _buildLabel('Gender'),
                              const SizedBox(
                                  height: AppDimensions.sm),
                              DropdownButtonFormField<String>(
                                value: _selectedGender,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: _inputDeco(
                                  hint: 'Select (optional)',
                                  icon: Icons.people_outline,
                                ),
                                items: ['Male', 'Female', 'Other']
                                    .map(
                                      (g) => DropdownMenuItem(
                                        value: g,
                                        child: Text(g),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(
                                    () => _selectedGender = v),
                              ),

                              const SizedBox(
                                  height: AppDimensions.md),

                              // Language
                              _buildLabel('Preferred Language'),
                              const SizedBox(
                                  height: AppDimensions.sm),
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
                                    .map(
                                      (l) => DropdownMenuItem(
                                        value: l['code'],
                                        child: Text(l['name']!),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(
                                    () => _selectedLanguage = v!),
                              ),

                              const SizedBox(
                                  height: AppDimensions.md),

                              // Alert Phone
                              _buildLabel(
                                  'Emergency Contact Number'),
                              const SizedBox(height: 4),
                              Text(
                                'SMS sent here if you miss a dose',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(
                                  height: AppDimensions.sm),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType:
                                    TextInputType.phone,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                ),
                                decoration: _inputDeco(
                                  hint: 'e.g. 0771234567',
                                  icon: Icons.phone_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppDimensions.xl),

                        // ── Save Button ───────────────
                        SizedBox(
                          width: double.infinity,
                          height: AppDimensions.buttonLarge,
                          child: ElevatedButton(
                            onPressed:
                                _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMd,
                                ),
                              ),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child:
                                        CircularProgressIndicator(
                                      color:
                                          AppColors.successGreen,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'SAVE & CONTINUE',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.successGreen,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: AppDimensions.xl),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

  // ── Top Bar ────────────────────────────────────────────
  Widget _buildTopBar() => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.sm,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const Spacer(),
            const Text(
              'New Profile',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 48),
          ],
        ),
      );

  // ── Photo Section ──────────────────────────────────────
  Widget _buildPhotoSection() {
    final name = _nameController.text;
    final initial = name.isNotEmpty
        ? name.substring(0, 1).toUpperCase()
        : '?';

    return Center(
      child: GestureDetector(
        onTap: _showPhotoOptions,
        child: Stack(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(55),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 3,
                ),
                image: _selectedPhoto != null
                    ? DecorationImage(
                        image: FileImage(_selectedPhoto!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _selectedPhoto == null
                  ? Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: AppColors.successGreen,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: AppColors.successGreen,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────
  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );

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
        prefixIcon:
            Icon(icon, color: AppColors.successGreen, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.successGreen,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusMd),
          borderSide:
              const BorderSide(color: AppColors.dangerRed),
        ),
      );
}