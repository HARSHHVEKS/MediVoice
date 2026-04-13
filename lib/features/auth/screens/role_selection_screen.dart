// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_constants.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {

  // ── Animations ───────────────────────────────────────────
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Time greeting ────────────────────────────────────────
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 🌤️';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }

  // ── Patient tap — check profiles ─────────────────────────
  Future<void> _onPatientTapped() async {
    final db = DatabaseHelper.instance;
    final patients = await db.getAllPatients();

    if (!mounted) return;

    if (patients.isEmpty) {
      // No profiles yet — show message
      _showNoProfileDialog();
    } else if (patients.length == 1) {
      // Only one patient — go straight to home
      await db.setCurrentPatient(
        patients.first[DBConstants.patientId] as int,
      );
      if (!mounted) return;
      Navigator.pushNamed(context, '/patient-home');
    } else {
      // Multiple patients — show picker
      _showPatientPicker(patients);
    }
  }

  // ── No profile dialog ────────────────────────────────────
  void _showNoProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
        title: const Text(
          'No Profile Found',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'No patient profile has been set up yet.\n\n'
          'Please ask your nurse or doctor to set up '
          'your medicines during your next consultation.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: AppColors.successGreen,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Patient picker — if multiple profiles ────────────────
  void _showPatientPicker(List<Map<String, dynamic>> patients) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
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
              'Select Patient',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            ...patients.map((patient) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.successGreen,
                    child: Text(
                      (patient[DBConstants.patientFullName] as String)
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    patient[DBConstants.patientFullName] as String,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    patient[DBConstants.patientWard] ?? 'No ward',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                    ),
                  ),
                  onTap: () async {
                    await DatabaseHelper.instance.setCurrentPatient(
                      patient[DBConstants.patientId] as int,
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/patient-home');
                  },
                )),
            const SizedBox(height: AppDimensions.lg),
          ],
        ),
      ),
    );
  }

  // ── Show more options bottom sheet ───────────────────────
  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MoreOptionsSheet(
        onCaregiverTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/caregiver-profiles');
        },
        onAdminTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/admin-login');
        },
      ),
    );
  }

  void _showComingSoon(String screen) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔜 Coming soon: $screen',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
        ),
        backgroundColor: AppColors.primaryDark,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.lg,
              ),
              child: Column(
                children: [
                  SizedBox(height: size.height * 0.05),

                  // ── Header ────────────────────────────
                  _buildHeader(),

                  // ── Patient Button ────────────────────
                  Expanded(
                    child: Center(
                      child: _buildPatientButton(size),
                    ),
                  ),

                  // ── More Button ───────────────────────
                  _buildMoreButton(),

                  SizedBox(height: size.height * 0.02),

                  // ── Footer ────────────────────────────
                  _buildFooter(),

                  const SizedBox(height: AppDimensions.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader() => Column(
      children: [
        Text(
          _greeting,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.medical_services,
            size: 36,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        const Text(
          'MediVoice',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Who is using the app?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );

  // ── Big Patient Button ───────────────────────────────────
  Widget _buildPatientButton(Size size) => AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: _onPatientTapped,
        child: Container(
          width: size.width * 0.82,
          height: size.height * 0.35,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF43A047),
                Color(0xFF2E7D32),
                Color(0xFF1B5E20),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D32).withOpacity(0.6),
                blurRadius: 30,
                offset: const Offset(0, 12),
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(45),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  size: 52,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'I AM A PATIENT',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap here to take your medicine',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );

  // ── More Button ──────────────────────────────────────────
  Widget _buildMoreButton() => GestureDetector(
      onTap: _showMoreOptions,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.lg,
          vertical: AppDimensions.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.more_horiz,
              color: Colors.white.withOpacity(0.7),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Caregiver / Staff',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

  // ── Footer ───────────────────────────────────────────────
  Widget _buildFooter() => Column(
      children: [
        Container(
          height: 1,
          color: Colors.white.withOpacity(0.15),
        ),
        const SizedBox(height: AppDimensions.sm),
        Text(
          'Kawempe National Referral Hospital',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: Colors.white.withOpacity(0.45),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
}

// ══════════════════════════════════════════════════════════
// More Options Bottom Sheet
// ══════════════════════════════════════════════════════════
class _MoreOptionsSheet extends StatelessWidget {

  const _MoreOptionsSheet({
    required this.onCaregiverTap,
    required this.onAdminTap,
  });
  final VoidCallback onCaregiverTap;
  final VoidCallback onAdminTap;

  @override
  Widget build(BuildContext context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        AppDimensions.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
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
            'Staff Access',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'For caregivers and hospital staff only',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimensions.lg),

          // Caregiver
          _SheetOption(
            icon: Icons.medical_services,
            iconColor: AppColors.primaryBlue,
            iconBgColor: const Color(0xFFE3F2FD),
            label: 'Caregiver Mode',
            sublabel: 'Manage patient profiles & medicines',
            onTap: onCaregiverTap,
          ),

          const SizedBox(height: AppDimensions.md),

          // Admin
          _SheetOption(
            icon: Icons.admin_panel_settings,
            iconColor: AppColors.adminNavy,
            iconBgColor: const Color(0xFFE8EAF6),
            label: 'Hospital Admin',
            sublabel: 'Staff and hospital management',
            onTap: onAdminTap,
          ),

          const SizedBox(height: AppDimensions.lg),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
}

// ── Sheet Option ─────────────────────────────────────────
class _SheetOption extends StatelessWidget {

  const _SheetOption({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
}