import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/local_catalog_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../common/blocs/role_mode/role_mode_cubit.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../blocs/scanner/scanner_cubit.dart';
import '../../blocs/scanner/scanner_state.dart';
import '../widgets/scanner_image_preview.dart';
import '../../../business/data/models/product_label_detection.dart';

enum ScannerMode { qr, product }

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({
    super.key,
    this.evento,
    this.initialMode = ScannerMode.qr,
    this.onProductDetected,
  });

  final String? evento;
  final ScannerMode initialMode;
  final void Function(ProductLabelDetection)? onProductDetected;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ScannerCubit>(),
      child: _ScannerView(
        evento: evento,
        initialMode: initialMode,
        onProductDetected: onProductDetected,
      ),
    );
  }
}

class _ScannerView extends StatefulWidget {
  const _ScannerView({
    this.evento,
    this.initialMode = ScannerMode.qr,
    this.onProductDetected,
  });

  final String? evento;
  final ScannerMode initialMode;
  final void Function(ProductLabelDetection)? onProductDetected;

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView> {
  Timer? _fallbackTimer;
  bool _showFallbackButton = false;
  final MobileScannerController _controller = MobileScannerController(
    returnImage: true,
  );
  late ScannerMode _mode;
  bool _arma = true;
  final GlobalKey<_LiveProductCameraState> _cameraKey = GlobalKey();
  int _framesSinResultado = 0;
  String? _ultimoCodigo;
  DateTime? _ultimoProcesado;
  bool _productResultNotified = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_mode != ScannerMode.qr) return;
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

  void _cambiarModo(ScannerMode mode) {
    if (mode == _mode) return;
    if (mode == ScannerMode.product) {
      unawaited(_controller.stop().catchError((_) {}));
    } else {
      _framesSinResultado = 0;
      unawaited(_controller.start().catchError((_) {}));
    }
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

  /// Escaneo continuo: la camara en vivo envia fotogramas cada ~2 s y se
  /// reconoce la etiqueta localmente sin que el usuario toque nada. Si tras
  /// varios intentos no hay resultado, se consulta a la IA del backend.
  Future<void> _onFrame(XFile file, bool manual) async {
    if (_mode != ScannerMode.product || !mounted) return;
    final cubit = context.read<ScannerCubit>();
    if (cubit.state.status == ScannerStatus.resolving) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (manual) {
      _framesSinResultado = 0;
      await cubit.detectProductImage(imagePath: file.path, imageBytes: bytes);
      return;
    }
    final ok = await cubit.probeProductFrame(
      imagePath: file.path,
      imageBytes: bytes,
    );
    if (ok || !mounted) {
      _framesSinResultado = 0;
      return;
    }
    if (++_framesSinResultado >= 3) {
      _framesSinResultado = 0;
      await cubit.detectProductImage(imagePath: file.path, imageBytes: bytes);
    }
  }

  /// Boton de camara: fuerza el reconocimiento inmediato del cuadro actual;
  /// si la camara en vivo no esta disponible usa la camara del sistema.
  Future<void> _escannerEtiqueta() async {
    if (_mode != ScannerMode.product) return;
    final ok = await _cameraKey.currentState?.captureNow() ?? false;
    if (!ok && mounted) await _capturarConCamaraSistema();
  }

  Future<void> _capturarConCamaraSistema() async {
    try {
      _arma = false;
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (picked == null) {
        _arma = true;
        return;
      }
      final cubit = context.read<ScannerCubit>();
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      unawaited(
        cubit.detectProductImage(imagePath: picked.path, imageBytes: bytes),
      );
    } catch (_) {
      _arma = true;
      if (mounted) {
        showSnackOrAuthDialog(
          context,
          'No se pudo capturar la etiqueta. Intenta de nuevo.',
        );
      }
    }
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
            if (message != null && _mode == ScannerMode.qr) {
              showSnackOrAuthDialog(context, message);
            }

            if (_mode == ScannerMode.product &&
                state.status == ScannerStatus.success &&
                state.productDetection != null &&
                widget.onProductDetected != null &&
                !_productResultNotified) {
              _productResultNotified = true;
              widget.onProductDetected!.call(state.productDetection!);
              if (mounted) {
                Navigator.of(context).pop(state.productDetection);
              }
              return;
            }

            if (_mode == ScannerMode.product &&
                (state.status == ScannerStatus.success ||
                    state.status == ScannerStatus.failure) &&
                !_arma) {
              _arma = true;
            }
          },
          builder: (context, state) {
            final resolving = state.status == ScannerStatus.resolving;
            final productMode = _mode == ScannerMode.product;
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
                if (!productMode)
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
                              state: state,
                              resolving: resolving,
                              showResult: showProductResult,
                              cameraKey: _cameraKey,
                              onFrame: _onFrame,
                              onEscanearEtiqueta: _escannerEtiqueta,
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

  final ScannerMode mode;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    final product = mode == ScannerMode.product;
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
                  ? 'Apunta a la etiqueta del producto: el codigo se detecta '
                        'solo desde la camara, o toca el boton para capturar la '
                        'etiqueta. La IA reconoce tipo, marca y categoria.'
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

  final ScannerMode mode;
  final ValueChanged<ScannerMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModoBoton(
          activo: mode == ScannerMode.qr,
          icon: Icons.qr_code_2_rounded,
          label: 'QR y códigos',
          onTap: () => onChanged(ScannerMode.qr),
        ),
        const SizedBox(width: 10),
        _ModoBoton(
          activo: mode == ScannerMode.product,
          icon: Icons.inventory_2_rounded,
          label: 'Producto',
          onTap: () => onChanged(ScannerMode.product),
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
    required this.cameraKey,
    required this.state,
    required this.resolving,
    required this.showResult,
    required this.onFrame,
    required this.onEscanearEtiqueta,
  });

  final GlobalKey<_LiveProductCameraState> cameraKey;
  final ScannerState state;
  final bool resolving;
  final bool showResult;
  final Future<void> Function(XFile, bool) onFrame;
  final Future<void> Function()? onEscanearEtiqueta;

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
        _LiveProductCamera(
          key: cameraKey,
          active: !resolving,
          onFrame: onFrame,
        ),
        if (capturedPath != null && resolving) ...[
          ColoredBox(
            color: Colors.black,
            child: ScannerImagePreview(
              path: capturedPath,
              height: null,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
        const _ProductFocusOverlay(),
        if (!resolving)
          const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Apunta a la etiqueta: se escanea sola',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
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
          _BotonEscanearEtiqueta(
            habilitado: true,
            onTap: onEscanearEtiqueta,
          ),
      ],
    );
  }
}

class _LiveProductCamera extends StatefulWidget {
  const _LiveProductCamera({
    super.key,
    required this.active,
    required this.onFrame,
  });

