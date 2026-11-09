import 'package:flutter/material.dart';
import '../theme/ginata_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  late final AnimationController _titleController;
  late final Animation<double> _titleFade;

  late final AnimationController _subtitleController;
  late final Animation<double> _subtitleFade;

  late final AnimationController _indicatorController;
  late final Animation<double> _indicatorFade;

  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOut),
    );

    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeOut),
    );

    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _indicatorFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _indicatorController, curve: Curves.easeOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulse = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _titleController.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _subtitleController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _indicatorController.forward();
    _pulseController.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _indicatorController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GinataColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoFade.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                'assets/images/logo.png',
                height: 100,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: GinataColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            FadeTransition(
              opacity: _titleFade,
              child: const Text(
                'GINATA',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: GinataColors.primary,
                  letterSpacing: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _subtitleFade,
              child: Text(
                'Property Management',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: GinataColors.secondary.withValues(alpha: 0.8),
                  letterSpacing: 2,
                ),
              ),
            ),
            const Spacer(flex: 3),
            FadeTransition(
              opacity: _indicatorFade,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  return _PulsingDots(
                    color: GinataColors.secondary,
                    progress: _pulse.value,
                  );
                },
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _PulsingDots extends StatelessWidget {
  final Color color;
  final double progress;

  const _PulsingDots({required this.color, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final offset = index * 0.2;
        final dotProgress = ((progress + offset) % 1.0);
        final scale = 0.5 + (dotProgress * 0.5);
        final opacity = 0.3 + (dotProgress * 0.7);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
