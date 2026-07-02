import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:math' as math;

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../home/data/models/product_model.dart';
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
      body: BlocConsumer<ScannerCubit, ScannerState>(
        listener: (context, state) {
          final message = state.message;
          if (message != null) {
            showSnackOrAuthDialog(context, message);
          }

          if (state.status == ScannerStatus.success && state.code != null) {
            final directTarget = context
                .read<ScannerCubit>()
                .resolveDirectTarget(state.code!);
            if (directTarget != null) {
              context.go(directTarget);
              return;
            }
            if (state.products.length == 1) {
              context.go(AppRoutes.product(state.products.first.id));
            }
          }
        },
        builder: (context, state) {
          final resolving = state.status == ScannerStatus.resolving;

          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.secondary,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Escaneo inteligente',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Busca productos por imagen: toma una foto del empaque, etiqueta o producto. El lector QR queda solo para enlaces directos.',
                          textAlign: TextAlign.center,
                        ),
                        if (state.code != null) ...[
                          const SizedBox(height: 12),
                          SelectableText(
                            state.code!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (state.products.length > 1) ...[
                          const SizedBox(height: 12),
                          _PagedScannerResults(
                            key: ValueKey(
                              state.products.map((item) => item.id).join('|'),
                            ),
                            products: state.products,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: resolving
                                    ? null
                                    : () => context
                                          .read<ScannerCubit>()
                                          .pickAndSearchProduct(
                                            ImageSource.camera,
                                          ),
                                icon: const Icon(Icons.camera_alt_rounded),
                                label: const Text('Foto'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: resolving
                                    ? null
                                    : () => context
                                          .read<ScannerCubit>()
                                          .pickAndSearchProduct(
                                            ImageSource.gallery,
                                          ),
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('Galeria'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: resolving
                              ? null
                              : () => context.read<ScannerCubit>().restart(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Escanear otro'),
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
    );
  }
}

class _PagedScannerResults extends StatefulWidget {
  const _PagedScannerResults({super.key, required this.products});

  final List<ProductModel> products;

  @override
  State<_PagedScannerResults> createState() => _PagedScannerResultsState();
}

class _PagedScannerResultsState extends State<_PagedScannerResults> {
  static const _pageSize = 10;
  final _controller = ScrollController();
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_loadMoreNearBottom);
  }

  @override
  void didUpdateWidget(covariant _PagedScannerResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products != widget.products) {
      _visibleCount = _pageSize;
      if (_controller.hasClients) {
        _controller.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_loadMoreNearBottom)
      ..dispose();
    super.dispose();
  }

  void _loadMoreNearBottom() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels < position.maxScrollExtent - 72) return;
    if (_visibleCount >= widget.products.length) return;
    setState(() {
      _visibleCount = math.min(
        _visibleCount + _pageSize,
        widget.products.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.products.take(_visibleCount).toList();
    final height = math.min(
      MediaQuery.sizeOf(context).height * 0.42,
      math.max(120.0, visible.length * 76.0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${visible.length} de ${widget.products.length} coincidencias',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: ListView.separated(
            controller: _controller,
            primary: false,
            itemCount: visible.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = visible[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _ProductThumb(product),
                title: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                        product.brand,
                        product.businessName,
                        product.currentPrice == null
                            ? null
                            : '${product.currentPrice!.toStringAsFixed(0)} ${product.currency ?? 'CUP'}',
                      ]
                      .whereType<String>()
                      .where((item) => item.isNotEmpty)
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(AppRoutes.product(product.id)),
              );
            },
          ),
        ),
        if (_visibleCount < widget.products.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Desliza para cargar 10 mas.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb(this.product);

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final image = product.imageUrl;
    if (image == null || image.isEmpty) {
      return const Icon(Icons.inventory_2_outlined);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        image,
        width: 42,
        height: 42,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined),
      ),
    );
  }
}
