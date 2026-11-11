import 'package:flutter/material.dart';
import '../theme/ginata_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _controller.addStatusListener((status) async {
      if (status != AnimationStatus.completed) return;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) widget.onComplete();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _progress(double start, double end, [Curve curve = Curves.easeOutCubic]) {
    return Interval(start, end, curve: curve).transform(_controller.value);
  }

  Widget _treePiece(String asset, double start, double end, Offset from, {double rotation = 0}) {
    final t = _progress(start, end, Curves.easeOutBack);
    return Opacity(
      opacity: _progress(start, (start + end) / 2).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(from.dx * (1 - t), from.dy * (1 - t)),
        child: Transform.rotate(
          angle: rotation * (1 - t),
          child: Transform.scale(
            scale: 0.86 + 0.14 * t,
            child: Image.asset(asset, fit: BoxFit.contain, excludeFromSemantics: true),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final treeWidth = width < 380 ? 176.0 : 216.0;
    final treeHeight = treeWidth * 830 / 745;
    final wordWidth = width < 380 ? 210.0 : 252.0;
    final wordOpacity = _progress(0.62, 0.86);
    final subtitleOpacity = _progress(0.74, 0.94);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFBF8F1), Color(0xFFF3F6F1)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: treeWidth,
                      height: treeHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _treePiece('assets/images/tree_trunk.png', 0.00, 0.46, const Offset(0, 70)),
                          _treePiece('assets/images/tree_left.png', 0.12, 0.58, const Offset(-70, 24), rotation: -0.10),
                          _treePiece('assets/images/tree_right.png', 0.20, 0.66, const Offset(70, 24), rotation: 0.10),
                          _treePiece('assets/images/tree_top.png', 0.30, 0.76, const Offset(0, -64)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Opacity(
                      opacity: wordOpacity,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - wordOpacity)),
                        child: Image.asset(
                          'assets/images/wordmark.png',
                          width: wordWidth,
                          fit: BoxFit.contain,
                          semanticLabel: 'Ginata',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: subtitleOpacity,
                      child: const Text(
                        'PROPERTY MANAGEMENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3.2,
                          color: GinataColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 44),
                    Opacity(
                      opacity: subtitleOpacity,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 72,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: _progress(0.78, 1.0),
                                minHeight: 3,
                                backgroundColor: GinataColors.secondary.withValues(alpha: 0.14),
                                valueColor: const AlwaysStoppedAnimation<Color>(GinataColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Preparing your workspace',
                            style: TextStyle(fontSize: 12, color: GinataColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
