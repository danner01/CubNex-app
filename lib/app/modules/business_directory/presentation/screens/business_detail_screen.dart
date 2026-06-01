import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../common/presentation/widgets/market_cards.dart';
import '../../../../common/services/contact_service.dart';
import '../../../../common/services/share_service.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/store_brand_theme.dart';
import '../../../business/data/models/store_customization_model.dart';
import '../../../favorites/blocs/engagement/engagement_cubit.dart';
import '../../../favorites/blocs/engagement/engagement_state.dart';
import '../../../review_rating/data/models/review_model.dart';
import '../../blocs/business_detail/business_detail_cubit.dart';
import '../../blocs/business_detail/business_detail_state.dart';

class BusinessDetailScreen extends StatelessWidget {
  const BusinessDetailScreen({required this.businessId, super.key});

  final String businessId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<BusinessDetailCubit>()..load(businessId)),
        BlocProvider(create: (_) => sl<EngagementCubit>()),
      ],
      child: const _EngagementListener(child: _BusinessDetailView()),
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

class _BusinessDetailView extends StatelessWidget {
  const _BusinessDetailView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BusinessDetailCubit, BusinessDetailState>(
      builder: (context, state) {
        if (state.status == BusinessDetailStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.status == BusinessDetailStatus.failure ||
            state.business == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.errorMessage ?? 'No se pudo cargar la tienda.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final business = state.business!;
        final customization =
            state.customization ??
            StoreCustomizationModel.fromBusinessColors(
              businessId: business.id,
              colors: business.colors,
            );
        final brand = StoreBrandTheme.fromCustomization(
          customization,
          Theme.of(context).brightness,
        );

        return Theme(
          data: brand.applyTo(Theme.of(context)),
          child: Builder(
            builder: (context) {
              return Scaffold(
                backgroundColor: brand.background,
                body: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    _BusinessHero(
                      name: business.name,
                      description: business.description,
                      logoUrl: business.logoUrl,
                      bannerUrl: business.bannerUrl,
                      rating: business.rating,
                      brand: brand,
                      location: [
                        business.municipality,
                        business.province,
                      ].where((value) => value != null && value.isNotEmpty).join(', '),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _openBusinessChat(context),
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            label: const Text('Chat'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context
                                .read<EngagementCubit>()
                                .followBusiness(business.id),
                            icon: const Icon(Icons.favorite_border_rounded),
                            label: const Text('Seguir'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          tooltip: 'Compartir',
                          onPressed: () => _shareBusiness(context),
                          icon: const Icon(Icons.share_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _ContactCard(phone: business.phone, whatsapp: business.whatsapp),
                    const SizedBox(height: 22),
                    SectionHeader(title: 'Productos de la tienda'),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => context
                          .read<EngagementCubit>()
                          .favoriteBusiness(business.id),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Guardar negocio en favoritos'),
                    ),
                    const SizedBox(height: 12),
                    if (state.products.isEmpty)
                      const _EmptyProducts()
                    else
                      SizedBox(
                        height: 238,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: state.products.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final product = state.products[index];
                            return ProductPreviewCard(
                              name: product.name,
                              brand: product.brand,
                              imageUrl: product.imageUrl,
                              price: product.currentPrice,
                              currency: product.currency,
                              onTap: () => context.go(AppRoutes.product(product.id)),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 22),
                    SectionHeader(title: 'Resenas'),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => BlocProvider.value(
                          value: context.read<BusinessDetailCubit>(),
                          child: const _ReviewFormSheet(),
                        ),
                      ),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Escribir resena'),
                    ),
                    const SizedBox(height: 12),
                    if (state.reviews.isEmpty)
                      const _EmptyReviews()
                    else
                      ...state.reviews.map((review) => _ReviewCard(review: review)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _shareBusiness(BuildContext context) async {
    final business = context.read<BusinessDetailCubit>().state.business;
    if (business == null) return;
    final message = await sl<ShareService>().shareEntity(
      entityType: 'negocio',
      entityId: business.id,
      title: business.name,
      message: business.description,
    );
    if (message != null && context.mounted) {
      showSnackOrAuthDialog(context, message);
    }
  }

  Future<void> _openBusinessChat(BuildContext context) async {
    final business = context.read<BusinessDetailCubit>().state.business;
    if (business == null) return;
    final message = await sl<ContactService>().openWhatsApp(
      business.whatsapp?.isNotEmpty == true ? business.whatsapp : business.phone,
      message: 'Hola, vi ${business.name} en CubNex.',
    );
    if (message != null && context.mounted) {
      showSnackOrAuthDialog(context, message);
    }
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: AppColors.goldDark,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Text(
                  '${review.usefulCount} utiles',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.comment!),
            ],
            if (review.businessResponse != null &&
                review.businessResponse!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Respuesta: ${review.businessResponse!}'),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    context.read<BusinessDetailCubit>().markUseful(review.id),
                icon: const Icon(Icons.thumb_up_alt_outlined),
                label: const Text('Util'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewFormSheet extends StatefulWidget {
  const _ReviewFormSheet();

  @override
  State<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<_ReviewFormSheet> {
  final _commentController = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escribir resena',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(
                5,
                (index) => IconButton(
                  onPressed: () => setState(() => _rating = index + 1),
                  icon: Icon(
                    index < _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: AppColors.goldDark,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Comentario',
                hintText: 'Cuenta como fue tu experiencia',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                context.read<BusinessDetailCubit>().createReview(
                  rating: _rating,
                  comment: _commentController.text.trim().isEmpty
                      ? null
                      : _commentController.text.trim(),
                );
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessHero extends StatelessWidget {
  const _BusinessHero({
    required this.name,
    required this.brand,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.rating,
    this.location,
  });

  final String name;
  final StoreBrandTheme brand;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final double? rating;
  final String? location;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(gradient: brand.heroGradient),
              child: bannerUrl != null && bannerUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: bannerUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    )
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: brand.primary,
                  foregroundColor: brand.onPrimary,
                  backgroundImage: logoUrl != null && logoUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(logoUrl!)
                      : null,
                  child: logoUrl == null || logoUrl!.isEmpty
                      ? const Icon(Icons.storefront_rounded, size: 34)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.04,
                          color: brand.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: AppColors.goldDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating?.toStringAsFixed(1) ?? '0.0',
                            style: TextStyle(
                              color: brand.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (location != null && location!.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                location!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: brand.onSurface.withValues(alpha: 0.72),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (description != null && description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: brand.onSurface.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ],
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

class _ContactCard extends StatelessWidget {
  const _ContactCard({this.phone, this.whatsapp});

  final String? phone;
  final String? whatsapp;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            onTap: phone?.isNotEmpty == true
                ? () => _openPhone(context, phone)
                : null,
            leading: Icon(
              Icons.phone_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
            title: const Text('Telefono'),
            subtitle: Text(phone?.isNotEmpty == true ? phone! : 'No configurado'),
            trailing: phone?.isNotEmpty == true
                ? const Icon(Icons.call_outlined)
                : null,
          ),
          ListTile(
            onTap: whatsapp?.isNotEmpty == true
                ? () => _openWhatsApp(context, whatsapp)
                : null,
            leading: Icon(
              Icons.message_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
            title: const Text('WhatsApp'),
            subtitle: Text(
              whatsapp?.isNotEmpty == true ? whatsapp! : 'No configurado',
            ),
            trailing: whatsapp?.isNotEmpty == true
                ? const Icon(Icons.open_in_new_rounded)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _openPhone(BuildContext context, String? value) async {
    final message = await sl<ContactService>().openPhone(value);
    if (message != null && context.mounted) {
      showSnackOrAuthDialog(context, message);
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String? value) async {
    final message = await sl<ContactService>().openWhatsApp(value);
    if (message != null && context.mounted) {
      showSnackOrAuthDialog(context, message);
    }
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 10),
            const Text(
              'Esta tienda todavia no tiene productos publicados.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 10),
            const Text(
              'Esta tienda todavia no tiene resenas.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
