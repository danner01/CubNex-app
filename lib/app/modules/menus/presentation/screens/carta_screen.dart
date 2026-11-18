import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/services/contact_service.dart';
import '../../../../common/services/json_cache.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/store_brand_theme.dart';
import '../../../business/data/models/store_customization_model.dart';
import '../../data/models/menu_model.dart';

const cartaPublicBaseUrl = 'https://conkkao-pwa.vercel.app';

String cartaPublicUrl(String slug) => '$cartaPublicBaseUrl/carta/$slug';

/// Carta publica de un negocio gastronomico o de servicios. Se abre desde un
/// enlace /carta/:slug (PWA o APK) sin necesidad de iniciar sesion y usa los
/// colores y el tema del propio negocio.
class CartaScreen extends StatefulWidget {
  const CartaScreen({required this.slug, super.key});

  final String slug;

  @override
  State<CartaScreen> createState() => _CartaScreenState();
}

class _CartaScreenState extends State<CartaScreen> {
  PublicCartaModel? _carta;
  bool _loading = true;
  String? _error;
  String _query = '';
  String _category = 'Todas';

  @override
  void initState() {
    super.initState();
    _load();
  }

  PublicCartaModel? _parseCarta(dynamic json) => json is Map
      ? PublicCartaModel.fromJson(Map<String, dynamic>.from(json))
      : null;

  Future<void> _load() async {
    final cacheKey = 'carta:${widget.slug}';
    final cached = _carta ?? _parseCarta(await JsonCache.read(cacheKey));
    if (!mounted) return;
    setState(() {
      _loading = cached == null;
      _carta = cached;
      _error = null;
    });
    final result = await sl<ApiClient>().get<PublicCartaModel?>(
      '/menus/carta/${Uri.encodeComponent(widget.slug)}',
      parser: (json) {
        final carta = _parseCarta(json);
        if (carta != null) JsonCache.save(cacheKey, json);
        return carta;
      },
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess && result.data != null) {
        _carta = result.data;
      } else if (_carta == null) {
        _error = result.error?.message ?? 'No se encontro la carta.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final carta = _carta;
    if (_loading || carta == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _goBack,
          ),
        ),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error ?? 'No se encontro la carta.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    final brand = StoreBrandTheme.fromCustomization(
      StoreCustomizationModel.fromBusinessColors(
        businessId: carta.businessId,
        colors: carta.colors,
      ),
      Theme.of(context).brightness,
    );
    final categories = <String>{
      for (final item in carta.items) item.category?.trim().isNotEmpty == true
          ? item.category!.trim()
          : 'Carta',
    }.toList();
    final query = _query.trim().toLowerCase();
    final visible = carta.items.where((item) {
      final category = item.category?.trim().isNotEmpty == true
          ? item.category!.trim()
          : 'Carta';
      if (_category != 'Todas' && category != _category) return false;
      if (query.isEmpty) return true;
      return '${item.name} ${item.description ?? ''} $category'
          .toLowerCase()
          .contains(query);
    }).toList();
    final grouped = <String, List<MenuItemModel>>{};
    for (final item in visible) {
      final key = item.category?.trim().isNotEmpty == true
          ? item.category!.trim()
          : 'Carta';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return Theme(
      data: brand.applyTo(Theme.of(context)),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: brand.background,
          body: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _CartaHero(
                    carta: carta,
                    brand: brand,
                    onBack: _goBack,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _CartaActions(
                      carta: carta,
                      slug: widget.slug,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Buscar en la carta',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: brand.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                if (categories.length > 1)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        children: [
                          for (final category in ['Todas', ...categories])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(category),
                                selected: _category == category,
                                selectedColor: brand.primary,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _category == category
                                      ? brand.onPrimary
                                      : brand.onSurface,
                                ),
                                onSelected: (_) =>
                                    setState(() => _category = category),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (grouped.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No hay platos para mostrar.')),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildListDelegate([
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                          child: Text(
                            entry.key,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        for (final item in entry.value)
                          _CartaItemTile(item: item, brand: brand),
                      ],
                      const SizedBox(height: 32),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }
}

class _CartaHero extends StatelessWidget {
  const _CartaHero({
    required this.carta,
    required this.brand,
    required this.onBack,
  });

  final PublicCartaModel carta;
  final StoreBrandTheme brand;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final onHero = readableOn(brand.primary);
    return Container(
      decoration: BoxDecoration(
        gradient: brand.heroGradient,
        image: carta.bannerUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(carta.bannerUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.45),
                  BlendMode.darken,
                ),
              ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton.filledTonal(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(height: 36),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (carta.logoUrl != null)
                Container(
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white54, width: 2),
                    image: DecorationImage(
                      image: NetworkImage(carta.logoUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  width: 72,
                  height: 72,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CARTA DIGITAL',
                      style: TextStyle(
                        color: carta.bannerUrl == null ? onHero : Colors.white,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      carta.businessName,
                      style: TextStyle(
                        color: carta.bannerUrl == null ? onHero : Colors.white,
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((carta.menuDescription ?? carta.businessDescription) != null) ...[
            const SizedBox(height: 10),
            Text(
              carta.menuDescription ?? carta.businessDescription!,
              style: TextStyle(
                color: (carta.bannerUrl == null ? onHero : Colors.white)
                    .withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in [
                carta.location,
                carta.address,
                carta.schedule,
              ])
                if (label != null && label.isNotEmpty)
                  Chip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartaActions extends StatelessWidget {
  const _CartaActions({required this.carta, required this.slug});

  final PublicCartaModel carta;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final phone = carta.whatsapp?.isNotEmpty == true
        ? carta.whatsapp
        : carta.phone;
    return Row(
      children: [
        if (phone != null && phone.isNotEmpty)
          Expanded(
            child: FilledButton.icon(
              onPressed: () => sl<ContactService>().openWhatsApp(
                phone,
                message: 'Hola, vi la carta de ${carta.businessName} en ConKkao.',
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Pedir'),
            ),
          ),
        if (phone != null && phone.isNotEmpty) const SizedBox(width: 8),
        if (carta.businessId.isNotEmpty)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.store(carta.businessId)),
              icon: const Icon(Icons.storefront_rounded),
              label: const Text('Negocio'),
            ),
          ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Copiar enlace',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: cartaPublicUrl(slug)));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enlace de la carta copiado.')),
              );
            }
          },
          icon: const Icon(Icons.link_rounded),
        ),
      ],
    );
  }
}

class _CartaItemTile extends StatelessWidget {
  const _CartaItemTile({required this.item, required this.brand});

  final MenuItemModel item;
  final StoreBrandTheme brand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: brand.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: brand.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              Container(
                width: 68,
                height: 68,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(item.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (item.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.description!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: brand.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${item.price.toStringAsFixed(item.price % 1 == 0 ? 0 : 2)} ${item.currency ?? 'CUP'}',
                style: TextStyle(
                  color: brand.onPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