  final bool active;
  final Future<void> Function(XFile, bool) onFrame;

  @override
  State<_LiveProductCamera> createState() => _LiveProductCameraState();
}

class _LiveProductCameraState extends State<_LiveProductCamera>
    with WidgetsBindingObserver {
  CameraController? _camera;
  Timer? _timer;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('sin camara');
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
      _timer = Timer.periodic(
        const Duration(milliseconds: 2200),
        (_) => unawaited(_tick(false)),
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<bool> _tick(bool manual) async {
    final camera = _camera;
    if (camera == null || !mounted || !camera.value.isInitialized) {
      return false;
    }
    if (_busy || (!manual && !widget.active)) return manual ? false : true;
    _busy = true;
    try {
      final file = await camera.takePicture();
      await widget.onFrame(file, manual);
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<bool> captureNow() => _tick(true);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _timer?.cancel();
      _camera = null;
      unawaited(camera.dispose());
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_init());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_camera?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    if (_failed) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'No se pudo abrir la camara.\nUsa el boton para tomar la foto.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      );
    }
    if (camera == null || !camera.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final size = camera.value.previewSize;
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size?.height ?? 1,
            height: size?.width ?? 1,
            child: CameraPreview(camera),
          ),
        ),
      ),
    );
  }
}

class _BotonEscanearEtiqueta extends StatelessWidget {
  const _BotonEscanearEtiqueta({
    required this.habilitado,
    required this.onTap,
  });

  final bool habilitado;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        child: SizedBox(
          width: 60,
          height: 60,
          child: _BotonDisparo(
            onTap: habilitado && onTap != null
                ? () => unawaited(onTap!())
                : null,
            icono: Icons.photo_camera_rounded,
          ),
        ),
      ),
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
            if (widget.state.catalogMatches.isNotEmpty) ...[
              Text(
                'Coincidencias en el catalogo',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              for (final match in widget.state.catalogMatches)
                _MatchTile(
                  match: match,
                  onTap: () =>
                      context.go(AppRoutes.product(match.entry.id)),
                ),
              const SizedBox(height: 6),
            ],
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
          : ScannerImagePreview(
              path: path,
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

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.onTap});

  final CatalogMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final entry = match.entry;
    final image = entry.imageUrl;
    final percent = (match.score * 100).round();
    final price = entry.price == null
        ? null
        : '${entry.price!.toStringAsFixed(2)} ${entry.currency ?? ''}'.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 48,
            child: image == null || image.isEmpty
                ? const Icon(Icons.inventory_2_outlined)
                : Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.inventory_2_outlined),
                  ),
          ),
        ),
        title: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if ((entry.brand ?? '').isNotEmpty) entry.brand!,
            if ((entry.businessName ?? '').isNotEmpty) entry.businessName!,
            if (price != null) price,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '$percent%',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
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
        final width = constraints.maxWidth * 0.92;
        final height = constraints.maxHeight * 0.72;
        final rect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight * 0.45),
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
    this.onDisparar,
    this.iconoDisparo = Icons.qr_code_scanner_rounded,
  });

  final MobileScannerController controller;
  final bool habilitado;
  final VoidCallback? onDisparar;
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
