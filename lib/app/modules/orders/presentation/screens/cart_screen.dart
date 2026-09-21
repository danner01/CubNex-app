import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/blocs/app_session/app_session_cubit.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../address/presentation/widgets/location_picker_sheet.dart';
import '../../../business_network/data/models/business_connection_model.dart';
import '../../../home/data/models/business_model.dart';
import '../../blocs/cart/cart_cubit.dart';
import '../../blocs/cart/cart_state.dart';
import '../../data/models/cart_delivery_selection_model.dart';
import '../../data/models/cart_item_model.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CartView();
  }
}

class _CartView extends StatefulWidget {
  const _CartView();

  @override
  State<_CartView> createState() => _CartViewState();
}

class _CartViewState extends State<_CartView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _deliveryReferenceController = TextEditingController();
  final _discountController = TextEditingController();
  final Map<String, BusinessModel> _businessDetailsCache = {};
  PickedLocation? _deliveryLocation;
  bool _prefilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    _deliveryAddressController.dispose();
    _deliveryReferenceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    final session = context.read<AppSessionCubit>().state;
    if (session.status == AppSessionStatus.authenticated &&
        session.email?.isNotEmpty == true) {
      _emailController.text = session.email!;
      unawaited(_loadProfilePrefill());
    }
    _prefilled = true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CartCubit, CartState>(
      listener: (context, state) {
        if (state.status == CartStatus.success ||
            state.status == CartStatus.failure) {
          showSnackOrAuthDialog(context, state.message);
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Carrito',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text('${state.totalItems} productos seleccionados.'),
              const SizedBox(height: 18),
              if (state.items.isEmpty)
                const _EmptyCart()
              else ...[
                ..._groupItems(state.items).entries.map(
                  (entry) => _BusinessCartGroup(
                    businessId: entry.key,
                    items: entry.value,
                    requestDelivery:
                        state.deliveryByBusiness[entry.key] ?? false,
                    selectedDelivery:
                        state.deliverySelectionByBusiness[entry.key],
                    onRequestDeliveryChanged: (value) {
                      context.read<CartCubit>().setDeliveryForBusiness(
                        entry.key,
                        value,
                      );
                    },
                    onSelectDelivery: () => _selectDeliveryForBusiness(entry.key),
                  ),
                ),
                const SizedBox(height: 18),
                _ContactForm(
                  formKey: _formKey,
                  nameController: _nameController,
                  phoneController: _phoneController,
                  emailController: _emailController,
                  messageController: _messageController,
                  deliveryAddressController: _deliveryAddressController,
                  deliveryReferenceController: _deliveryReferenceController,
                  discountController: _discountController,
                  requiresDelivery: state.deliveryByBusiness.values.any(
                    (value) => value,
                  ),
                  selectedDeliveryLocation: _deliveryLocation,
                  onPickDeliveryLocation: () =>
                      unawaited(_pickDeliveryLocation()),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total estimado',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '${state.total.toStringAsFixed(0)} CUP',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: state.status == CartStatus.submitting
                      ? null
                      : _submit,
                  icon: state.status == CartStatus.submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Enviar solicitud'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadProfilePrefill() async {
    final result = await sl<ApiClient>().get<Map<String, dynamic>>(
      '/usuarios/perfil',
      parser: (json) {
        if (json is Map) return Map<String, dynamic>.from(json);
        return const {};
      },
    );
    if (!mounted || !result.isSuccess) return;
    final profile = result.data ?? const {};
    void setIfEmpty(TextEditingController controller, Object? value) {
      final text = value?.toString().trim() ?? '';
      if (controller.text.trim().isEmpty && text.isNotEmpty) {
        controller.text = text;
      }
    }

    setIfEmpty(
      _nameController,
      profile['nombre_completo'] ?? profile['nombre'],
    );
    setIfEmpty(_phoneController, profile['telefono'] ?? profile['phone']);
    setIfEmpty(_emailController, profile['email']);
    setIfEmpty(
      _deliveryAddressController,
      profile['direccion'] ??
          profile['direccion_entrega'] ??
          profile['address'] ??
          profile['ubicacion_texto'],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final cartCubit = context.read<CartCubit>();
      final activeBusinessCubit = context.read<ActiveBusinessCubit>();
      final cartState = cartCubit.state;
      final grouped = _groupItems(cartCubit.state.items);
      final nextDeliverySelections = Map<String, CartDeliverySelection>.from(
        cartState.deliverySelectionByBusiness,
      );
      final autoAssignedSelections = <String, CartDeliverySelection>{};
      final activeBusinessId = activeBusinessCubit.state.activeBusiness?.id;
      var autoAssigned = 0;
      for (final businessId in grouped.keys) {
        if (businessId == 'sin-negocio') continue;
        final requestDelivery =
            cartState.deliveryByBusiness[businessId] ?? false;
        if (!requestDelivery) continue;
        if (nextDeliverySelections.containsKey(businessId)) continue;

        final candidates = await _loadDeliveryCandidates(
          targetBusinessId: businessId,
          activeBusinessId: activeBusinessId,
        );
        final preferred = await _pickBestDeliveryCandidate(
          targetBusinessId: businessId,
          candidates: candidates,
        );
        if (preferred != null) {
          final autoSelected = preferred.copyWith(assignmentMode: 'auto');
          nextDeliverySelections[businessId] = autoSelected;
          autoAssignedSelections[businessId] = autoSelected;
          autoAssigned++;
        }
      }
      if (!mounted) return;
      if (autoAssigned > 0) {
        for (final entry in autoAssignedSelections.entries) {
          cartCubit.setDeliverySelectionForBusiness(entry.key, entry.value);
        }
        showSnackOrAuthDialog(
          context,
          autoAssigned == 1
              ? 'Se autoasigno 1 delivery preferente.'
              : 'Se autoasignaron $autoAssigned deliveries preferentes.',
        );
      }

      final requesterBusinessId = activeBusinessCubit.state.activeBusiness?.id;
      await cartCubit.submit(
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
        deliveryAddress: _deliveryAddressController.text.trim().isEmpty
            ? null
            : _deliveryAddressController.text.trim(),
        deliveryReference: _deliveryReferenceController.text.trim().isEmpty
            ? null
            : _deliveryReferenceController.text.trim(),
        deliveryLatitude: _deliveryLocation?.latitude,
        deliveryLongitude: _deliveryLocation?.longitude,
        discountCode: _discountController.text.trim().isEmpty
            ? null
            : _discountController.text.trim(),
        requesterBusinessId: requesterBusinessId,
        deliverySelectionByBusiness: cartCubit.state.deliverySelectionByBusiness,
      );
    } catch (error) {
      if (!mounted) return;
      showSnackOrAuthDialog(
        context,
        'No se pudo procesar el envio con delivery. Intenta de nuevo. Detalle: $error',
      );
    }
  }

  Future<void> _pickDeliveryLocation() async {
    final picked = await showModalBottomSheet<PickedLocation>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LocationPickerSheet(
        initialLatitude: _deliveryLocation?.latitude,
        initialLongitude: _deliveryLocation?.longitude,
        title: 'Punto de entrega',
        description:
            'Toca el mapa para marcar la direccion de entrega. Puedes acercar o alejar con dos dedos.',
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _deliveryLocation = picked);
    final resolvedAddress = picked.address?.trim();
    if (resolvedAddress != null && resolvedAddress.isNotEmpty) {
      _deliveryAddressController.text = resolvedAddress;
      return;
    }
    if (_deliveryAddressController.text.trim().isEmpty) {
      _deliveryAddressController.text =
          'Ubicacion en mapa (${picked.latitude.toStringAsFixed(5)}, ${picked.longitude.toStringAsFixed(5)})';
    }
  }

  Future<void> _selectDeliveryForBusiness(String targetBusinessId) async {
    if (targetBusinessId == 'sin-negocio') {
      showSnackOrAuthDialog(
        context,
        'No se puede asociar delivery para productos sin negocio.',
      );
      return;
    }

    final activeBusinessId = context
        .read<ActiveBusinessCubit>()
        .state
        .activeBusiness
        ?.id;
    final candidates = await _loadDeliveryCandidates(
      targetBusinessId: targetBusinessId,
      activeBusinessId: activeBusinessId,
    );
    if (!mounted) return;
    if (candidates.isEmpty) {
      showSnackOrAuthDialog(
        context,
        'No se encontraron deliveries disponibles ahora.',
      );
      return;
    }

    final selected = await showModalBottomSheet<CartDeliverySelection>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DeliverySelectionSheet(
        candidates: candidates,
        selected: context
            .read<CartCubit>()
            .state
            .deliverySelectionByBusiness[targetBusinessId],
      ),
    );
    if (!mounted || selected == null) return;
    final previous = context
        .read<CartCubit>()
        .state
        .deliverySelectionByBusiness[targetBusinessId];
    context.read<CartCubit>().setDeliverySelectionForBusiness(
      targetBusinessId,
      selected.copyWith(assignmentMode: 'manual'),
    );
    showSnackOrAuthDialog(
      context,
      previous == null
          ? 'Delivery asociado y guardado.'
          : 'Delivery actualizado y guardado.',
    );
  }

  Future<List<CartDeliverySelection>> _loadDeliveryCandidates({
    required String targetBusinessId,
    String? activeBusinessId,
  }) async {
    final api = sl<ApiClient>();
    final byId = <String, CartDeliverySelection>{};

    final repartidoresResult = await api.get<List<Map<String, dynamic>>>(
      '/repartidores',
      queryParameters: const {'solo_disponibles': 'true', 'limit': 200},
      parser: (json) {
        if (json is! List) return const <Map<String, dynamic>>[];
        return json
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      },
    );
    if (repartidoresResult.isSuccess) {
      for (final perfil in repartidoresResult.data ?? const <Map<String, dynamic>>[]) {
        final perfilId = '${perfil['id'] ?? ''}';
        if (perfilId.isEmpty) continue;
        final nombre = '${perfil['nombre'] ?? ''}';
        final negocioId = '${perfil['negocio_id'] ?? ''}';
        final tieId = 'repartidor:$perfilId';
        byId.putIfAbsent(
          tieId,
          () => CartDeliverySelection(
            deliveryBusinessId: negocioId.isNotEmpty && negocioId != 'null' ? negocioId : tieId,
            deliveryBusinessName: nombre.isEmpty
                ? 'Repartidor ${_shortId(perfilId)}'
                : nombre,
            source: 'repartidor',
            province: perfil['negocio_provincia']?.toString(),
            municipality: perfil['negocio_municipio']?.toString(),
            deliveryPerfilId: perfilId,
            email: perfil['email']?.toString(),
            telefono: perfil['telefono']?.toString(),
            tipoVehiculo: perfil['tipo_vehiculo']?.toString(),
            calificacion: (perfil['calificacion_promedio'] as num?)?.toDouble(),
          ),
        );
      }
    }

    if (activeBusinessId != null && activeBusinessId.isNotEmpty) {
      final connectedResult = await api.get<List<BusinessConnectionModel>>(
        '/red-negocios',
        queryParameters: {'negocio_id': activeBusinessId, 'limit': 80},
        parser: (json) {
          if (json is! List) return const <BusinessConnectionModel>[];
          return json
              .whereType<Map>()
              .map(
                (item) => BusinessConnectionModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        },
      );
      if (connectedResult.isSuccess) {
        for (final connection in connectedResult.data ?? const <BusinessConnectionModel>[]) {
          if (!connection.isActive) continue;
          if (connection.connectedBusinessId == targetBusinessId) continue;
          final type = connection.relationType.trim().toLowerCase();
          final business = connection.connectedBusiness;
          final isDeliveryConnection =
              type == 'delivery' ||
              _isDeliveryRelationType(type) ||
              _isLikelyDeliveryBusiness(business);
          if (!isDeliveryConnection) continue;
          final name =
              business?.name ??
              connection.notes ??
              'Delivery conectado ${_shortId(connection.connectedBusinessId)}';
          byId.putIfAbsent(
            connection.connectedBusinessId,
            () => CartDeliverySelection(
              deliveryBusinessId: connection.connectedBusinessId,
              deliveryBusinessName: name,
              source: 'conexion',
              province: business?.province,
              municipality: business?.municipality,
            ),
          );
        }
      }
    }

    final systemResult = await api.get<List<BusinessModel>>(
      '/negocios',
      queryParameters: {'limit': 60, 'order': 'destacado.desc,created_at.desc'},
      parser: (json) {
        if (json is! List) return const <BusinessModel>[];
        return json
            .whereType<Map>()
            .map((item) => BusinessModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      },
    );
    if (systemResult.isSuccess) {
      for (final business in systemResult.data ?? const <BusinessModel>[]) {
        if (business.id == targetBusinessId) continue;
        final isDeliveryBusiness = _isLikelyDeliveryBusiness(business);
        if (!isDeliveryBusiness) continue;
        byId.putIfAbsent(
          business.id,
          () => CartDeliverySelection(
            deliveryBusinessId: business.id,
            deliveryBusinessName: business.name,
            source: 'sistema',
            province: business.province,
            municipality: business.municipality,
          ),
        );
      }
    }

    return byId.values.toList()
      ..sort((a, b) {
        if (a.source == b.source) {
          return a.deliveryBusinessName.compareTo(b.deliveryBusinessName);
        }
        const priority = {'repartidor': 0, 'conexion': 1, 'sistema': 2};
        return (priority[a.source] ?? 9).compareTo(priority[b.source] ?? 9);
      });
  }

  Future<CartDeliverySelection?> _pickBestDeliveryCandidate({
    required String targetBusinessId,
    required List<CartDeliverySelection> candidates,
  }) async {
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;

    final target = await _loadBusinessDetails(targetBusinessId);
    final targetMunicipality = _normalizeZone(target?.municipality);
    final targetProvince = _normalizeZone(target?.province);

    int proximityRank(CartDeliverySelection candidate) {
      final candidateMunicipality = _normalizeZone(candidate.municipality);
      final candidateProvince = _normalizeZone(candidate.province);
      if (targetMunicipality.isNotEmpty &&
          candidateMunicipality.isNotEmpty &&
          targetMunicipality == candidateMunicipality) {
        return 0;
      }
      if (targetProvince.isNotEmpty &&
          candidateProvince.isNotEmpty &&
          targetProvince == candidateProvince) {
        return 1;
      }
      if (candidate.source == 'repartidor') return 0;
      if (candidate.source == 'conexion') return 2;
      return 3;
    }

    final sorted = [...candidates]..sort((a, b) {
      final proximityA = proximityRank(a);
      final proximityB = proximityRank(b);
      if (proximityA != proximityB) return proximityA.compareTo(proximityB);
      final sourceRankA = a.source == 'conexion' ? 0 : 1;
      final sourceRankB = b.source == 'conexion' ? 0 : 1;
      if (sourceRankA != sourceRankB) return sourceRankA.compareTo(sourceRankB);
      return a.deliveryBusinessName.compareTo(b.deliveryBusinessName);
    });
    return sorted.first;
  }

  Future<BusinessModel?> _loadBusinessDetails(String businessId) async {
    final cached = _businessDetailsCache[businessId];
    if (cached != null) return cached;
    final result = await sl<ApiClient>().get<BusinessModel?>(
      '/negocios/$businessId',
      parser: (json) {
        if (json is List && json.isNotEmpty && json.first is Map) {
          return BusinessModel.fromJson(
            Map<String, dynamic>.from(json.first as Map),
          );
        }
        if (json is Map) {
          return BusinessModel.fromJson(Map<String, dynamic>.from(json));
        }
        return null;
      },
    );
    final business = result.data;
    if (business != null) {
      _businessDetailsCache[businessId] = business;
    }
    return business;
  }

  String _normalizeZone(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  bool _isDeliveryRelationType(String relationType) {
    final type = relationType.trim().toLowerCase();
    return type.contains('delivery') ||
        type.contains('reparto') ||
        type.contains('mensaj') ||
        type.contains('logistic') ||
        type.contains('envio') ||
        type.contains('transporte');
  }

  bool _isLikelyDeliveryBusiness(BusinessModel? business) {
    if (business == null) return false;
    final parent = (business.businessParentCategory ?? '').trim().toLowerCase();
    final type = (business.businessTypeName ?? '').trim().toLowerCase();
    final name = business.name.trim().toLowerCase();
    final featureDelivery = business.features['delivery'] == true;
    return parent == 'transporte' ||
        type.contains('delivery') ||
        type.contains('reparto') ||
        type.contains('mensaj') ||
        type.contains('logistic') ||
        type.contains('envio') ||
        type.contains('transporte') ||
        name.contains('delivery') ||
        name.contains('reparto') ||
        name.contains('mensaj') ||
        featureDelivery;
  }

  String _shortId(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'sistema';
    if (text.length <= 6) return text;
    return text.substring(0, 6);
  }

  Map<String, List<CartItemModel>> _groupItems(List<CartItemModel> items) {
    final grouped = <String, List<CartItemModel>>{};
    for (final item in items) {
      final key = item.product.businessId ?? 'sin-negocio';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }
}

class _BusinessCartGroup extends StatelessWidget {
  const _BusinessCartGroup({
    required this.businessId,
    required this.items,
    required this.requestDelivery,
    required this.selectedDelivery,
    required this.onRequestDeliveryChanged,
    required this.onSelectDelivery,
  });

  final String businessId;
  final List<CartItemModel> items;
  final bool requestDelivery;
  final CartDeliverySelection? selectedDelivery;
  final ValueChanged<bool> onRequestDeliveryChanged;
  final VoidCallback onSelectDelivery;

  @override
  Widget build(BuildContext context) {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final shortBusinessId = businessId.length > 8
        ? businessId.substring(0, 8)
        : businessId;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: businessId == 'sin-negocio'
                      ? Text(
                          'Productos sin negocio',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        )
                      : _BusinessNameText(
                          businessId: businessId,
                          initialName: _businessNameFromItems(items),
                          fallback: 'Negocio $shortBusinessId',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                ),
                Text(
                  '${subtotal.toStringAsFixed(0)} CUP',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.storefront_outlined),
                  label: Text('Recoger'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.delivery_dining_outlined),
                  label: Text('Delivery'),
                ),
              ],
              selected: {requestDelivery},
              onSelectionChanged: (selection) =>
                  onRequestDeliveryChanged(selection.first),
            ),
            if (requestDelivery && businessId != 'sin-negocio') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedDelivery == null
                          ? 'Delivery: auto-asignado por el negocio'
                          : 'Delivery: ${selectedDelivery!.deliveryBusinessName}',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onSelectDelivery,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(
                      selectedDelivery == null ? 'Asociar' : 'Cambiar',
                    ),
                  ),
                ],
              ),
              if (selectedDelivery != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedDelivery!.source == 'conexion'
                            ? 'Fuente: conexiones del negocio'
                            : 'Fuente: sistema',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            selectedDelivery!.assignmentMode == 'auto'
                                ? 'Autoasignado'
                                : 'Manual',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 10),
            ...items.map(_CartItemTile.new),
          ],
        ),
      ),
    );
  }

  String? _businessNameFromItems(List<CartItemModel> items) {
    for (final item in items) {
      final name = item.product.businessName?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }
}

