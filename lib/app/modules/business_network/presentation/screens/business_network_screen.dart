import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../business/presentation/widgets/business_switcher.dart';
import '../../../home/data/models/business_model.dart';
import '../../data/models/business_connection_model.dart';

class BusinessNetworkScreen extends StatefulWidget {
  const BusinessNetworkScreen({super.key});

  @override
  State<BusinessNetworkScreen> createState() => _BusinessNetworkScreenState();
}

class _BusinessNetworkScreenState extends State<BusinessNetworkScreen> {
  final _apiClient = sl<ApiClient>();
  var _loading = true;
  var _searching = false;
  String? _error;
  String _searchQuery = '';
  List<BusinessConnectionModel> _connections = const [];
  List<BusinessModel> _candidates = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final businessId = context
        .read<ActiveBusinessCubit>()
        .state
        .activeBusiness
        ?.id;
    if (businessId == null) {
      setState(() {
        _loading = false;
        _error = 'Selecciona un negocio activo.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _apiClient.get<List<BusinessConnectionModel>>(
      '/red-negocios',
      queryParameters: {'negocio_id': businessId},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) => BusinessConnectionModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
        return const [];
      },
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _connections = result.data ?? const [];
      _error = result.isSuccess ? null : result.error?.message;
    });
  }

  Future<void> _searchBusinesses(String query) async {
    final activeBusiness = context
        .read<ActiveBusinessCubit>()
        .state
        .activeBusiness;
    if (activeBusiness == null) return;

    setState(() {
      _searching = true;
      _searchQuery = query;
    });

    final filters = <String, Object>{
      'limit': 12,
      'order': 'destacado.desc,created_at.desc',
    };
    if (query.trim().isNotEmpty) {
      filters['q'] = query.trim();
    } else {
      final parentCategory = activeBusiness.businessParentCategory;
      if (parentCategory?.isNotEmpty == true) {
        filters['categoria_padre'] = parentCategory!;
      }
    }

    final result = await _apiClient.get<List<BusinessModel>>(
      '/negocios',
      queryParameters: filters,
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) =>
                    BusinessModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((business) => business.id != activeBusiness.id)
              .where(
                (business) => !_connections.any(
                  (connection) => connection.connectedBusinessId == business.id,
                ),
              )
              .toList();
        }
        return const [];
      },
    );

    if (!mounted) return;
    setState(() {
      _searching = false;
      _candidates = result.data ?? const [];
    });
  }

  Future<void> _connectBusiness(BusinessModel target) async {
    final activeBusiness = context
        .read<ActiveBusinessCubit>()
        .state
        .activeBusiness;
    if (activeBusiness == null) {
      showSnackOrAuthDialog(context, 'Selecciona un negocio activo.');
      return;
    }

    final payload = await showModalBottomSheet<_ConnectionPayload>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConnectBusinessSheet(target: target),
    );
    if (payload == null || !mounted) return;

    final result = await _apiClient.post<void>(
      '/red-negocios/conectar/${target.id}',
      data: {
        'negocio_id': activeBusiness.id,
        'tipo_relacion': payload.relationType,
        'notificaciones': payload.notifications,
        'productos_interes': payload.productsOfInterest,
        if (payload.notes.isNotEmpty) 'notas': payload.notes,
      },
      parser: (_) {},
    );

    if (!mounted) return;
    showSnackOrAuthDialog(
      context,
      result.isSuccess
          ? 'Conexion creada con ${target.name}.'
          : result.error?.message ?? 'No se pudo crear la conexion.',
    );
    if (result.isSuccess) {
      await _load();
      await _searchBusinesses(_searchQuery);
    }
  }

  Future<void> _toggleNotifications(
    BusinessConnectionModel connection,
    bool value,
  ) async {
    setState(() {
      _connections = _connections
          .map(
            (item) => item.id == connection.id
                ? item.copyWith(notifications: value)
                : item,
          )
          .toList();
    });
    final result = await _apiClient.put<void>(
      '/red-negocios/${connection.id}',
      data: {'notificaciones': value},
      parser: (_) {},
    );
    if (!result.isSuccess && mounted) {
      showSnackOrAuthDialog(
        context,
        result.error?.message ?? 'No se pudo actualizar la conexion.',
      );
      _load();
    }
  }

  Future<void> _requestProduct(BusinessConnectionModel connection) async {
    final product = await showModalBottomSheet<_SupplyRequestPayload>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SupplyRequestSheet(connection: connection),
    );
    if (product == null || !mounted) return;

    final result = await _apiClient.post<void>(
      '/solicitudes-red',
      data: {
        'conexion_id': connection.id,
        'negocio_solicitante_id': connection.businessId,
        'negocio_destino_id': connection.connectedBusinessId,
        if (product.productId != null) 'producto_id': product.productId,
        'nombre_producto': product.productName,
        'cantidad': product.quantity,
        'unidad': product.unit,
        'mensaje': product.message,
        if (product.price != null) 'precio_referencia': product.price,
        'moneda': product.currency,
      },
      parser: (_) {},
    );

    if (!mounted) return;
    showSnackOrAuthDialog(
      context,
      result.isSuccess
          ? 'Solicitud enviada a la red.'
          : result.error?.message ?? 'No se pudo enviar la solicitud.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeBusiness = context
        .watch<ActiveBusinessCubit>()
        .state
        .activeBusiness;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Conexiones',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                BusinessSwitcher(onChanged: _load),
                const SizedBox(height: 16),
                Text(
                  'Conecta proveedores, clientes mayoristas, aliados y deliverys. Recibe avisos cuando actualicen productos o solicita abastecimiento con antelacion.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _BusinessSearchPanel(
                  candidates: _candidates,
                  searching: _searching,
                  onChanged: _searchBusinesses,
                  onConnect: _connectBusiness,
                ),
                const SizedBox(height: 16),
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.list_alt_rounded), text: 'Lista'),
                    Tab(icon: Icon(Icons.hub_outlined), text: 'Diagrama'),
                  ],
                ),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.64,
                  child: TabBarView(
                    children: [
                      _NetworkList(
                        loading: _loading,
                        error: _error,
                        connections: _connections,
                        onToggleNotifications: _toggleNotifications,
                        onRequestProduct: _requestProduct,
                        onRefresh: _load,
                      ),
                      _NetworkDiagram(
                        centerName: activeBusiness?.name ?? 'Mi negocio',
                        centerLogo: activeBusiness?.logoUrl,
                        connections: _connections,
                        onTap: (connection) =>
                            _showConnectionDetails(connection),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConnectionDetails(BusinessConnectionModel connection) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConnectionDetailsSheet(
        connection: connection,
        onToggleNotifications: (value) =>
            _toggleNotifications(connection, value),
        onRequestProduct: () => _requestProduct(connection),
      ),
    );
  }
}

