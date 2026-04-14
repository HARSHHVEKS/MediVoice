// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {

  // ── PIN Controller ───────────────────────────────────────
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  // ── State ────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;
  static const int _maxAttempts = 5;

  // ── Shake animation ──────────────────────────────────────
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // ── Database ─────────────────────────────────────────────
  final _db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _setupShakeAnimation();
  }

  void _setupShakeAnimation() {
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.elasticIn,
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Verify Admin PIN ─────────────────────────────────────
  Future<void> _handleVerify(String pin) async {
    if (pin.length != 6) return;

    if (_failedAttempts >= _maxAttempts) {
      setState(() {
        _errorMessage =
            'Too many failed attempts. Please contact hospital IT.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get stored admin PIN from settings
      final storedPin = await _db.getSetting('admin_pin');

      if (!mounted) return;

      if (storedPin == null) {
        setState(() {
          _errorMessage = 'Admin PIN not configured.';
          _isLoading = false;
        });
        return;
      }

      if (pin == storedPin) {
        // PIN correct
        debugPrint('✅ ADMIN LOGIN: Success');
        _failedAttempts = 0;
        _showSuccess();
      } else {
        // PIN wrong
        debugPrint('❌ ADMIN LOGIN: Wrong PIN');
        _failedAttempts++;
        _pinController.clear();
        _shakeController.forward(from: 0);

        setState(() {
          _errorMessage = _failedAttempts >= _maxAttempts
              ? 'Too many failed attempts. Contact hospital IT.'
              : 'Incorrect PIN. '
                  '${_maxAttempts - _failedAttempts} attempts remaining.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ ADMIN LOGIN ERROR: $e');
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  // Temporary success — admin dashboard coming later
  void _showSuccess() {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '✅ Admin access granted!',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: AppColors.successGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.adminNavy,
              Color(0xFF1A2E4A),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Column(
              children: [
                const SizedBox(height: AppDimensions.xl),

                // ── Header ──────────────────────────────
                _buildHeader(),

                const SizedBox(height: AppDimensions.xxl),

                // ── PIN Card ─────────────────────────────
                _buildPinCard(),

                const SizedBox(height: AppDimensions.lg),

                // ── Hint ─────────────────────────────────
                _buildHint(),
              ],
            ),
          ),
        ),
      ),
    );

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader() => Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(45),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.admin_panel_settings,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppDimensions.lg),
        const Text(
          'Hospital Admin',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your 6-digit admin PIN',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );

  // ── PIN Card ─────────────────────────────────────────────
  Widget _buildPinCard() {
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 60,
      textStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.adminNavy,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.5,
        ),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(
          color: AppColors.adminNavy,
          width: 2.5,
        ),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(
          color: AppColors.dangerRed,
          width: 2,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) => Transform.translate(
          offset: Offset(
            _shakeController.isAnimating
                ? (_shakeAnimation.value *
                    (_shakeController.value < 0.5 ? 1 : -1))
                : 0,
            0,
          ),
          child: child,
        ),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.xl),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Error
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                    color: AppColors.dangerRed.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.dangerRed,
                      size: 20,
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppColors.dangerRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
            ],

            // PIN Input
            Pinput(
              controller: _pinController,
              focusNode: _pinFocusNode,
              length: 6,
              obscureText: true,
              obscuringCharacter: '●',
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              errorPinTheme: errorPinTheme,
              onCompleted: _handleVerify,
            ),

            const SizedBox(height: AppDimensions.xl),

            // Verify Button
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonStandard,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () => _handleVerify(_pinController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adminNavy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMd,
                    ),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'VERIFY PIN',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Default PIN hint ─────────────────────────────────────
  Widget _buildHint() => Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.lg,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Text(
            'Default PIN: 123456',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
}