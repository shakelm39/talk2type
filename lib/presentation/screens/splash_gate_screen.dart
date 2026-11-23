import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/license_service.dart';
import '../providers/permission_provider.dart';
import 'api_key_setup_screen.dart';
import 'home_control_screen.dart';
import 'permission_dashboard_screen.dart';
import 'welcome_choice_screen.dart';

class SplashGateScreen extends StatefulWidget {
  const SplashGateScreen({super.key});

  @override
  State<SplashGateScreen> createState() => _SplashGateScreenState();
}

class _SplashGateScreenState extends State<SplashGateScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();
    _navigateToNext();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    final permProv = Provider.of<PermissionProvider>(context, listen: false);

    // Always fetch dynamic pricing & hub app info on every app start (non-blocking)
    LicenseService.instance.fetchHubAppInfo();

    // Step 1: Check License
    final isLicenseValid = await LicenseService.instance.isLicenseValid();
    if (isLicenseValid) {
      // Trigger periodic verification in background
      LicenseService.instance.verifyLicensePeriodic();
    } else {
      // If user hasn't chosen free yet, present welcome choice screen
      if (!AppConfig.userChoseFree) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeChoiceScreen()),
        );
        return;
      }
    }

    // Step 2: Check Permissions
    await permProv.checkAllPermissions();
    if (!mounted) return;

    if (!permProv.allGranted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PermissionDashboardScreen()),
      );
    } else if (!AppConfig.hasAnyAiKey && !AppConfig.keySetupSkipped) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ApiKeySetupScreen(isFirstLaunch: true)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeControlScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glowing Orb App Icon
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 36,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.mic_rounded,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // App Title
                    const Text(
                      "Talk2Type",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Bengali & English Tagline
                    const Text(
                      "বাংলা ও ইংরেজি ভয়েস টাইপিং অ্যাসিস্ট্যান্ট",
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "AI-Powered Floating Voice-to-Text AutoType",
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Sleek progress indicator
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
