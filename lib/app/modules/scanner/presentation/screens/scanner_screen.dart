import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../common/blocs/role_mode/role_mode_cubit.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../blocs/scanner/scanner_cubit.dart';
import '../../blocs/scanner/scanner_state.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ScannerCubit>(),
      child: const _ScannerView(),
    );
  }
}

class _ScannerView extends StatelessWidget {
  const _ScannerView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<ScannerCubit, ScannerState>(
          listener: (context, state) {
                      if (state.status == ScannerStatus.success &&
                          state.walletQrDetected) {
                        final destination = Uri(
                          path: AppRoutes.credits,
                          queryParameters: {
                            if (state.walletUserId != null &&
                                state.walletUserId!.isNotEmpty)
                              'uid': state.walletUserId!,
                            if (state.walletAlias != null &&
                                state.walletAlias!.isNotEmpty)
                              'alias': state.walletAlias!,
                            if (state.walletQrPayload != null &&
                                state.walletQrPayload!.isNotEmpty)
                              'qr': state.walletQrPayload!,
                          },
                        ).toString();
                        context.go(destination);
                        return;
                      }

                      if (state.status == ScannerStatus.success &&
                          state.orderQrValidated) {
                        final target = _ordersRouteForMode(
                          context.read<RoleModeCubit>().state.activeMode,
                        );
                        final destination = Uri(
                          path: target,
                          queryParameters: {
                            'scan': 'ok',
                            if (state.message != null && state.message!.isNotEmpty)
                              'scan_msg': state.message,
                          },
                        ).toString();
                        context.go(destination);
                        return;
                      }

                      final message = state.message;
                      if (message != null) {
                        showSnackOrAuthDialog(context, message);
                      }
                    },
          builder: (context, state) {
            final resolving = state.status == ScannerStatus.resolving;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _HeaderCard(
                    onRestart: resolving
                        ? null
                        : () => context.read<ScannerCubit>().restart(),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            onDetect: resolving
                                ? null
                                : (capture) {
                                    final value = capture.barcodes.isEmpty
                                        ? null
                                        : capture.barcodes.first.rawValue;
                                    if (value == null) return;
                                    context.read<ScannerCubit>().processCode(
                                      value,
                                    );
                                  },
                          ),
                          const _QrFocusOverlay(),
                          if (resolving)
                            ColoredBox(
                              color: Colors.black.withValues(alpha: 0.45),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({this.onRestart});

  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            Text(
                          'Escanear QR',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
                          'Pedidos o billetera ConKkao: coloca el codigo dentro del marco.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Escanear otro'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrFocusOverlay extends StatelessWidget {
  const _QrFocusOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = (constraints.maxWidth * 0.72).clamp(180.0, 300.0);
        final rect = Rect.fromCenter(
          center: Offset(
            constraints.maxWidth / 2,
            constraints.maxHeight / 2,
          ),
          width: side,
          height: side,
        );
        return Stack(
          children: [
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _QrMaskPainter(cutout: rect, radius: 18),
            ),
            Positioned.fromRect(
              rect: rect,
              child: CustomPaint(painter: _QrCornersPainter()),
            ),
          ],
        );
      },
    );
  }
}

class _QrMaskPainter extends CustomPainter {
  _QrMaskPainter({required this.cutout, required this.radius});

  final Rect cutout;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()
      ..addRRect(RRect.fromRectAndRadius(cutout, Radius.circular(radius)));
    final overlay = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(cutout, Radius.circular(radius)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _QrMaskPainter oldDelegate) {
    return oldDelegate.cutout != cutout || oldDelegate.radius != radius;
  }
}

class _QrCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const corner = 28.0;
    const stroke = 5.0;
    final paint = Paint()
      ..color = const Color(0xFF5FE8C7)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final p = Path()
      ..moveTo(0, corner)
      ..lineTo(0, 0)
      ..lineTo(corner, 0)
      ..moveTo(size.width - corner, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, corner)
      ..moveTo(size.width, size.height - corner)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - corner, size.height)
      ..moveTo(corner, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height - corner);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _ordersRouteForMode(RoleMode mode) {
  return switch (mode) {
    RoleMode.client => AppRoutes.orders,
    RoleMode.business => AppRoutes.businessOrders,
    RoleMode.delivery => AppRoutes.deliveryRequests,
  };
}
