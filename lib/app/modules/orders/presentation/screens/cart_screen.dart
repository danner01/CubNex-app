import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/blocs/app_session/app_session_cubit.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../blocs/cart/cart_cubit.dart';
import '../../blocs/cart/cart_state.dart';
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
  final _discountController = TextEditingController();
  bool _prefilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    _deliveryAddressController.dispose();
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
                    onRequestDeliveryChanged: (value) => context
                        .read<CartCubit>()
                        .setDeliveryForBusiness(entry.key, value),
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
                  discountController: _discountController,
                  requiresDelivery: state.deliveryByBusiness.values.any(
                    (value) => value,
                  ),
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
                      : () => _submit(context),
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
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<CartCubit>().submit(
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
      discountCode: _discountController.text.trim().isEmpty
          ? null
          : _discountController.text.trim(),
    );
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
    required this.onRequestDeliveryChanged,
  });

  final String businessId;
  final List<CartItemModel> items;
  final bool requestDelivery;
  final ValueChanged<bool> onRequestDeliveryChanged;

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
    required this.discountController,
    required this.requiresDelivery,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController messageController;
  final TextEditingController deliveryAddressController;
  final TextEditingController discountController;
  final bool requiresDelivery;

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
                Text(
                  'Pendiente: selector de mapa y transportistas disponibles.',
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
