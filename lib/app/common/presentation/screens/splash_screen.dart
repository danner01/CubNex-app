import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../blocs/app_session/app_session_cubit.dart';
import '../../services/apk_update_service.dart';
import '../../../config/injection/injection.dart';
import '../../../config/routes/app_routes.dart';
import '../../../config/theme/app_colors.dart';
import '../../entities/user_role.dart';
import '../widgets/conkkao_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _splashSeconds = 2;
  static const _growthAnimationSeconds = 2;
  static const _totalDuration = Duration(
    seconds: _splashSeconds + _growthAnimationSeconds,
  );

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration)
      ..forward();
    _goToOnboarding();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goToOnboarding() async {
    final updateFuture = _checkForUpdate()
        .timeout(const Duration(seconds: 4), onTimeout: () => null)
        .catchError((_) => null);
    await Future<void>.delayed(_totalDuration);
    if (!mounted) return;
    final update = await updateFuture;
    if (mounted && update != null) {
      await _showUpdateDialog(update);
    }
    if (!mounted) return;
    final session = context.read<AppSessionCubit>().state;
    final target = switch (session.status) {
      AppSessionStatus.authenticated => _defaultLocationForRole(session.role),
      AppSessionStatus.guest => AppRoutes.home,
      AppSessionStatus.unauthenticated =>
        session.onboardingSeen ? AppRoutes.login : AppRoutes.onboarding,
      AppSessionStatus.loading => AppRoutes.onboarding,
    };
    if (!mounted) return;
    context.go(target);
  }

  Future<ApkUpdateInfo?> _checkForUpdate() {
    return sl<ApkUpdateService>().checkForUpdate();
  }

  Future<void> _showUpdateDialog(ApkUpdateInfo update) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nueva version disponible'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version ${update.version}'),
              const SizedBox(height: 8),
              Text(
                update.notes?.isNotEmpty == true
                    ? update.notes!
                    : 'Hay una actualizacion lista para descargar.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Mas tarde'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Actualizar'),
            ),
          ],
        );
      },
    );

    if (shouldOpen != true) return;
    final uri = Uri.tryParse(update.downloadUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _defaultLocationForRole(UserRole role) {
    return switch (role) {
      UserRole.businessAdmin ||
      UserRole.superadmin => AppRoutes.businessDashboard,
      UserRole.delivery => AppRoutes.deliveryDashboard,
      _ => AppRoutes.home,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(child: CacaoGrowthSplash(animation: _controller)),
      ),
    );
  }

}

/// Botanical identity animation used during startup. It is intentionally
/// self-contained so the splash never depends on network or remote assets.
class CacaoGrowthSplash extends StatelessWidget {
  const CacaoGrowthSplash({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = animation.value;
        final logoProgress = ((progress - 0.76) / 0.24).clamp(0.0, 1.0);
        return SizedBox(
          width: 250,
          height: 330,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(250, 330),
                painter: _CacaoGrowthPainter(progress: progress),
              ),
              Opacity(
                opacity: Curves.easeOut.transform(logoProgress),
                child: Transform.scale(
                  scale: 0.72 + logoProgress * 0.28,
                  child: const ConKkaoLogo(size: 142, showGlow: true),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CacaoGrowthPainter extends CustomPainter {
  const _CacaoGrowthPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);
    final soilY = size.height * 0.73;
    final soilPaint = Paint()
      ..color = const Color(0xFF4A281A).withValues(alpha: 0.9)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.2, soilY),
      Offset(size.width * 0.8, soilY),
      soilPaint,
    );

    final seedT = Curves.easeOut.transform((progress / 0.22).clamp(0.0, 1.0));
    if (seedT < 1) {
      final seedCenter = Offset(center.dx, soilY + 18 - seedT * 15);
      final seed = Paint()..color = const Color(0xFF8B542E);
      canvas.drawOval(
        Rect.fromCenter(center: seedCenter, width: 28, height: 18),
        seed,
      );
    }

    final plantT = Curves.easeInOut.transform(
      ((progress - 0.14) / 0.43).clamp(0.0, 1.0),
    );
    if (plantT > 0) {
      final stem = Paint()
        ..color = const Color(0xFF52735B)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      final stemEnd = Offset(center.dx, soilY - 110 * plantT);
      canvas.drawLine(Offset(center.dx, soilY), stemEnd, stem);
      _drawLeaf(canvas, stemEnd + Offset(-4, 18), -0.65, plantT);
      _drawLeaf(canvas, stemEnd + Offset(5, 42), 0.55, plantT * 0.9);
    }

    final podT = Curves.easeOutBack.transform(
      ((progress - 0.38) / 0.38).clamp(0.0, 1.0),
    );
    if (podT > 0) {
      canvas.save();
      canvas.translate(center.dx, center.dy + 18);
      canvas.scale(podT);
      final pod = Path()
        ..moveTo(0, -72)
        ..cubicTo(42, -50, 44, 28, 0, 78)
        ..cubicTo(-44, 28, -42, -50, 0, -72)
        ..close();
      canvas.drawPath(
        pod,
        Paint()
          ..color = const Color(0xFFD7AB4D)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        pod,
        Paint()
          ..color = const Color(0xFFF2D27C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final seam = Path()
        ..moveTo(0, -60)
        ..cubicTo(-13, -20, 14, 21, 0, 63);
      canvas.drawPath(
        seam,
        Paint()
          ..color = const Color(0xFF5A775D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }

    final openT = Curves.easeInOut.transform(
      ((progress - 0.67) / 0.22).clamp(0.0, 1.0),
    );
    if (openT > 0 && openT < 1) {
      final glow = Paint()
        ..color = AppColors.gold.withValues(alpha: 0.2 * openT)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(center, 68 + openT * 18, glow);
    }
  }

  void _drawLeaf(Canvas canvas, Offset origin, double angle, double amount) {
    if (amount <= 0) return;
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    canvas.scale(amount, amount);
    final leaf = Path()
      ..moveTo(0, 0)
      ..cubicTo(18, -30, 45, -24, 56, -5)
      ..cubicTo(36, 14, 12, 16, 0, 0)
      ..close();
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF52735B));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CacaoGrowthPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
