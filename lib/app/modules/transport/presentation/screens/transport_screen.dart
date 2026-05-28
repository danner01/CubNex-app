import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../address/presentation/widgets/location_picker_sheet.dart';
import '../../../search/data/models/search_results_model.dart';
import '../../blocs/transport/transport_cubit.dart';
import '../../blocs/transport/transport_state.dart';

class TransportScreen extends StatelessWidget {
  const TransportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TransportCubit>()..load(),
      child: const _TransportView(),
    );
  }
}

class BusinessTransportScreen extends StatelessWidget {
  const BusinessTransportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TransportCubit>()..loadMine(),
      child: const _BusinessTransportView(),
    );
  }
}

class _TransportView extends StatelessWidget {
  const _TransportView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<TransportCubit, TransportState>(
        builder: (context, state) => RefreshIndicator(
          onRefresh: () => context.read<TransportCubit>().load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                'Transporte',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Carga, pasajeros, delivery, taxi, mudanzas y renta.'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Todo'),
                    onPressed: () => context.read<TransportCubit>().load(),
                  ),
                  ...['carga', 'pasajeros', 'delivery', 'mudanza', 'taxi'].map(
                    (type) => ActionChip(
                      label: Text(type),
                      onPressed: () =>
                          context.read<TransportCubit>().load(type: type),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (state.status == TransportStatus.loading)
                const Center(child: CircularProgressIndicator())
              else if (state.items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No hay servicios de transporte publicados.'),
                  ),
                )
              else
                ...state.items.map(
                  (item) => _TransportCard(
                    item: item,
                    onTap: () => context.go(AppRoutes.transportService(item.id)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessTransportView extends StatelessWidget {
  const _BusinessTransportView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => BlocProvider.value(
            value: context.read<TransportCubit>(),
            child: const _TransportFormSheet(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Servicio'),
      ),
      body: BlocConsumer<TransportCubit, TransportState>(
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message!)));
          }
        },
        builder: (context, state) => RefreshIndicator(
          onRefresh: () => context.read<TransportCubit>().loadMine(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text(
                'Mis transportes',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Publica carga, pasajeros, delivery, taxi o mudanza.'),
              const SizedBox(height: 16),
              if (state.status == TransportStatus.loading)
                const Center(child: CircularProgressIndicator())
              else if (state.items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Aun no tienes servicios publicados.'),
                  ),
                )
              else
                ...state.items.map((item) => _TransportCard(item: item)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransportFormSheet extends StatefulWidget {
  const _TransportFormSheet();

  @override
  State<_TransportFormSheet> createState() => _TransportFormSheetState();
}

class _TransportFormSheetState extends State<_TransportFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _kmPriceController = TextEditingController();
  String _type = 'carga';
  String _currency = 'CUP';
  PickedLocation? _location;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _vehicleController.dispose();
    _basePriceController.dispose();
    _kmPriceController.dispose();
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
                  'Nuevo servicio',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'carga', child: Text('Carga')),
                    DropdownMenuItem(value: 'pasajeros', child: Text('Pasajeros')),
                    DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
                    DropdownMenuItem(value: 'mudanza', child: Text('Mudanza')),
                    DropdownMenuItem(value: 'taxi', child: Text('Taxi')),
                    DropdownMenuItem(value: 'renta', child: Text('Renta')),
                  ],
                  onChanged: (value) => setState(() => _type = value ?? 'carga'),
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
                TextFormField(
                  controller: _vehicleController,
                  decoration: const InputDecoration(labelText: 'Tipo de vehiculo'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _basePriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Precio base'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _kmPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Precio/km'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(labelText: 'Moneda'),
                  items: const [
                    DropdownMenuItem(value: 'CUP', child: Text('CUP')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'MLC', child: Text('MLC')),
                  ],
                  onChanged: (value) => setState(() => _currency = value ?? 'CUP'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(
                    _location == null
                        ? 'Seleccionar punto base en mapa'
                        : 'Punto base: ${_location!.latitude.toStringAsFixed(4)}, ${_location!.longitude.toStringAsFixed(4)}',
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
    context.read<TransportCubit>().create(
      title: _titleController.text.trim(),
      type: _type,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      vehicleType: _vehicleController.text.trim().isEmpty
          ? null
          : _vehicleController.text.trim(),
      basePrice: double.tryParse(_basePriceController.text.trim()),
      pricePerKm: double.tryParse(_kmPriceController.text.trim()),
      currency: _currency,
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
        title: 'Punto base del transporte',
      ),
    );
    if (picked != null) {
      setState(() => _location = picked);
    }
  }
}

class _TransportCard extends StatelessWidget {
  const _TransportCard({required this.item, this.onTap});

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
            if (item.description != null) item.description,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
      'delivery' => Icons.delivery_dining_outlined,
      'pasajeros' || 'taxi' => Icons.local_taxi_outlined,
      'mudanza' => Icons.inventory_2_outlined,
      _ => Icons.local_shipping_outlined,
    };
  }
}
