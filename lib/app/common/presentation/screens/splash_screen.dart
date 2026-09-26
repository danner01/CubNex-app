import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../blocs/app_session/app_session_cubit.dart';
import '../../services/apk_update_service.dart';
import '../../../config/injection/injection.dart';
import '../../../config/routes/app_routes.dart';
import '../../entities/user_role.dart';
import '../widgets/conkkao_logo.dart';
import '../widgets/update_download_sheet.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _logoSplashSeconds = 1;
  static const _flyerSeconds = 1;

  bool _showFlyer = false;

  @override
  void initState() {
    super.initState();
    _goToOnboarding();
  }

  Future<void> _goToOnboarding() async {
    final updateFuture = _checkForUpdate()
        .timeout(const Duration(seconds: 4), onTimeout: () => null)
        .catchError((_) => null);
    await Future<void>.delayed(const Duration(seconds: _logoSplashSeconds));
    if (!mounted) return;
    setState(() => _showFlyer = true);
    await Future<void>.delayed(const Duration(seconds: _flyerSeconds));
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
    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nueva version disponible'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hay una nueva version de ConKkao: v${update.version}.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Puedes actualizar automaticamente ahora o hacerlo luego '
                'desde tu perfil.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Ahora no'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.system_update_alt_rounded, size: 18),
              label: const Text('Actualizar ahora'),
            ),
          ],
        );
      },
    );
    if (proceed != true || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => UpdateDownloadSheet(update: update),
    );
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
        child: _showFlyer ? _buildFlyer() : _buildLogo(),
      ),
    );
  }

  Widget _buildLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.9, end: 1.05),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            builder: (_, scale, __) {
              return Transform.scale(
                scale: scale,
                child: const ConKkaoLogo(size: 142, showGlow: true),
              );
            },
          ),
        ),
        Positioned(
          bottom: 40,
          child: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) {
              final version = snap.data?.version ?? '';
              final build = snap.data?.buildNumber ?? '';
              final text = build.isEmpty ? 'v$version' : 'v$version+$build';
              return Text(
                text,
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFlyer() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeIn,
        builder: (_, value, child) {
          return Opacity(opacity: value, child: child);
        },
        child: Image.asset(
          'assets/rendija.jpg',
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }

}
