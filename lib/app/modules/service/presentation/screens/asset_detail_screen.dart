import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../common/services/share_service.dart';
import '../../../favorites/blocs/engagement/engagement_cubit.dart';
import '../../../favorites/blocs/engagement/engagement_state.dart';
import '../../blocs/asset_detail/asset_detail_cubit.dart';
import '../../blocs/asset_detail/asset_detail_state.dart';
import '../../data/models/asset_detail_model.dart';

class AssetDetailScreen extends StatelessWidget {
  const AssetDetailScreen({
    required this.assetId,
    required this.kind,
    super.key,
  });

  final String assetId;
  final AssetDetailKind kind;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AssetDetailCubit>()..load(id: assetId, kind: kind)),
        BlocProvider(create: (_) => sl<EngagementCubit>()),
      ],
      child: const _EngagementListener(child: _AssetDetailView()),
    );
  }
}

class _EngagementListener extends StatelessWidget {
  const _EngagementListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<EngagementCubit, EngagementState>(
      listener: (context, state) {
        if (state.status == EngagementStatus.success ||
            state.status == EngagementStatus.failure) {
          showSnackOrAuthDialog(context, state.message);
        }
      },
      child: child,
    );
  }
}

class _AssetDetailView extends StatelessWidget {
  const _AssetDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AssetDetailCubit, AssetDetailState>(
        listener: (context, state) {
          if (state.message != null) {
            showSnackOrAuthDialog(context, state.message);
          }
        },
        builder: (context, state) {
          if (state.status == AssetDetailStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == AssetDetailStatus.failure ||
              state.asset == null) {
            return _MessageView(
              icon: Icons.error_outline_rounded,
              title: 'No disponible',
              message: state.message ?? 'No se pudo abrir esta publicacion.',
            );
          }

          final asset = state.asset!;
          final price = _mainPrice(asset);

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                children: [
                  _HeroImage(asset: asset),
                  const SizedBox(height: 18),
                  Text(
                    asset.kindLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    asset.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  if (price != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      price,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _InfoCard(
                    icon: _iconFor(asset),
                    title: asset.type ?? asset.kindLabel,
                    subtitle: _location(asset),
                  ),
                  if (asset.kind == AssetDetailKind.transport) ...[
                    const SizedBox(height: 12),
                    _InfoCard(
                      icon: Icons.local_shipping_outlined,
                      title: asset.vehicleType ?? 'Vehiculo',
                      subtitle: _transportPrice(asset),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Descripcion',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    asset.description?.isNotEmpty == true
                        ? asset.description!
                        : 'Contacta al negocio para confirmar disponibilidad, precio y condiciones.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareAsset(context),
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Compartir'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: 'Guardar favorito',
                        onPressed: () => _favoriteAsset(context),
                        icon: const Icon(Icons.favorite_border_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: state.status == AssetDetailStatus.saving
                              ? null
                              : () => _showRequestSheet(context),
                          icon: state.status == AssetDetailStatus.saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded),
                          label: const Text('Solicitar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _mainPrice(AssetDetailModel asset) {
    if (asset.price != null) {
      return '${asset.price!.toStringAsFixed(0)} ${asset.currency ?? 'CUP'}';
    }
    if (asset.basePrice != null) {
      return 'Desde ${asset.basePrice!.toStringAsFixed(0)} ${asset.currency ?? 'CUP'}';
    }
    return null;
  }

  String _transportPrice(AssetDetailModel asset) {
    final parts = [
      if (asset.basePrice != null)
        'Base ${asset.basePrice!.toStringAsFixed(0)} ${asset.currency ?? 'CUP'}',
      if (asset.pricePerKm != null)
        '${asset.pricePerKm!.toStringAsFixed(0)} ${asset.currency ?? 'CUP'}/km',
    ];
    if (parts.isEmpty) return 'Precio a consultar';
    return parts.join(' - ');
  }

  String _location(AssetDetailModel asset) {
    return [
      asset.municipality,
      asset.province,
      asset.address,
    ].where((item) => item != null && item.isNotEmpty).join(' - ');
  }

  IconData _iconFor(AssetDetailModel asset) {
    if (asset.kind == AssetDetailKind.transport) {
      return switch (asset.type) {
        'delivery' => Icons.delivery_dining_outlined,
        'taxi' || 'pasajeros' => Icons.local_taxi_outlined,
        _ => Icons.local_shipping_outlined,
      };
    }
    return switch (asset.type) {
      'auto' || 'moto' => Icons.directions_car_outlined,
      'terreno' || 'finca' => Icons.terrain_outlined,
      _ => Icons.home_work_outlined,
    };
  }

  Future<void> _shareAsset(BuildContext context) async {
    final asset = context.read<AssetDetailCubit>().state.asset;
    if (asset == null) return;
    final entityType = switch (asset.kind) {
      AssetDetailKind.property => 'propiedad',
      AssetDetailKind.transport => 'servicio',
    };
    final message = await sl<ShareService>().shareEntity(
      entityType: entityType,
      entityId: asset.id,
      title: asset.title,
      message: asset.description,
    );
    if (message != null && context.mounted) {
      showSnackOrAuthDialog(context, message);
    }
  }

  void _showRequestSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<AssetDetailCubit>(),
        child: const _AssetRequestSheet(),
      ),
    );
  }

  void _favoriteAsset(BuildContext context) {
    final asset = context.read<AssetDetailCubit>().state.asset;
    if (asset == null) return;
    final engagement = context.read<EngagementCubit>();
    switch (asset.kind) {
      case AssetDetailKind.property:
        engagement.favoriteProperty(asset.id);
      case AssetDetailKind.transport:
        engagement.favoriteTransport(asset.id);
    }
  }
}

class _AssetRequestSheet extends StatefulWidget {
  const _AssetRequestSheet();

  @override
  State<_AssetRequestSheet> createState() => _AssetRequestSheetState();
}

class _AssetRequestSheetState extends State<_AssetRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = context.watch<AssetDetailCubit>().state.asset;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enviar solicitud',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(asset?.title ?? 'Publicacion seleccionada'),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe tu nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefono'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje para el negocio',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Enviar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AssetDetailCubit>().submitRequest(
      contactName: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      message: _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim(),
    );
    Navigator.of(context).pop();
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.asset});

  final AssetDetailModel asset;

  @override
  Widget build(BuildContext context) {
    final imageUrl = asset.images.isEmpty ? null : asset.images.first;

    return AspectRatio(
      aspectRatio: 1.1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceVariant
              : AppColors.lightSurfaceVariant,
          child: imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Icon(_fallbackIcon(asset), size: 64),
                )
              : Icon(_fallbackIcon(asset), size: 64),
        ),
      ),
    );
  }

  IconData _fallbackIcon(AssetDetailModel asset) {
    return asset.kind == AssetDetailKind.transport
        ? Icons.local_shipping_outlined
        : Icons.home_work_outlined;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Theme.of(context).colorScheme.onSecondary,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle.isEmpty ? 'Sin datos adicionales' : subtitle),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
