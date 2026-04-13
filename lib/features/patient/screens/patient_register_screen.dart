// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/auth_service.dart';

class PatientRegisterScreen extends StatefulWidget {
  const PatientRegisterScreen({super.key});

  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends State<PatientRegisterScreen> {
  // ── Form & Page Control ──────────────────────────────────
  final _pageController = PageController();
  int _currentPage = 0;

  // ── Form Keys ────────────────────────────────────────────
  final _infoFormKey = GlobalKey<FormState>();

  // ── Controllers ──────────────────────────────────────────
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();

  // ── State ────────────────────────────────────────────────
  String? _selectedGender;
  String _selectedLanguage = 'lg';
  String _enteredPin = '';
  String _confirmPin = '';
  bool _isLoading = false;
  bool _isPinConfirmStep = false;
  String? _errorMessage;

  // ── Auth Service ─────────────────────────────────────────
  final _auth = AuthService.instance;

  // ── Language Options ─────────────────────────────────────
  final List<Map<String, String>> _languages = [
    {'code': 'lg', 'name': 'Luganda'},
    {'code': 'en', 'name': 'English'},
    {'code': 'sw', 'name': 'Swahili'},
    {'code': 'ac', 'name': 'Acholi'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Page Navigation ──────────────────────────────────────
  void _nextPage() {
    if (_currentPage == 0) {
      if (!_infoFormKey.currentState!.validate()) return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentPage++;
      _errorMessage = null;
    });
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentPage--;
      _errorMessage = null;
      _enteredPin = '';
      _confirmPin = '';
      _isPinConfirmStep = false;
    });
  }

  // ── PIN Entry ────────────────────────────────────────────
  void _onNumberTapped(String number) {
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      if (!_isPinConfirmStep) {
        if (_enteredPin.length < 4) {
          _enteredPin += number;
          // Move to confirm step
          if (_enteredPin.length == 4) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() => _isPinConfirmStep = true);
              }
            });
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += number;
          // Auto submit when confirm PIN complete
          if (_confirmPin.length == 4) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _validateAndRegister();
            });
          }
        }
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      if (!_isPinConfirmStep) {
        if (_enteredPin.isNotEmpty) {
          _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          // Go back to first PIN entry
          _isPinConfirmStep = false;
          _enteredPin = '';
        }
      }
    });
  }

  // ── Register ─────────────────────────────────────────────
  Future<void> _validateAndRegister() async {
    // Check PINs match
    if (_enteredPin != _confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match. Try again.';
        _confirmPin = '';
        _enteredPin = '';
        _isPinConfirmStep = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _auth.registerPatient(
        fullName: _nameController.text.trim(),
        pin: _enteredPin,
        alertPhone: _phoneController.text.trim(),
        age: _ageController.text.isNotEmpty
            ? int.tryParse(_ageController.text)
            : null,
        gender: _selectedGender,
        language: _selectedLanguage,
      );

      if (!mounted) return;

      if (result.success) {
        debugPrint('✅ PATIENT REGISTERED: ${result.userName}');
        Navigator.pushReplacementNamed(context, '/patient-home');
      } else {
        setState(() {
          _errorMessage = result.message;
          _enteredPin = '';
          _confirmPin = '';
          _isPinConfirmStep = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ REGISTER ERROR: $e');
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

    @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
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
              // ── Top Bar ───────────────────────────────
              _buildTopBar(),

              // ── Progress Indicator ────────────────────
              _buildProgressBar(),

              // ── Pages ─────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildInfoPage(size),
                    _buildPinPage(size),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────────
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
            onPressed: () {
              if (_currentPage > 0) {
                _prevPage();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const Spacer(),
          const Text(
            'Create Profile',
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

  // ── Progress Bar ─────────────────────────────────────────
  Widget _buildProgressBar() => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.xl,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: List.generate(2, (index) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 4,
              decoration: BoxDecoration(
                color: index <= _currentPage
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );

  // ── Page 1 — Patient Info ────────────────────────────────
  Widget _buildInfoPage(Size size) => SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Form(
        key: _infoFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimensions.md),

            // Header
            const Text(
              'Tell us about you',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fill in your details below',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.white.withOpacity(0.75),
              ),
            ),

            const SizedBox(height: AppDimensions.xl),

            // ── White Card ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppDimensions.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  AppDimensions.radiusXl,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Name
                  _buildLabel('Full Name *'),
                  const SizedBox(height: AppDimensions.sm),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
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
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppDimensions.md),

                  // Age
                  _buildLabel('Age'),
                  const SizedBox(height: AppDimensions.sm),
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
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

                  const SizedBox(height: AppDimensions.md),

                  // Gender
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
                      hint: 'Select gender (optional)',
                      icon: Icons.person_outline,
                    ),
                    items: ['Male', 'Female', 'Other']
                        .map((g) => DropdownMenuItem(
                              value: g,
                              child: Text(g),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedGender = v),
                  ),

                  const SizedBox(height: AppDimensions.md),

                  // Language
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

                  const SizedBox(height: AppDimensions.md),

                  // Alert Phone
                  _buildLabel('Alert Phone Number *'),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'SMS will be sent here if you miss a dose',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
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
                        return 'Please enter an alert phone number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.xl),

            // Next Button
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonStandard,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMd,
                    ),
                  ),
                ),
                child: const Text(
                  'NEXT — Set Your PIN',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.successGreen,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppDimensions.lg),
          ],
        ),
      ),
    );

  // ── Page 2 — PIN Setup ───────────────────────────────────
  Widget _buildPinPage(Size size) {
    final currentPin =
        _isPinConfirmStep ? _confirmPin : _enteredPin;

    return Column(
      children: [
        const SizedBox(height: AppDimensions.xl),

        // Header
        Text(
          _isPinConfirmStep ? 'Confirm Your PIN' : 'Set Your PIN',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isPinConfirmStep
              ? 'Enter your PIN again to confirm'
              : 'Choose a 4-digit PIN you will remember',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
          ),
        ),

        const SizedBox(height: AppDimensions.xl),

        // PIN Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final filled = index < currentPin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 2,
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: AppDimensions.md),

        // Error
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppDimensions.xl,
            ),
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withOpacity(0.5),
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),

        const Spacer(),

        // Loading or Number Pad
        if (_isLoading) const CircularProgressIndicator(color: Colors.white) else _buildNumberPad(),

        const SizedBox(height: AppDimensions.xl),
      ],
    );
  }

  // ── Number Pad ───────────────────────────────────────────
  Widget _buildNumberPad() => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.xl,
      ),
      child: Column(
        children: [
          _buildNumRow(['1', '2', '3']),
          const SizedBox(height: AppDimensions.md),
          _buildNumRow(['4', '5', '6']),
          const SizedBox(height: AppDimensions.md),
          _buildNumRow(['7', '8', '9']),
          const SizedBox(height: AppDimensions.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 80, height: 80),
              _buildNumBtn('0'),
              _buildBackspaceBtn(),
            ],
          ),
        ],
      ),
    );

  Widget _buildNumRow(List<String> nums) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: nums.map((n) => _buildNumBtn(n)).toList(),
    );

  Widget _buildNumBtn(String number) => GestureDetector(
      onTap: () => _onNumberTapped(number),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );

  Widget _buildBackspaceBtn() => GestureDetector(
      onTap: _onBackspace,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );

  // ── Helpers ──────────────────────────────────────────────
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
  }) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: 'Poppins',
        color: Colors.grey.shade400,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: AppColors.successGreen),
    );
}