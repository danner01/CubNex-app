import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../common/services/share_service.dart';
import '../../../favorites/blocs/engagement/engagement_cubit.dart';
import '../../../favorites/blocs/engagement/engagement_state.dart';
import '../../../orders/blocs/cart/cart_cubit.dart';
import '../../blocs/product_detail/product_detail_cubit.dart';
import '../../blocs/product_detail/product_detail_state.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<ProductDetailCubit>()..load(productId)),
        BlocProvider(create: (_) => sl<EngagementCubit>()),
      ],
      child: const _EngagementListener(child: _ProductDetailView()),
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

class _ProductDetailView extends StatelessWidget {
  const _ProductDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ProductDetailCubit, ProductDetailState>(
        builder: (context, state) {
          if (state.status == ProductDetailStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == ProductDetailStatus.failure ||
              state.product == null) {
            return _ErrorView(message: state.errorMessage ?? 'Producto no disponible.');
          }

          final product = state.product!;
          final price = product.currentPrice == null
              ? 'Consultar'
              : '${product.currentPrice!.toStringAsFixed(0)} ${product.currency ?? 'CUP'}';

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                children: [
                  _ProductImage(imageUrl: product.imageUrl),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          price,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => context
                            .read<EngagementCubit>()
                            .favoriteProduct(product.id),
                        icon: const Icon(Icons.favorite_border_rounded),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () => _shareProduct(context),
                        icon: const Icon(Icons.share_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  if (product.brand != null && product.brand!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      product.brand!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _InfoCard(
                    icon: Icons.local_shipping_outlined,
                    title: 'Entrega y cobertura',
                    subtitle: 'Consulta disponibilidad, entrega o recogida con el negocio.',
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.verified_outlined,
                    title: 'Vendedor verificado',
                    subtitle: 'Abre la tienda para ver mas productos, reseñas y contacto.',
                    onTap: product.businessId == null
                        ? null
                        : () => context.go(AppRoutes.store(product.businessId!)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Descripcion',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description?.isNotEmpty == true
                        ? product.description!
                        : 'Este producto esta disponible en CubNex. Contacta al negocio para confirmar detalles, stock y entrega.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
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
                          onPressed: product.businessId == null
                              ? null
                              : () => context.go(AppRoutes.store(product.businessId!)),
                          icon: const Icon(Icons.storefront_rounded),
                          label: const Text('Tienda'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            context.read<CartCubit>().addProduct(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Producto agregado al carrito.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.shopping_cart_outlined),
                          label: const Text('Agregar'),
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

  Future<void> _shareProduct(BuildContext context) async {
    final product = context.read<ProductDetailCubit>().state.product;
    if (product == null) return;
    final message = await sl<ShareService>().shareEntity(
      entityType: 'producto',
      entityId: product.id,
      title: product.name,
      message: product.description,
    );
    if (message != null && context.mounted) {
      showSnackOrAuthDialog(context, message);
    }
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceVariant
              : AppColors.lightSurfaceVariant,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.inventory_2_outlined, size: 56),
                )
              : const Icon(Icons.inventory_2_outlined, size: 56),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
