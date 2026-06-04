import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
                          ...state.products.map(
                            (product) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.inventory_2_outlined,
                              ),
                              title: Text(product.name),
                              subtitle: Text(product.brand ?? 'Sin marca'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  context.go(AppRoutes.product(product.id)),
                            ),
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