class _NetworkList extends StatelessWidget {
  const _NetworkList({
    required this.loading,
    required this.connections,
    required this.onToggleNotifications,
    required this.onRequestProduct,
    required this.onRefresh,
    this.error,
  });

  final bool loading;
  final String? error;
  final List<BusinessConnectionModel> connections;
  final Future<void> Function() onRefresh;
  final void Function(BusinessConnectionModel connection, bool value)
  onToggleNotifications;
  final void Function(BusinessConnectionModel connection) onRequestProduct;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (connections.isEmpty) {
      return const Center(
        child: Text(
          'Aun no tienes conexiones. Entra a un negocio desde el buscador y toca Conectar.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 14),
      itemCount: connections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final connection = connections[index];
        return _ConnectionCard(
          connection: connection,
          onToggleNotifications: (value) =>
              onToggleNotifications(connection, value),
          onRequestProduct: () => onRequestProduct(connection),
        );
      },
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connection,
    required this.onToggleNotifications,
    required this.onRequestProduct,
  });

  final BusinessConnectionModel connection;
  final ValueChanged<bool> onToggleNotifications;
  final VoidCallback onRequestProduct;

  @override
  Widget build(BuildContext context) {
    final business = connection.connectedBusiness;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: business?.logoUrl?.isNotEmpty == true
                      ? NetworkImage(business!.logoUrl!)
                      : null,
                  child: business?.logoUrl?.isNotEmpty == true
                      ? null
                      : const Icon(Icons.storefront_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business?.name ?? 'Negocio conectado',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(connection.relationLabel),
                    ],
                  ),
                ),
                Switch(
                  value: connection.notifications,
                  onChanged: onToggleNotifications,
                ),
              ],
            ),
            if (connection.products.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Productos actuales',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ...connection.products
                  .take(4)
                  .map(
                    (product) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(product.currentPrice ?? 0).toStringAsFixed(0)} ${product.currency ?? 'CUP'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.greenLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onRequestProduct,
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              label: const Text('Solicitar producto'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkDiagram extends StatefulWidget {
  const _NetworkDiagram({
    required this.centerName,
    required this.connections,
    required this.onTap,
    this.centerLogo,
  });

  final String centerName;
  final String? centerLogo;
  final List<BusinessConnectionModel> connections;
  final ValueChanged<BusinessConnectionModel> onTap;

  @override
  State<_NetworkDiagram> createState() => _NetworkDiagramState();
}

class _NetworkDiagramState extends State<_NetworkDiagram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.connections.isEmpty) {
      return const Center(
        child: Text('El diagrama aparecera cuando conectes negocios.'),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final center = Offset(size.width / 2, size.height / 2);
            final radius = math.min(size.width, size.height) * 0.34;
            return Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: _NetworkPainter(
                    count: widget.connections.length,
                    progress: _controller.value,
                    radius: radius,
                    center: center,
                  ),
                ),
                Positioned(
                  left: center.dx - 42,
                  top: center.dy - 42,
                  child: _NetworkAvatar(
                    label: widget.centerName,
                    imageUrl: widget.centerLogo,
                    highlighted: true,
                  ),
                ),
                ...List.generate(widget.connections.length, (index) {
                  final angle =
                      (math.pi * 2 / widget.connections.length) * index -
                      math.pi / 2;
                  final x = center.dx + math.cos(angle) * radius - 34;
                  final y = center.dy + math.sin(angle) * radius - 34;
                  final connection = widget.connections[index];
                  return Positioned(
                    left: x,
                    top: y,
                    child: GestureDetector(
                      onTap: () => widget.onTap(connection),
                      child: _NetworkAvatar(
                        label: connection.connectedBusiness?.name ?? 'Negocio',
                        imageUrl: connection.connectedBusiness?.logoUrl,
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}

class _NetworkPainter extends CustomPainter {
  const _NetworkPainter({
    required this.count,
    required this.progress,
    required this.radius,
    required this.center,
  });

  final int count;
  final double progress;
  final double radius;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.45)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final pulsePaint = Paint()
      ..color = AppColors.greenLight.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final angle = (math.pi * 2 / count) * i - math.pi / 2;
      final target = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawLine(center, target, linePaint);
      final t = (progress + i / math.max(count, 1)) % 1;
      final pulse = Offset.lerp(center, target, t)!;
      canvas.drawCircle(pulse, 3.5, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.count != count;
  }
}

class _NetworkAvatar extends StatelessWidget {
  const _NetworkAvatar({
    required this.label,
    this.imageUrl,
    this.highlighted = false,
  });

  final String label;
  final String? imageUrl;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(highlighted ? 4 : 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: highlighted ? AppColors.gold : AppColors.greenLight,
              width: highlighted ? 3 : 2,
            ),
          ),
          child: CircleAvatar(
            radius: highlighted ? 38 : 30,
            backgroundImage: imageUrl?.isNotEmpty == true
                ? NetworkImage(imageUrl!)
                : null,
            child: imageUrl?.isNotEmpty == true
                ? null
                : const Icon(Icons.storefront_rounded),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: highlighted ? 110 : 84,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _ConnectionDetailsSheet extends StatelessWidget {
  const _ConnectionDetailsSheet({
    required this.connection,
    required this.onToggleNotifications,
    required this.onRequestProduct,
  });

  final BusinessConnectionModel connection;
  final ValueChanged<bool> onToggleNotifications;
  final VoidCallback onRequestProduct;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              connection.connectedBusiness?.name ?? 'Conexion',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(connection.relationLabel),
            const SizedBox(height: 16),
            SwitchListTile(
              value: connection.notifications,
              onChanged: onToggleNotifications,
              contentPadding: EdgeInsets.zero,
              title: const Text('Recibir alertas de mercado'),
              subtitle: const Text(
                'Avisos por nuevos productos, stock y cambios de precio.',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onRequestProduct,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Solicitar abastecimiento'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplyRequestPayload {
  const _SupplyRequestPayload({
    required this.productName,
    required this.quantity,
    required this.currency,
    this.productId,
    this.unit,
    this.price,
    this.message,
  });

  final String productName;
  final double quantity;
  final String currency;
  final String? productId;
  final String? unit;
  final double? price;
  final String? message;
}

class _SupplyRequestSheet extends StatefulWidget {
  const _SupplyRequestSheet({required this.connection});

  final BusinessConnectionModel connection;

  @override
  State<_SupplyRequestSheet> createState() => _SupplyRequestSheetState();
}

class _SupplyRequestSheetState extends State<_SupplyRequestSheet> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitController = TextEditingController();
  final _messageController = TextEditingController();
  String? _productId;
  double? _price;
  var _currency = 'CUP';

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _selectProduct(String productId) {
    final product = widget.connection.products.firstWhere(
      (item) => item.id == productId,
    );
    setState(() {
      _productId = product.id;
      _nameController.text = product.name;
      _price = product.currentPrice;
      _currency = product.currency ?? 'CUP';
    });
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
              'Solicitar producto',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (widget.connection.products.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _productId,
                decoration: const InputDecoration(
                  labelText: 'Producto publicado',
                ),
                items: widget.connection.products
                    .map(
                      (product) => DropdownMenuItem(
                        value: product.id,
                        child: Text(product.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) _selectProduct(value);
                },
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Producto o servicio requerido',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: 'Unidad'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mensaje',
                hintText: 'Ej: necesito 5 sacos para el viernes.',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final name = _nameController.text.trim();
                final quantity =
                    double.tryParse(
                      _quantityController.text.trim().replaceAll(',', '.'),
                    ) ??
                    0;
                if (name.isEmpty || quantity <= 0) {
                  showSnackOrAuthDialog(
                    context,
                    'Completa producto y cantidad.',
                  );
                  return;
                }
                Navigator.of(context).pop(
                  _SupplyRequestPayload(
                    productId: _productId,
                    productName: name,
                    quantity: quantity,
                    unit: _unitController.text.trim().isEmpty
                        ? null
                        : _unitController.text.trim(),
                    price: _price,
                    currency: _currency,
                    message: _messageController.text.trim().isEmpty
                        ? null
                        : _messageController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Enviar solicitud'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessSearchPanel extends StatefulWidget {
  const _BusinessSearchPanel({
    required this.candidates,
    required this.searching,
    required this.onChanged,
    required this.onConnect,
  });

  final List<BusinessModel> candidates;
  final bool searching;
  final ValueChanged<String> onChanged;
  final ValueChanged<BusinessModel> onConnect;

  @override
  State<_BusinessSearchPanel> createState() => _BusinessSearchPanelState();
}

class _BusinessSearchPanelState extends State<_BusinessSearchPanel> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChanged(''));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Encontrar negocios para conectar',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: 'Buscar proveedor, mayorista, delivery...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: widget.searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.candidates.isEmpty)
              Text(
                widget.searching
                    ? 'Buscando...'
                    : 'Te mostraremos sugerencias por tipo de negocio o por busqueda.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final business = widget.candidates[index];
                    return SizedBox(
                      width: 220,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => widget.onConnect(business),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage:
                                          business.logoUrl?.isNotEmpty == true
                                          ? NetworkImage(business.logoUrl!)
                                          : null,
                                      child:
                                          business.logoUrl?.isNotEmpty == true
                                          ? null
                                          : const Icon(
                                              Icons.storefront_rounded,
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        business.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  business.businessTypeName ??
                                      business.province ??
                                      'Negocio',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                FilledButton.tonalIcon(
                                  onPressed: () => widget.onConnect(business),
                                  icon: const Icon(
                                    Icons.hub_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Conectar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionPayload {
  const _ConnectionPayload({
    required this.relationType,
    required this.notifications,
    required this.productsOfInterest,
    required this.notes,
  });

  final String relationType;
  final bool notifications;
  final List<String> productsOfInterest;
  final String notes;
}

class _ConnectBusinessSheet extends StatefulWidget {
  const _ConnectBusinessSheet({required this.target});

  final BusinessModel target;

  @override
  State<_ConnectBusinessSheet> createState() => _ConnectBusinessSheetState();
}

class _ConnectBusinessSheetState extends State<_ConnectBusinessSheet> {
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
              'Conectar con ${widget.target.name}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _relationType,
              decoration: const InputDecoration(labelText: 'Tipo de conexion'),
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
                labelText: 'Productos o servicios de interes',
                hintText: 'arroz, cerveza, delivery, pan...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas o condiciones',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notifications,
              onChanged: (value) => setState(() => _notifications = value),
              title: const Text('Recibir notificaciones'),
              subtitle: const Text(
                'Cambios de precio, stock, publicaciones y solicitudes.',
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
                Navigator.of(context).pop(
                  _ConnectionPayload(
                    relationType: _relationType,
                    notifications: _notifications,
                    productsOfInterest: interests,
                    notes: _notesController.text.trim(),
                  ),
                );
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
