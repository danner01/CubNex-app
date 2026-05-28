import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/injection/injection.dart';
import '../../blocs/menus/menus_cubit.dart';
import '../../blocs/menus/menus_state.dart';
import '../../data/models/menu_model.dart';

class BusinessMenusScreen extends StatelessWidget {
  const BusinessMenusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MenusCubit>()..loadMine(),
      child: const _BusinessMenusView(),
    );
  }
}

class _BusinessMenusView extends StatelessWidget {
  const _BusinessMenusView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => BlocProvider.value(
            value: context.read<MenusCubit>(),
            child: const _MenuFormSheet(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Menu'),
      ),
      body: BlocConsumer<MenusCubit, MenusState>(
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message!)));
          }
        },
        builder: (context, state) => RefreshIndicator(
          onRefresh: () => context.read<MenusCubit>().loadMine(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text(
                'Menus y QR',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Crea menus gastronomicos, platos y codigos QR.'),
              const SizedBox(height: 16),
              if (state.status == MenusStatus.loading)
                const Center(child: CircularProgressIndicator())
              else if (state.menus.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Aun no tienes menus creados.'),
                  ),
                )
              else
                ...state.menus.map(
                  (menu) => _MenuCard(
                    menu: menu,
                    items: state.itemsByMenu[menu.id] ?? const [],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.menu, required this.items});

  final MenuModel menu;
  final List<MenuItemModel> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.restaurant_menu_outlined),
        title: Text(menu.name, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(menu.description ?? '${items.length} items'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => BlocProvider.value(
                      value: context.read<MenusCubit>(),
                      child: _MenuItemFormSheet(menuId: menu.id),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Item'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => context.read<MenusCubit>().generateQr(menu.id),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('QR'),
                ),
              ),
            ],
          ),
          if (menu.qrCodeUrl != null && menu.qrCodeUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Image.network(menu.qrCodeUrl!, height: 120),
            if (menu.publicUrl != null)
              SelectableText(
                menu.publicUrl!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text('Este menu aun no tiene items.')
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                subtitle: Text(item.category ?? item.description ?? 'Sin categoria'),
                trailing: Text(
                  '${item.price.toStringAsFixed(0)} ${item.currency ?? 'CUP'}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuFormSheet extends StatefulWidget {
  const _MenuFormSheet();

  @override
  State<_MenuFormSheet> createState() => _MenuFormSheetState();
}

class _MenuFormSheetState extends State<_MenuFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre del menu'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Escribe nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripcion'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Crear menu'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<MenusCubit>().createMenu(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );
    Navigator.of(context).pop();
  }
}

class _MenuItemFormSheet extends StatefulWidget {
  const _MenuItemFormSheet({required this.menuId});

  final String menuId;

  @override
  State<_MenuItemFormSheet> createState() => _MenuItemFormSheetState();
}

class _MenuItemFormSheetState extends State<_MenuItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _currency = 'CUP';

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
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
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre del plato'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
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
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'MLC', child: Text('MLC')),
                        ],
                        onChanged: (value) =>
                            setState(() => _currency = value ?? 'CUP'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Agregar item'),
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
    context.read<MenusCubit>().createItem(
      menuId: widget.menuId,
      name: _nameController.text.trim(),
      price: double.parse(_priceController.text.trim()),
      category: _categoryController.text.trim().isEmpty
          ? null
          : _categoryController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      currency: _currency,
    );
    Navigator.of(context).pop();
  }
}
