import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../address/presentation/widgets/location_picker_sheet.dart';
import '../../../search/data/models/search_results_model.dart';
import '../../blocs/properties/properties_cubit.dart';
import '../../blocs/properties/properties_state.dart';

class PropertiesScreen extends StatelessWidget {
  const PropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PropertiesCubit>()..load(),
      child: const _PropertiesView(),
    );
  }
}

class BusinessPropertiesScreen extends StatelessWidget {
  const BusinessPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PropertiesCubit>()..loadMine(),
      child: const _BusinessPropertiesView(),
    );
  }
}

class _PropertiesView extends StatelessWidget {
  const _PropertiesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<PropertiesCubit, PropertiesState>(
        builder: (context, state) => RefreshIndicator(
          onRefresh: () => context.read<PropertiesCubit>().load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                'Propiedades y vehiculos',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Casas, apartamentos, autos, motos, terrenos y alquileres.'),
              const SizedBox(height: 14),
              _FilterChips(
                filters: const ['casa', 'apartamento', 'auto', 'moto', 'terreno'],
                onSelect: (type) => context.read<PropertiesCubit>().load(type: type),
              ),
              const SizedBox(height: 16),
              if (state.status == PropertiesStatus.loading)
                const Center(child: CircularProgressIndicator())
              else if (state.items.isEmpty)
                const _EmptyAsset(message: 'No hay propiedades publicadas.')
              else
                ...state.items.map(
                  (item) => _AssetCard(
                    item: item,
                    onTap: () => context.go(AppRoutes.property(item.id)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessPropertiesView extends StatelessWidget {
  const _BusinessPropertiesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => BlocProvider.value(
            value: context.read<PropertiesCubit>(),
            child: const _PropertyFormSheet(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Publicar'),
      ),
      body: BlocConsumer<PropertiesCubit, PropertiesState>(
        listener: (context, state) {
          if (state.message != null) {
            showSnackOrAuthDialog(context, state.message);
          }
        },
        builder: (context, state) => RefreshIndicator(
          onRefresh: () => context.read<PropertiesCubit>().loadMine(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text(
                'Mis propiedades',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Publica casas, autos, motos, terrenos o alquileres.'),
              const SizedBox(height: 16),
              if (state.status == PropertiesStatus.loading)
                const Center(child: CircularProgressIndicator())
              else if (state.items.isEmpty)
                const _EmptyAsset(message: 'Aun no tienes publicaciones.')
              else
                ...state.items.map((item) => _AssetCard(item: item)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyFormSheet extends StatefulWidget {
  const _PropertyFormSheet();

  @override
  State<_PropertyFormSheet> createState() => _PropertyFormSheetState();
}

class _PropertyFormSheetState extends State<_PropertyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _provinceController = TextEditingController();
  final _municipalityController = TextEditingController();
  String _type = 'casa';
  String _currency = 'USD';
  PickedLocation? _location;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _provinceController.dispose();
    _municipalityController.dispose();
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
                  'Nueva publicacion',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'casa', child: Text('Casa')),
                    DropdownMenuItem(value: 'apartamento', child: Text('Apartamento')),
                    DropdownMenuItem(value: 'auto', child: Text('Auto')),
                    DropdownMenuItem(value: 'moto', child: Text('Moto')),
                    DropdownMenuItem(value: 'terreno', child: Text('Terreno')),
                    DropdownMenuItem(value: 'local', child: Text('Local')),
                  ],
                  onChanged: (value) => setState(() => _type = value ?? 'casa'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Titulo'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Escribe titulo' : null,
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
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'CUP', child: Text('CUP')),
                          DropdownMenuItem(value: 'MLC', child: Text('MLC')),
                        ],
                        onChanged: (value) =>
                            setState(() => _currency = value ?? 'USD'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _provinceController,
                  decoration: const InputDecoration(labelText: 'Provincia'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _municipalityController,
                  decoration: const InputDecoration(labelText: 'Municipio'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(
                    _location == null
                        ? 'Seleccionar ubicacion en mapa'
                        : 'Ubicacion: ${_location!.latitude.toStringAsFixed(4)}, ${_location!.longitude.toStringAsFixed(4)}',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Publicar'),
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
    context.read<PropertiesCubit>().create(
      title: _titleController.text.trim(),
      type: _type,
      price: double.parse(_priceController.text.trim()),
      currency: _currency,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      province: _provinceController.text.trim().isEmpty
          ? null
          : _provinceController.text.trim(),
      municipality: _municipalityController.text.trim().isEmpty
          ? null
          : _municipalityController.text.trim(),
      latitude: _location?.latitude,
      longitude: _location?.longitude,
    );
    Navigator.of(context).pop();
  }

  Future<void> _pickLocation() async {
    final picked = await showModalBottomSheet<PickedLocation>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LocationPickerSheet(
        initialLatitude: _location?.latitude,
        initialLongitude: _location?.longitude,
        title: 'Ubicacion de la propiedad',
      ),
    );
    if (picked != null) {
      setState(() => _location = picked);
    }
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.filters, required this.onSelect});

  final List<String> filters;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(label: const Text('Todo'), onPressed: () => onSelect(null)),
        ...filters.map(
          (filter) => ActionChip(
            label: Text(filter),
            onPressed: () => onSelect(filter),
          ),
        ),
      ],
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.item, this.onTap});

  final SearchAssetModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Theme.of(context).colorScheme.onSecondary,
          child: Icon(_iconFor(item.type)),
        ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          [
            if (item.type != null) item.type,
            if (item.municipality != null) item.municipality,
            if (item.province != null) item.province,
          ].join(' · '),
        ),
        trailing: Text(
          item.price == null
              ? 'Consultar'
              : '${item.price!.toStringAsFixed(0)} ${item.currency ?? ''}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String? type) {
    return switch (type) {
      'auto' || 'moto' || 'camion' => Icons.directions_car_outlined,
      'terreno' || 'finca' => Icons.terrain_outlined,
      'local' => Icons.storefront_outlined,
      _ => Icons.home_work_outlined,
    };
  }
}

class _EmptyAsset extends StatelessWidget {
  const _EmptyAsset({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
