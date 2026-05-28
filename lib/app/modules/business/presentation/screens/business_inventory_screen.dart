import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/injection/injection.dart';
import '../../../../config/theme/app_colors.dart';
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message!)));
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
                    (product) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSecondary,
                          child: const Icon(Icons.inventory_2_outlined),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(product.brand ?? 'Sin marca'),
                        trailing: Text(
                          product.currentPrice == null
                              ? 'Consultar'
                              : '${product.currentPrice!.toStringAsFixed(0)} ${product.currency ?? 'CUP'}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet();

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
  String _currency = 'CUP';
  bool _detecting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
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
                  'Nuevo producto',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
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
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar producto'),
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
    context.read<BusinessInventoryCubit>().createProduct(
      name: _nameController.text.trim(),
      brand: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      price: double.parse(_priceController.text.trim()),
      currency: _currency,
      stock: int.tryParse(_stockController.text.trim()),
    );
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
