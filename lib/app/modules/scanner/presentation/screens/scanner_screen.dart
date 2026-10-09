import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../common/blocs/role_mode/role_mode_cubit.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../blocs/scanner/scanner_cubit.dart';
import '../../blocs/scanner/scanner_state.dart';

enum _ScannerMode { qr, product }

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
  _ScannerMode _mode = _ScannerMode.qr;

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
    if (_mode != _ScannerMode.qr) return;
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

  Future<void> _capturarProducto() async {
    final cubit = context.read<ScannerCubit>();
    if (cubit.state.status == ScannerStatus.resolving) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      await cubit.detectProductImage(imagePath: picked.path, imageBytes: bytes);
    } catch (_) {
      if (mounted) {
        showSnackOrAuthDialog(
          context,
          'No se pudo capturar el producto. Intenta de nuevo.',
        );
      }
    }
  }

  void _cambiarModo(_ScannerMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _arma = true;
      _ultimoCodigo = null;
      _ultimoProcesado = null;
    });
    context.read<ScannerCubit>().restart();
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
    if (kIsWeb) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_scanner_outlined, size: 44),
                const SizedBox(height: 12),
                const Text(
                  'El escaner solo esta disponible en la app movil.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

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
            if (message != null && _mode == _ScannerMode.qr) {
              showSnackOrAuthDialog(context, message);
            }
          },
          builder: (context, state) {
            final resolving = state.status == ScannerStatus.resolving;
            final productMode = _mode == _ScannerMode.product;
            final showProductResult =
                productMode &&
                (state.productDetection != null ||
                    (state.status == ScannerStatus.failure &&
                        state.productImagePath != null));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _ModeSelector(
                    mode: _mode,
                    onChanged: _cambiarModo,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _HeaderCard(
                    mode: _mode,
                    onRestart: resolving || showProductResult
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
                          if (productMode)
                            _ProductScanView(
                              controller: _controller,
                              state: state,
                              resolving: resolving,
                              showResult: showProductResult,
                              onCapturar: _capturarProducto,
                            )
                          else ...[
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
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
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
  const _HeaderCard({required this.mode, this.onRestart});

  final _ScannerMode mode;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    final product = mode == _ScannerMode.product;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            Text(
              product ? 'Escanea un producto' : 'Escanear QR',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              product
                  ? 'Apunta a la etiqueta del producto y toca el boton de la camara.'
                        ' La IA reconoce tipo, marca y categoria, y busca en la base de datos.'
                  : 'Pedidos o billetera ConKkao: coloca el codigo dentro del marco.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(product ? 'Escanea otro' : 'Escanear otro'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final _ScannerMode mode;
  final ValueChanged<_ScannerMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModoBoton(
          activo: mode == _ScannerMode.qr,
          icon: Icons.qr_code_2_rounded,
          label: 'QR y códigos',
          onTap: () => onChanged(_ScannerMode.qr),
        ),
        const SizedBox(width: 10),
        _ModoBoton(
          activo: mode == _ScannerMode.product,
          icon: Icons.inventory_2_rounded,
          label: 'Producto',
          onTap: () => onChanged(_ScannerMode.product),
        ),
      ],
    );
  }
}

class _ModoBoton extends StatelessWidget {
  const _ModoBoton({
    required this.activo,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool activo;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: activo ? theme.colorScheme.primary : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: activo
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: activo
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductScanView extends StatelessWidget {
  const _ProductScanView({
    required this.controller,
    required this.state,
    required this.resolving,
    required this.showResult,
    required this.onCapturar,
  });

  final MobileScannerController controller;
  final ScannerState state;
  final bool resolving;
  final bool showResult;
  final VoidCallback onCapturar;

  @override
  Widget build(BuildContext context) {
    if (showResult) {
      return _ProductResultView(
        state: state,
        onRetake: () => context.read<ScannerCubit>().restart(),
      );
    }

    final capturedPath = state.productImagePath;
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: controller, onDetect: (_) {}),
        if (capturedPath != null && resolving) ...[
          ColoredBox(
            color: Colors.black,
            child: Image.file(
              File(capturedPath),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
        const _ProductFocusOverlay(),
        if (resolving)
          ColoredBox(
            color: Colors.black.withValues(alpha: 0.55),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Reconociendo con IA...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _ControlesEscaner(
            controller: controller,
            habilitado: true,
            iconoDisparo: Icons.photo_camera_rounded,
            onDisparar: onCapturar,
          ),
      ],
    );
  }
}

class _ProductResultView extends StatefulWidget {
  const _ProductResultView({required this.state, required this.onRetake});

  final ScannerState state;
  final VoidCallback onRetake;

  @override
  State<_ProductResultView> createState() => _ProductResultViewState();
}

class _ProductResultViewState extends State<_ProductResultView> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(
      text: widget.state.productQuery ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _ProductResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.productQuery != widget.state.productQuery) {
      _queryController.text = widget.state.productQuery ?? '';
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _buscar(BuildContext context) {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    final destination = Uri(
      path: AppRoutes.search,
      queryParameters: {'q': query},
    ).toString();
    context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final detection = widget.state.productDetection;
    final sujetoExitoso = widget.state.status == ScannerStatus.success;
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _thumb(
              path: widget.state.productImagePath,
              theme: theme,
            ),
            const SizedBox(height: 14),
            if (sujetoExitoso && detection != null) ...[
              _rowDetalle(
                icon: Icons.inventory_2_rounded,
                etiqueta: 'Tipo de producto',
                valor: detection.name,
                theme: theme,
              ),
              if ((detection.brand ?? '').trim().isNotEmpty)
                _rowDetalle(
                  icon: Icons.branding_watermark_rounded,
                  etiqueta: 'Marca',
                  valor: detection.brand,
                  theme: theme,
                ),
              if ((detection.category ?? '').trim().isNotEmpty)
                _rowDetalle(
                  icon: Icons.category_rounded,
                  etiqueta: 'Categoria',
                  valor: detection.category,
                  theme: theme,
                ),
              if ((detection.barcode ?? '').trim().isNotEmpty)
                _rowDetalle(
                  icon: Icons.qr_code_2_rounded,
                  etiqueta: 'Codigo de barras',
                  valor: detection.barcode,
                  theme: theme,
                ),
            ] else
              _MessageChip(
                icon: Icons.help_outline_rounded,
                texto:
                    'No pudimos reconocer el producto con IA. '
                    'Escribe el nombre o escanea de nuevo.',
                theme: theme,
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(context),
              decoration: const InputDecoration(
                labelText: 'Busqueda en ConKkao',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _buscar(context),
              icon: const Icon(Icons.manage_search_rounded),
              label: const Text('Buscar en la base de datos'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onRetake,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Escanea otro producto'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb({String? path, required ThemeData theme}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: path == null || path.isEmpty
          ? Container(
              height: 180,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(Icons.no_photography_outlined, size: 44),
              ),
            )
          : Image.file(
              File(path),
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, size: 44),
                ),
              ),
            ),
    );
  }

  Widget _rowDetalle({
    required IconData icon,
    required String etiqueta,
    required String? valor,
    required ThemeData theme,
  }) {
    final text = (valor ?? '').trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageChip extends StatelessWidget {
  const _MessageChip({required this.icon, required this.texto, required this.theme});

  final IconData icon;
  final String texto;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFocusOverlay extends StatelessWidget {
  const _ProductFocusOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.66;
        final height = constraints.maxHeight * 0.46;
        final rect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight * 0.46),
          width: width,
          height: height,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _ProductMaskPainter(cutout: rect)),
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

class _ProductMaskPainter extends CustomPainter {
  _ProductMaskPainter({required this.cutout});

  final Rect cutout;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(20)));
    final overlay = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutout, const Radius.circular(20)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ProductMaskPainter oldDelegate) {
    return oldDelegate.cutout != cutout;
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
    this.iconoDisparo = Icons.qr_code_scanner_rounded,
  });

  final MobileScannerController controller;
  final bool habilitado;
  final VoidCallback onDisparar;
  final IconData iconoDisparo;

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
                _BotonDisparo(onTap: habilitado ? onDisparar : null, icono: iconoDisparo),
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
  const _BotonDisparo({this.onTap, this.icono = Icons.qr_code_scanner_rounded});

  final VoidCallback? onTap;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: onTap == null ? 'Procesando...' : 'Disparar escaneo',
      child: Material(
        color: onTap == null ? Colors.white54 : Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 60,
            height: 60,
            child: Icon(
              icono,
              size: 30,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
