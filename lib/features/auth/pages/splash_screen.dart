import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/rbac/roles.dart';
import '../../../core/config/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scale = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final box = Hive.box(AppConstants.authBox);
    final isLoggedIn = box.get('isLoggedIn', defaultValue: false) as bool;
    final userRole = box.get('userRole', defaultValue: '') as String;
    final hasCompletedSetup = box.get('hasCompletedSetup', defaultValue: true) as bool;

    if (isLoggedIn && userRole.isNotEmpty) {
      // Owner hasn't named their workspace yet → Welcome screen
      if (userRole == KlasivoRole.owner && !hasCompletedSetup) {
        context.go('/welcome');
      } else if (userRole == KlasivoRole.teacher || userRole == KlasivoRole.owner) {
        context.go('/dashboard');
      } else if (userRole == KlasivoRole.student) {
        context.go('/student');
      } else {
        context.go('/auth');
      }
    } else {
      context.go('/auth');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KlasivoColors.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeIn.value,
              child: Transform.scale(
                scale: _scale.value,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(KlasivoSpacing.xxl),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KlasivoRadius.xl),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  size: 72,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: KlasivoSpacing.xxl),
              const Text(
                'Klasivo',
                style: TextStyle(
                  fontFamily: KlasivoTypography.fontFamily,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: KlasivoSpacing.sm),
              const Text(
                'Professional Exam Management',
                style: TextStyle(
                  fontFamily: KlasivoTypography.fontFamily,
                  fontSize: 15,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: KlasivoSpacing.hero),
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
