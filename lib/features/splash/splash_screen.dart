// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Animation Controllers ────────────────────────────────
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _pulseController;

  // ── Animations 
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    // Logo: scales up from small + fades in (0.0s → 1.2s)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0, 0.6, curve: Curves.easeIn),
      ),
    );

    // Text: slides up + fades in (starts after logo)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    // Pulse: logo breathes gently (loops forever)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseScale = Tween<double>(begin: 1, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
//splash screen timings
  Future<void> _startSequence() async {
    // Step 1: Logo animates in
    await _logoController.forward();

    // Step 2: Text slides in (slight overlap — feels smooth)
    await Future.delayed(const Duration(milliseconds: 200));
    await _textController.forward();

    // Step 3: Logo starts pulsing
    await Future.delayed(const Duration(milliseconds: 400));
    _pulseController.repeat(reverse: true);

    // Step 4: Wait (total visible time = ~5-6 seconds)
    await Future.delayed(const Duration(milliseconds: 2000));

    // Step 5: Navigate
    await _navigate();
  }

  Future<void> _navigate() async {
    if (!mounted) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_completed') ?? false;

    if (!mounted) {
      return;
    }

    if (!onboardingDone) {
      await Navigator.pushReplacementNamed(context, '/role-selection');
    } else {
      await Navigator.pushReplacementNamed(context, '/role-selection');
    }
  }

  @override
  void dispose() {
    // ALWAYS dispose controllers — prevents memory leaks
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      // ── KEY FIX: No SafeArea here ──────────────────────
      // Container fills ENTIRE screen including status bar
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          // SafeArea is INSIDE the container now
          // So gradient fills full screen
          // But content stays inside safe zone
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── Animated Logo ──────────────────────────
              AnimatedBuilder(
                animation: Listenable.merge([
                  _logoController,
                  _pulseController,
                ]),
                builder: (context, child) => FadeTransition(
                    opacity: _logoFade,
                    child: Transform.scale(
                      scale: _logoScale.value * _pulseScale.value,
                      child: child,
                    ),
                  ),
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(65),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    size: 68,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Animated Text Block ────────────────────
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: _textSlide,
                  child: Column(
                    children: [
                      const Text(
                        'MediVoice',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your Voice. Your Medicine. Your Health.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withOpacity(0.75),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // ── Loading Indicator ──────────────────────
              FadeTransition(
                opacity: _textFade,
                child: Column(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        color: Colors.white.withOpacity(0.8),
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Kawempe National Referral Hospital',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
}




















// ignore_for_file: deprecated_member_use

// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../core/constants/app_colors.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//     _navigate();
//   }

//   Future<void> _navigate() async {
//     await Future.delayed(const Duration(seconds: 3));
//     if (!mounted) {
//       return;
//     }

//     final prefs = await SharedPreferences.getInstance();
//     final onboardingDone = prefs.getBool('onboarding_completed') ?? false;

//     if (!mounted) {
//       return;
//     }

//     if (!onboardingDone) {
//       await Navigator.pushReplacementNamed(context, '/role-selection');
//     } else {
//       await Navigator.pushReplacementNamed(context, '/role-selection');
//     }
//   }

//   @override
//   Widget build(BuildContext context) => Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: AppColors.primaryGradient,
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               const Spacer(flex: 2),

//               // Logo circle
//               Container(
//                 width: 120,
//                 height: 120,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(60),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.2),
//                       blurRadius: 20,
//                       offset: const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: const Icon(
//                   Icons.medical_services,
//                   size: 64,
//                   color: AppColors.primaryBlue,
//                 ),
//               ),

//               const SizedBox(height: 24),

//               // App name
//               const Text(
//                 'MediVoice',
//                 style: TextStyle(
//                   fontFamily: 'Poppins',
//                   fontSize: 44,
//                   fontWeight: FontWeight.w700,
//                   color: Colors.white,
//                 ),
//               ),

//               const SizedBox(height: 8),

//               // Tagline
//               const Text(
//                 'Your Voice. Your Medicine. Your Health.',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontFamily: 'Poppins',
//                   fontSize: 14,
//                   fontStyle: FontStyle.italic,
//                   color: Colors.white70,
//                 ),
//               ),

//               const Spacer(flex: 2),

//               // Loading spinner
//               const CircularProgressIndicator(
//                 color: Colors.white,
//                 strokeWidth: 2,
//               ),

//               const SizedBox(height: 24),

//               // Hospital name
//               const Text(
//                 'Kawempe National Referral Hospital',
//                 style: TextStyle(
//                   fontFamily: 'Poppins',
//                   fontSize: 12,
//                   color: Colors.white54,
//                 ),
//               ),

//               const SizedBox(height: 32),
//             ],
//           ),
//         ),
//       ),
//     );
// }
