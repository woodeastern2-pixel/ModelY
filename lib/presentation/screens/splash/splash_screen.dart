import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../viewmodels/integration_viewmodel.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _scaleAnim = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final integrationVm = context.read<IntegrationViewModel>();
    var guard = 0;
    while (mounted && integrationVm.isBootstrapping && guard < 40) {
      await Future.delayed(const Duration(milliseconds: 250));
      guard += 1;
    }

    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final integrationVm = context.watch<IntegrationViewModel>();
    final bootstrapStatus = integrationVm.bootstrapStatus;
    return Scaffold(
      backgroundColor: AppPalette.navigation,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: AppPalette.indigo,
                        borderRadius: BorderRadius.circular(AppRadii.panel),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x405B5CE2),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        size: 42,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'AI VOC',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'OPERATIONS ASSISTANT',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF9EA5B8),
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SizedBox(
                      width: 280,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Color(0xFFB7B8FF),
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              bootstrapStatus ?? '워크스페이스를 준비하는 중입니다',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFFB9BED0)),
                            ),
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
