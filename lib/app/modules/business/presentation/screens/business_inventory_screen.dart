import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../home/data/models/product_model.dart';
import '../../blocs/inventory/business_inventory_cubit.dart';
import '../../blocs/inventory/business_inventory_state.dart';

class BusinessInventoryScreen extends StatelessWidget {
  const BusinessInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BusinessInventoryCubit>()..load(),
      child: const _BusinessInventoryView(),
    );
  }
}

class _BusinessInventoryView extends StatelessWidget {
  const _BusinessInventoryView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BusinessInventoryCubit, BusinessInventoryState>(
      listener: (context, state) {
        if (state.message != null &&
            (state.status == BusinessInventoryStatus.failure ||
                state.status == BusinessInventoryStatus.success)) {
          showSnackOrAuthDialog(context, state.message);
        }
      },
      builder: (context, state) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: state.business == null
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => BlocProvider.value(
                      value: context.read<BusinessInventoryCubit>(),
                      child: const _ProductFormSheet(),
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: const Text('Producto'),
          ),
          body: RefreshIndicator(
            onRefresh: () => context.read<BusinessInventoryCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Text(
                  'Inventario',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.business == null
                      ? 'Carga o crea tu negocio para administrar productos.'
                      : 'Negocio: ${state.business!.name}',
                ),
                const SizedBox(height: 18),
                if (state.status == BusinessInventoryStatus.loading)
                  const Center(child: CircularProgressIndicator())
                else if (state.business == null)
                  const _EmptyInventory(
                    icon: Icons.storefront_outlined,
                    message: 'No encontramos un negocio asociado a tu usuario.',
                  )
                else if (state.products.isEmpty)
                  const _EmptyInventory(
                    icon: Icons.inventory_2_outlined,
                    message: 'Todavia no hay productos cargados.',
                  )
                else
                  ...state.products.map(
                    (product) => _InventoryProductCard(product: product),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InventoryProductCard extends StatelessWidget {
  const _InventoryProductCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final category = product.features['categoria']?.toString();
    final image = product.imageUrl;
    final visible = product.canBuy;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => BlocProvider.value(
            value: context.read<BusinessInventoryCubit>(),
            child: _ProductFormSheet(product: product),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: image == null
                      ? ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => BlocProvider.value(
                                  value: context.read<BusinessInventoryCubit>(),
                                  child: _ProductFormSheet(product: product),
                                ),
                              );
                            }
                            if (value == 'delete') {
                              _confirmDelete(context);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [product.brand, category].whereType<String>().join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniStatusChip(
                          icon: Icons.inventory_outlined,
                          label: 'Stock ${product.stock ?? 0}',
                        ),
                        _MiniStatusChip(
                          icon: visible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          label: visible ? 'Visible' : 'Oculto',
                          active: visible,
                        ),
                        if (!product.inInventory)
                          const _MiniStatusChip(
                            icon: Icons.remove_shopping_cart_outlined,
                            label: 'Fuera de inventario',
                            active: false,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.currentPrice == null
                          ? 'Precio a consultar'
                          : '${product.currentPrice!.toStringAsFixed(0)} ${product.currency ?? 'CUP'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('Vas a eliminar "${product.name}" del inventario.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      context.read<BusinessInventoryCubit>().deleteProduct(product);
    }
  }
}

class _MiniStatusChip extends StatelessWidget {
  const _MiniStatusChip({
    required this.icon,
    required this.label,
    this.active = true,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({this.product});

  final ProductModel? product;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();
  final _image1Controller = TextEditingController();
  final _image2Controller = TextEditingController();
  final _image3Controller = TextEditingController();
  String _currency = 'CUP';
  bool _inInventory = true;
  bool _purchasable = true;
  bool _detecting = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product == null) return;
    _nameController.text = product.name;
    _brandController.text = product.brand ?? '';
    _descriptionController.text = product.description ?? '';
    _priceController.text = product.price?.toStringAsFixed(2) ?? '';
    _stockController.text = product.stock?.toString() ?? '';
    _categoryController.text = product.features['categoria']?.toString() ?? '';
    _currency = product.currency ?? 'CUP';
    _inInventory = product.inInventory;
    _purchasable = product.purchasable && product.available;
    if (product.imageUrls.isNotEmpty) {
      _image1Controller.text = product.imageUrls.elementAtOrNull(0) ?? '';
      _image2Controller.text = product.imageUrls.elementAtOrNull(1) ?? '';
      _image3Controller.text = product.imageUrls.elementAtOrNull(2) ?? '';
    } else if (product.imageUrl != null) {
      _image1Controller.text = product.imageUrl!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _image1Controller.dispose();
    _image2Controller.dispose();
    _image3Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  _isEditing ? 'Editar producto' : 'Nuevo producto',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _detecting
                            ? null
                            : () => _pickAndDetect(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Camara'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _detecting
                            ? null
                            : () => _pickAndDetect(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galeria'),
                      ),
                    ),
                  ],
                ),
                if (_detecting) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Analizando etiqueta con IA...'),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(labelText: 'Marca'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Categoria del producto',
                    hintText: 'Ej: Bebidas, alimentos, piezas, servicios',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripcion'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Precio'),
                        validator: (value) =>
                            double.tryParse(value?.trim() ?? '') == null
                            ? 'Precio invalido'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 112,
                      child: DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(labelText: 'Moneda'),
                        items: const [
                          DropdownMenuItem(value: 'CUP', child: Text('CUP')),
                          DropdownMenuItem(value: 'MLC', child: Text('MLC')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (value) =>
                            setState(() => _currency = value ?? 'CUP'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stock'),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _inInventory,
                  onChanged: (value) => setState(() => _inInventory = value),
                  title: const Text('Agregar al inventario'),
                  subtitle: const Text(
                    'Permite controlar stock y reservas para este producto.',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _purchasable,
                  onChanged: (value) => setState(() => _purchasable = value),
                  title: const Text('Visible para clientes'),
                  subtitle: const Text(
                    'Solo aparece en tienda si esta activo, en inventario y con stock.',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Imagenes del producto',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _image1Controller,
                  decoration: const InputDecoration(
                    labelText: 'Imagen principal URL',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _image2Controller,
                  decoration: const InputDecoration(
                    labelText: 'Imagen adicional 1 URL',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _image3Controller,
                  decoration: const InputDecoration(
                    labelText: 'Imagen adicional 2 URL',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'El plan base permite hasta 3 fotos. Planes superiores podran ampliar este limite.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _isEditing ? 'Guardar cambios' : 'Guardar producto',
                  ),
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
    final cubit = context.read<BusinessInventoryCubit>();
    final product = widget.product;
    final imageUrls = [
      _image1Controller.text.trim(),
      _image2Controller.text.trim(),
      _image3Controller.text.trim(),
    ].where((url) => url.isNotEmpty).toList();
    final brand = _brandController.text.trim().isEmpty
        ? null
        : _brandController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    if (product == null) {
      cubit.createProduct(
        name: _nameController.text.trim(),
        brand: brand,
        description: description,
        price: double.parse(_priceController.text.trim()),
        currency: _currency,
        stock: int.tryParse(_stockController.text.trim()),
        category: _categoryController.text.trim(),
        imageUrls: imageUrls,
        inInventory: _inInventory,
        purchasable: _purchasable,
      );
    } else {
      cubit.updateProduct(
        product: product,
        name: _nameController.text.trim(),
        brand: brand,
        description: description,
        price: double.parse(_priceController.text.trim()),
        currency: _currency,
        stock: int.tryParse(_stockController.text.trim()),
        category: _categoryController.text.trim(),
        imageUrls: imageUrls,
        inInventory: _inInventory,
        purchasable: _purchasable,
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickAndDetect(ImageSource source) async {
    final inventoryCubit = context.read<BusinessInventoryCubit>();
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1400,
    );
    if (image == null || !mounted) return;

    setState(() => _detecting = true);
    try {
      final bytes = await image.readAsBytes();
      final detection = await inventoryCubit.detectLabel(base64Encode(bytes));
      if (!mounted || detection == null) return;
      if (detection.name != null) _nameController.text = detection.name!;
      if (detection.brand != null) _brandController.text = detection.brand!;
      if (detection.description != null) {
        _descriptionController.text = detection.description!;
      }
      if (detection.category != null) {
        _categoryController.text = detection.category!;
      }
      if (detection.price != null) {
        _priceController.text = detection.price!.toStringAsFixed(2);
      }
      if (detection.currency != null &&
          ['CUP', 'MLC', 'USD'].contains(detection.currency)) {
        setState(() => _currency = detection.currency!);
      }
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }
}

class _EmptyInventory extends StatelessWidget {
  const _EmptyInventory({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
              'Puedes crear el negocio desde el wizard y volver a esta vista.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.lightTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
