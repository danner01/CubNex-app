import 'dart:async';

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
  const ScannerScreen({super.key, this.evento});

  final String? evento;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ScannerCubit>(),
      child: _ScannerView(evento: evento),
    );
  }
}

class _ScannerView extends StatefulWidget {
  const _ScannerView({this.evento});

  final String? evento;

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView> {
  Timer? _fallbackTimer;
  bool _showFallbackButton = false;
  final MobileScannerController _controller = MobileScannerController();

  bool _arma = true;
  String? _ultimoCodigo;
  DateTime? _ultimoProcesado;

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_arma) return;
    final value = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (value == null) return;

    final ahora = DateTime.now();
    if (_ultimoCodigo == value &&
        _ultimoProcesado != null &&
        ahora.difference(_ultimoProcesado!) < const Duration(seconds: 3)) {
      return;
    }

    _ultimoCodigo = value;
    _ultimoProcesado = ahora;
    _arma = false;
    context.read<ScannerCubit>().processCode(value, evento: widget.evento);
  }

  Future<void> _dispararEscaneo() async {
    setState(() {
      _arma = true;
      _ultimoCodigo = null;
      _ultimoProcesado = null;
    });
    try {
      if (_controller.value.isRunning) {
        await _controller.stop();
      }
      await _controller.start();
    } catch (_) {}
  }

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _showFallbackButton = false;
    _fallbackTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showFallbackButton = true);
      }
    });
  }

  void _cancelFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    if (_showFallbackButton) {
      setState(() => _showFallbackButton = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<ScannerCubit, ScannerState>(
          listener: (context, state) {
            if (state.status == ScannerStatus.resolving) {
              _startFallbackTimer();
            } else {
              _cancelFallbackTimer();
            }

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
                            controller: _controller,
                            onDetect: _onDetect,
                          ),
                          const _QrFocusOverlay(),
                          if (resolving)
                            ColoredBox(
                              color: Colors.black.withValues(alpha: 0.45),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Procesando código...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (_showFallbackButton) ...[
                                      const SizedBox(height: 12),
                                      TextButton.icon(
                                        onPressed: () {
                                          context
                                              .read<ScannerCubit>()
                                              .useRawCode();
                                        },
                                        icon: const Icon(
                                          Icons.skip_next_rounded,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'Usar código sin procesar',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.15),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          _ControlesEscaner(
                            controller: _controller,
                            habilitado: !resolving,
                            onDisparar: _dispararEscaneo,
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
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
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

class _ControlesEscaner extends StatelessWidget {
  const _ControlesEscaner({
    required this.controller,
    required this.habilitado,
    required this.onDisparar,
  });

  final MobileScannerController controller;
  final bool habilitado;
  final VoidCallback onDisparar;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ValueListenableBuilder<MobileScannerState>(
        valueListenable: controller,
        builder: (context, state, _) {
          final torchOn = state.torchState == TorchState.on;
          final torchUnavailable = state.torchState == TorchState.unavailable;
          final camaraActiva = state.isRunning;
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BotonControl(
                  tooltip: torchOn ? 'Apagar linterna' : 'Encender linterna',
                  icon: torchOn
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  onTap: torchUnavailable || !camaraActiva
                      ? null
                      : () => controller.toggleTorch(),
                ),
                const SizedBox(width: 18),
                _BotonDisparo(onTap: habilitado ? onDisparar : null),
                const SizedBox(width: 18),
                _BotonControl(
                  tooltip: 'Cambiar camara',
                  icon: Icons.cameraswitch_rounded,
                  onTap: camaraActiva ? () => controller.switchCamera() : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BotonControl extends StatelessWidget {
  const _BotonControl({required this.tooltip, required this.icon, this.onTap});

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
      ),
    );
  }
}

class _BotonDisparo extends StatelessWidget {
  const _BotonDisparo({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Disparar escaneo',
      child: Material(
        color: onTap == null ? Colors.white54 : Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 60,
            height: 60,
            child: Icon(
              Icons.qr_code_scanner_rounded,
              size: 32,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
