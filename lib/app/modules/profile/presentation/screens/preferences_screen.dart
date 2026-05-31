import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../blocs/preferences/preferences_cubit.dart';
import '../../blocs/preferences/preferences_state.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PreferencesCubit>()..load(),
      child: const _PreferencesView(),
    );
  }
}

class _PreferencesView extends StatelessWidget {
  const _PreferencesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<PreferencesCubit, PreferencesState>(
        listener: (context, state) {
          if (state.message != null) {
            showSnackOrAuthDialog(context, state.message);
          }
        },
        builder: (context, state) {
          final loading = state.status == PreferencesStatus.loading;
          final saving = state.status == PreferencesStatus.saving;
          final grouped = <String, List<dynamic>>{};
          for (final type in state.types) {
            grouped.putIfAbsent(type.parentCategory ?? 'otros', () => []).add(type);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text(
                'Preferencias',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecciona los tipos de negocios y servicios que quieres ver primero en recomendaciones.',
              ),
              const SizedBox(height: 18),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else
                ...grouped.entries.map(
                  (entry) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _categoryLabel(entry.key),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: entry.value.map((type) {
                              final selected = state.selectedTypeIds.contains(
                                type.id,
                              );
                              return FilterChip(
                                selected: selected,
                                label: Text(type.name),
                                avatar: Icon(_iconFor(type.icon), size: 18),
                                onSelected: saving
                                    ? null
                                    : (_) => context
                                          .read<PreferencesCubit>()
                                          .toggleType(type.id),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: BlocBuilder<PreferencesCubit, PreferencesState>(
        builder: (context, state) {
          final saving = state.status == PreferencesStatus.saving;
          return FloatingActionButton.extended(
            onPressed: saving ? null : () => context.read<PreferencesCubit>().save(),
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Guardando' : 'Guardar'),
          );
        },
      ),
    );
  }

  String _categoryLabel(String value) {
    return switch (value) {
      'tienda' => 'Tiendas',
      'servicio' => 'Servicios',
      'transporte' => 'Transporte',
      'inmobiliaria' => 'Propiedades y vehiculos',
      'gastronomia' => 'Gastronomia',
      _ => 'Otros',
    };
  }

  IconData _iconFor(String? icon) {
    return switch (icon) {
      'truck' => Icons.local_shipping_outlined,
      'car' || 'car-front' => Icons.directions_car_outlined,
      'home' || 'building' => Icons.home_work_outlined,
      'utensils' || 'coffee' => Icons.restaurant_outlined,
      'scissors' => Icons.content_cut,
      'wrench' => Icons.handyman_outlined,
      'shirt' => Icons.checkroom_outlined,
      'smartphone' || 'monitor' => Icons.devices_outlined,
      _ => Icons.storefront_outlined,
    };
  }
}
