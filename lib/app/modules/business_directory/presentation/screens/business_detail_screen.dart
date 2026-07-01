import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/blocs/app_session/app_session_cubit.dart';
import '../../../../common/entities/user_role.dart';
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
import '../../../home/data/models/business_model.dart';
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
        BlocProvider(
          create: (_) => sl<BusinessDetailCubit>()..load(businessId),
        ),
        BlocProvider(
          create: (_) =>
              sl<EngagementCubit>()..loadBusinessFollowState(businessId),
        ),
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

class _BusinessDetailView extends StatefulWidget {
  const _BusinessDetailView();

  @override
  State<_BusinessDetailView> createState() => _BusinessDetailViewState();
}

class _BusinessDetailViewState extends State<_BusinessDetailView> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'todas';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BusinessDetailCubit, BusinessDetailState>(
      listener: (context, state) {
        if (state.message != null && state.message!.isNotEmpty) {
          showSnackOrAuthDialog(context, state.message);
        }
      },
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

        final session = context.watch<AppSessionCubit>().state;
        final activeBusiness = context
            .watch<ActiveBusinessCubit>()
            .state
            .activeBusiness;
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
        final catalogTitle = business.isFoodBusiness
            ? 'Menu y ofertas'
            : business.isServiceLike
            ? 'Servicios'
            : 'Productos de la tienda';
        final categories = _productCategories(state.products);
        final canConnectAsBusiness =
            activeBusiness != null &&
            activeBusiness.id != business.id &&
            (session.role == UserRole.businessAdmin ||
                session.role == UserRole.superadmin ||
                session.role == UserRole.delivery);
        final filteredProducts = state.products.where((product) {
          final text = [
            product.name,
            product.brand,
            product.description,
            product.features['categoria'],
            product.features['categoria_sugerida'],
          ].whereType<Object>().join(' ').toLowerCase();
          final matchesQuery =
              _query.trim().isEmpty ||
              text.contains(_query.trim().toLowerCase());
          final categoryValue = _categoryForProduct(product);
          final matchesCategory =
              _category == 'todas' || categoryValue == _category;
          return matchesQuery && matchesCategory;
        }).toList();

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
                      location: [business.municipality, business.province]
                          .where((value) => value != null && value.isNotEmpty)
                          .join(', '),
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
                          child: BlocBuilder<EngagementCubit, EngagementState>(
                            builder: (context, engagement) {
                              return OutlinedButton.icon(
                                onPressed: engagement.isFollowing
                                    ? () => showSnackOrAuthDialog(
                                        context,
                                        'Ya sigues este negocio.',
                                      )
                                    : () => context
                                          .read<EngagementCubit>()
                                          .followBusiness(business.id),
                                icon: Icon(
                                  engagement.isFollowing
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: engagement.isFollowing
                                      ? AppColors.goldDark
                                      : null,
                                ),
                                label: Text(
                                  engagement.isFollowing
                                      ? 'Siguiendo'
                                      : 'Seguir',
                                ),
                              );
                            },
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
                    if (canConnectAsBusiness) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _openConnectionSheet(
                            context,
                            sourceBusinessId: activeBusiness.id,
                            targetBusinessId: business.id,
                            targetName: business.name,
                          ),
                          icon: const Icon(Icons.hub_outlined),
                          label: const Text('Conectar con mi negocio'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _ContactCard(
                      phone: business.phone,
                      whatsapp: business.whatsapp,
                    ),
                    const SizedBox(height: 12),
                    _OperationalInfoCard(business: business),
                    const SizedBox(height: 22),
                    SectionHeader(title: catalogTitle),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: business.isServiceLike
                            ? 'Buscar servicios dentro del negocio'
                            : 'Buscar productos dentro de la tienda',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    if (categories.length > 1) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: categories
                              .map(
                                (category) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      category == 'todas' ? 'Todas' : category,
                                    ),
                                    selected: _category == category,
                                    onSelected: (_) =>
                                        setState(() => _category = category),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
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
                      _EmptyProducts(label: catalogTitle)
                    else if (filteredProducts.isEmpty)
                      _EmptyProducts(label: 'No hay resultados para ese filtro')
                    else
                      SizedBox(
                        height: 238,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredProducts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return ProductPreviewCard(
                              name: product.name,
                              brand: product.brand,
                              imageUrl: product.imageUrl,
                              price: product.currentPrice,
                              currency: product.currency,
                              onTap: () =>
                                  context.go(AppRoutes.product(product.id)),
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
                      ...state.reviews.map(
                        (review) => _ReviewCard(
                          review: review,
                          isOwnReview:
                              review.userId != null &&
                              review.userId == session.userId,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  List<String> _productCategories(List<dynamic> products) {
    final values = <String>{'todas'};
    for (final product in products) {
      final category = _categoryForProduct(product);
      if (category.isNotEmpty) values.add(category);
    }
    return values.toList();
  }

  String _categoryForProduct(dynamic product) {
    final features = product.features as Map<String, dynamic>;
    final raw =
        features['categoria'] ??
        features['categoria_sugerida'] ??
        features['departamento'] ??
        product.brand;
    return raw?.toString().trim() ?? '';
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
      business.whatsapp?.isNotEmpty == true
          ? business.whatsapp
          : business.phone,
      message: 'Hola, vi ${business.name} en CubNex.',
    );
    if (message != null && context.mounted) {
      showSnackOrAuthDialog(context, message);
    }
  }

  void _openConnectionSheet(
    BuildContext context, {
    required String sourceBusinessId,
    required String targetBusinessId,
    required String targetName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<BusinessDetailCubit>(),
        child: _BusinessConnectionSheet(
          sourceBusinessId: sourceBusinessId,
          targetBusinessId: targetBusinessId,
          targetName: targetName,
        ),
      ),
    );
  }
}

class _BusinessConnectionSheet extends StatefulWidget {
  const _BusinessConnectionSheet({
    required this.sourceBusinessId,
    required this.targetBusinessId,
    required this.targetName,
  });

  final String sourceBusinessId;
  final String targetBusinessId;
  final String targetName;

  @override
  State<_BusinessConnectionSheet> createState() =>
      _BusinessConnectionSheetState();
}

class _BusinessConnectionSheetState extends State<_BusinessConnectionSheet> {
  final _productsController = TextEditingController();
  final _notesController = TextEditingController();
  var _relationType = 'proveedor';
  var _notifications = true;

  @override
  void dispose() {
    _productsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conectar con ${widget.targetName}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _relationType,
              decoration: const InputDecoration(labelText: 'Relacion'),
              items: const [
                DropdownMenuItem(
                  value: 'proveedor',
                  child: Text('Este negocio me provee'),
                ),
                DropdownMenuItem(
                  value: 'cliente_mayorista',
                  child: Text('Yo le suministro'),
                ),
                DropdownMenuItem(
                  value: 'aliado',
                  child: Text('Aliado comercial'),
                ),
                DropdownMenuItem(
                  value: 'delivery',
                  child: Text('Delivery asociado'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _relationType = value ?? 'proveedor'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _productsController,
              decoration: const InputDecoration(
                labelText: 'Productos o servicios',
                hintText: 'arroz, bebidas, transporte...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notifications,
              onChanged: (value) => setState(() => _notifications = value),
              title: const Text('Recibir notificaciones'),
              subtitle: const Text(
                'Stock, precios, publicaciones y pedidos B2B.',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                final interests = _productsController.text
                    .split(',')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList();
                context.read<BusinessDetailCubit>().connectBusiness(
                  sourceBusinessId: widget.sourceBusinessId,
                  targetBusinessId: widget.targetBusinessId,
                  relationType: _relationType,
                  notifications: _notifications,
                  productsOfInterest: interests,
                  notes: _notesController.text,
                );
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.hub_outlined),
              label: const Text('Crear conexion'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.isOwnReview});

  final ReviewModel review;
  final bool isOwnReview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isOwnReview ? () => _openEditSheet(context) : null,
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
                  if (isOwnReview)
                    TextButton.icon(
                      onPressed: () => _openEditSheet(context),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Editar'),
                    )
                  else
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
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
      ),
    );
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<BusinessDetailCubit>(),
        child: _ReviewFormSheet(review: review),
      ),
    );
  }
}

class _ReviewFormSheet extends StatefulWidget {
  const _ReviewFormSheet({this.review});

  final ReviewModel? review;

  @override
  State<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<_ReviewFormSheet> {
  final _commentController = TextEditingController();
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    final review = widget.review;
    if (review != null) {
      _rating = review.rating == 0 ? 5 : review.rating;
      _commentController.text = review.comment ?? '';
    }
  }

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
              widget.review == null ? 'Escribir resena' : 'Editar resena',
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
                final comment = _commentController.text.trim().isEmpty
                    ? null
                    : _commentController.text.trim();
                final cubit = context.read<BusinessDetailCubit>();
                final review = widget.review;
                if (review == null) {
                  cubit.createReview(rating: _rating, comment: comment);
                } else {
                  cubit.updateReview(
                    reviewId: review.id,
                    rating: _rating,
                    comment: comment,
                  );
                }
                Navigator.of(context).pop();
              },
              icon: Icon(
                widget.review == null
                    ? Icons.send_outlined
                    : Icons.save_outlined,
              ),
              label: Text(widget.review == null ? 'Publicar' : 'Guardar'),
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
                                  color: brand.onSurface.withValues(
                                    alpha: 0.72,
                                  ),
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
            subtitle: Text(
              phone?.isNotEmpty == true ? phone! : 'No configurado',
            ),
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

class _OperationalInfoCard extends StatelessWidget {
  const _OperationalInfoCard({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    final schedule = [
      _formatTime(business.openingTime),
      _formatTime(business.closingTime),
    ].where((value) => value != null && value.isNotEmpty).join(' - ');
    final location = [
      business.address,
      business.municipality,
      business.province,
    ].where((value) => value != null && value.isNotEmpty).join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              business.isServiceLike
                  ? 'Disponibilidad y cobertura'
                  : 'Horario y disponibilidad',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.schedule_rounded,
              label: 'Horario',
              value: schedule.isEmpty ? 'No configurado' : schedule,
            ),
            _InfoRow(
              icon: business.availableNow
                  ? Icons.check_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              label: 'Estado',
              value: business.availableNow
                  ? 'Disponible ahora'
                  : 'No disponible en este momento',
            ),
            _InfoRow(
              icon: business.acceptsTransfer
                  ? Icons.account_balance_outlined
                  : Icons.payments_outlined,
              label: 'Pagos',
              value: business.acceptsTransfer
                  ? 'Acepta pagos por transferencia'
                  : 'Pago presencial o coordinado con el negocio',
            ),
            if (location.isNotEmpty)
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Ubicacion',
                value: location,
              ),
            if (business.requiresElectricity) ...[
              _InfoRow(
                icon: Icons.electric_bolt_outlined,
                label: 'Red electrica',
                value: business.hasElectricService
                    ? 'Con corriente de la red'
                    : 'Sin corriente de la red',
              ),
              _InfoRow(
                icon: Icons.battery_charging_full_rounded,
                label: 'Respaldo',
                value: business.hasElectricBackup
                    ? 'Tiene respaldo${business.electricBackupType?.isNotEmpty == true ? ' (${business.electricBackupType})' : ''}'
                    : 'Sin respaldo configurado',
              ),
              if (business.electricBlock?.isNotEmpty == true ||
                  business.electricCircuit?.isNotEmpty == true)
                _InfoRow(
                  icon: Icons.grid_4x4_rounded,
                  label: 'Bloque / circuito',
                  value: [business.electricBlock, business.electricCircuit]
                      .where((value) => value != null && value.isNotEmpty)
                      .join(' / '),
                ),
            ],
            if (business.businessTypeName?.isNotEmpty == true)
              _InfoRow(
                icon: Icons.storefront_rounded,
                label: 'Tipo',
                value: business.businessTypeName!,
              ),
          ],
        ),
      ),
    );
  }

  String? _formatTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(trimmed);
    if (match == null) return trimmed;
    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.label});

  final String label;

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
            Text(
              'Aun no hay ${label.toLowerCase()} publicados.',
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