class _BusinessNameText extends StatefulWidget {
  const _BusinessNameText({
    required this.businessId,
    required this.initialName,
    required this.fallback,
    this.style,
  });

  final String businessId;
  final String? initialName;
  final String fallback;
  final TextStyle? style;

  @override
  State<_BusinessNameText> createState() => _BusinessNameTextState();
}

class _BusinessNameTextState extends State<_BusinessNameText> {
  String? _resolvedName;

  @override
  void initState() {
    super.initState();
    _resolvedName = widget.initialName;
    if (_resolvedName == null || _resolvedName!.trim().isEmpty) {
      unawaited(_loadBusinessName());
    }
  }

  @override
  void didUpdateWidget(covariant _BusinessNameText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) {
      _resolvedName = widget.initialName;
      if (_resolvedName == null || _resolvedName!.trim().isEmpty) {
        unawaited(_loadBusinessName());
      }
    }
  }

  Future<void> _loadBusinessName() async {
    final result = await sl<ApiClient>().get<String?>(
      '/negocios/${widget.businessId}',
      parser: (json) {
        if (json is List && json.isNotEmpty && json.first is Map) {
          return (json.first as Map)['nombre']?.toString();
        }
        if (json is Map) return json['nombre']?.toString();
        return null;
      },
    );
    if (!mounted || !result.isSuccess) return;
    final name = result.data?.trim();
    if (name == null || name.isEmpty) return;
    setState(() => _resolvedName = name);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _resolvedName?.trim().isNotEmpty == true
          ? _resolvedName!.trim()
          : widget.fallback,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile(this.item);

  final CartItemModel item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              child: const Icon(Icons.inventory_2_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.subtotal.toStringAsFixed(0)} ${item.product.currency ?? 'CUP'}',
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => context.read<CartCubit>().updateQuantity(
                item.product.id,
                item.quantity - 1,
              ),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '${item.quantity}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            IconButton(
              onPressed: () => context.read<CartCubit>().updateQuantity(
                item.product.id,
                item.quantity + 1,
              ),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactForm extends StatelessWidget {
  const _ContactForm({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.messageController,
    required this.deliveryAddressController,
    required this.deliveryReferenceController,
    required this.discountController,
    required this.requiresDelivery,
    required this.selectedDeliveryLocation,
    required this.onPickDeliveryLocation,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController messageController;
  final TextEditingController deliveryAddressController;
  final TextEditingController deliveryReferenceController;
  final TextEditingController discountController;
  final bool requiresDelivery;
  final PickedLocation? selectedDeliveryLocation;
  final VoidCallback onPickDeliveryLocation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Datos de contacto',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe tu nombre'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefono'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              if (requiresDelivery) ...[
                Text(
                  'Direccion para delivery',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: deliveryAddressController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Direccion de entrega',
                    hintText: 'Escribe tu direccion o una referencia cercana',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) {
                    if (!requiresDelivery) return null;
                    return value == null || value.trim().isEmpty
                        ? 'Agrega la direccion de entrega'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onPickDeliveryLocation,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    selectedDeliveryLocation == null
                        ? 'Seleccionar direccion en mapa'
                        : 'Mapa: ${selectedDeliveryLocation!.latitude.toStringAsFixed(4)}, ${selectedDeliveryLocation!.longitude.toStringAsFixed(4)}',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: deliveryReferenceController,
                  minLines: 1,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Referencia de entrega',
                    hintText: 'Ej: edificio azul, apto 3B, entre calles...',
                    prefixIcon: Icon(Icons.pin_drop_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Si la tienda no tiene delivery, puedes asociar uno en cada bloque de negocio.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mensaje para el negocio',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: discountController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Codigo de descuento',
                  hintText: 'Opcional si tienes promocion de la tienda',
                  prefixIcon: Icon(Icons.local_offer_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliverySelectionSheet extends StatefulWidget {
  const _DeliverySelectionSheet({
    required this.candidates,
    this.selected,
  });

  final List<CartDeliverySelection> candidates;
  final CartDeliverySelection? selected;

  @override
  State<_DeliverySelectionSheet> createState() => _DeliverySelectionSheetState();
}

class _DeliverySelectionSheetState extends State<_DeliverySelectionSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final filtered = widget.candidates.where((candidate) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      return candidate.deliveryBusinessName.toLowerCase().contains(query);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleccionar delivery',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Buscar delivery...',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final candidate = filtered[index];
                  final selected =
                      widget.selected?.deliveryBusinessId ==
                      candidate.deliveryBusinessId;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: selected
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: candidate.source == 'repartidor'
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        candidate.source == 'repartidor'
                            ? Icons.delivery_dining_rounded
                            : (candidate.source == 'conexion'
                                ? Icons.hub_outlined
                                : Icons.public_rounded),
                        size: 22,
                        color: candidate.source == 'repartidor'
                            ? Theme.of(context).colorScheme.onSecondaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(
                      candidate.deliveryBusinessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      candidate.source == 'repartidor'
                          ? [
                              if (candidate.tipoVehiculo?.trim().isNotEmpty == true)
                                candidate.tipoVehiculo!.trim(),
                              if (candidate.calificacion != null &&
                                  candidate.calificacion! > 0)
                                '★ ${candidate.calificacion!.toStringAsFixed(1)}',
                              ...(candidate.email?.trim().isNotEmpty == true
                                  ? [candidate.email!.trim()]
                                  : []),
                            ].join(' · ')
                          : (candidate.source == 'conexion'
                              ? 'Conectado a tu negocio'
                              : 'Disponible en el sistema'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: selected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: Theme.of(context).colorScheme.secondary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(candidate),
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

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 10),
            const Text(
              'Agrega productos desde una ficha para enviar una solicitud al negocio.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
