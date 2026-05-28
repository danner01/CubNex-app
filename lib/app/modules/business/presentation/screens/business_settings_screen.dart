import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/injection/injection.dart';
import '../../blocs/settings/business_settings_cubit.dart';
import '../../blocs/settings/business_settings_state.dart';
import '../../data/models/store_customization_model.dart';

class BusinessSettingsScreen extends StatelessWidget {
  const BusinessSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BusinessSettingsCubit>()..load(),
      child: const _BusinessSettingsView(),
    );
  }
}

class _BusinessSettingsView extends StatelessWidget {
  const _BusinessSettingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<BusinessSettingsCubit, BusinessSettingsState>(
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message!)));
          }
        },
        builder: (context, state) {
          final customization = state.customization;
          final saving = state.status == BusinessSettingsStatus.saving;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text(
                'Apariencia de tienda',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.business == null
                    ? 'Carga tu negocio para personalizarlo.'
                    : 'Personalizando: ${state.business!.name}',
              ),
              const SizedBox(height: 18),
              if (state.status == BusinessSettingsStatus.loading)
                const Center(child: CircularProgressIndicator())
              else if (customization == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No encontramos configuracion editable.'),
                  ),
                )
              else ...[
                _StorePreview(customization: customization),
                const SizedBox(height: 12),
                _PaletteSection(customization: customization),
                const SizedBox(height: 12),
                _LayoutSection(customization: customization, saving: saving),
              ],
            ],
          );
        },
      ),
      floatingActionButton:
          BlocBuilder<BusinessSettingsCubit, BusinessSettingsState>(
            builder: (context, state) {
              final disabled =
                  state.customization == null ||
                  state.status == BusinessSettingsStatus.saving;
              return FloatingActionButton.extended(
                onPressed: disabled
                    ? null
                    : () => context.read<BusinessSettingsCubit>().save(),
                icon: disabled
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(disabled ? 'Guardando' : 'Guardar'),
              );
            },
          ),
    );
  }
}

class _StorePreview extends StatelessWidget {
  const _StorePreview({required this.customization});

  final StoreCustomizationModel customization;

  @override
  Widget build(BuildContext context) {
    final primary = _hex(customization.primaryColor);
    final background = _hex(customization.backgroundColor);
    final text = _hex(customization.textColor);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primary,
                  foregroundColor: Colors.black,
                  child: const Icon(Icons.storefront_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vista previa de tienda',
                    style: TextStyle(
                      color: text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 94,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(
                  customization.cardRadius.toDouble(),
                ),
                border: Border.all(color: primary.withValues(alpha: 0.45)),
              ),
              child: Center(
                child: Text(
                  'Producto destacado · ${customization.cardStyle}',
                  style: TextStyle(color: text, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteSection extends StatelessWidget {
  const _PaletteSection({required this.customization});

  final StoreCustomizationModel customization;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paleta de colores',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _palettes.map((palette) {
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    context.read<BusinessSettingsCubit>().update(
                      customization.copyWith(
                        primaryColor: palette.primary,
                        secondaryColor: palette.secondary,
                        accentColor: palette.accent,
                        backgroundColor: palette.background,
                        textColor: palette.text,
                      ),
                    );
                  },
                  child: Container(
                    width: 92,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Swatch(color: palette.primary),
                            _Swatch(color: palette.secondary),
                            _Swatch(color: palette.accent),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          palette.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayoutSection extends StatelessWidget {
  const _LayoutSection({required this.customization, required this.saving});

  final StoreCustomizationModel customization;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: customization.cardStyle,
              decoration: const InputDecoration(labelText: 'Estilo de tarjeta'),
              items: const [
                DropdownMenuItem(value: 'grande', child: Text('Grande')),
                DropdownMenuItem(value: 'compacta', child: Text('Compacta')),
                DropdownMenuItem(value: 'lista', child: Text('Lista')),
              ],
              onChanged: saving
                  ? null
                  : (value) => context.read<BusinessSettingsCubit>().update(
                      customization.copyWith(cardStyle: value ?? 'grande'),
                    ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: customization.gridColumns,
              decoration: const InputDecoration(labelText: 'Columnas del grid'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 columna')),
                DropdownMenuItem(value: 2, child: Text('2 columnas')),
                DropdownMenuItem(value: 3, child: Text('3 columnas')),
              ],
              onChanged: saving
                  ? null
                  : (value) => context.read<BusinessSettingsCubit>().update(
                      customization.copyWith(gridColumns: value ?? 2),
                    ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: customization.showDiscount,
              title: const Text('Mostrar descuentos'),
              onChanged: saving
                  ? null
                  : (value) => context.read<BusinessSettingsCubit>().update(
                      customization.copyWith(showDiscount: value),
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: customization.showRating,
              title: const Text('Mostrar calificacion'),
              onChanged: saving
                  ? null
                  : (value) => context.read<BusinessSettingsCubit>().update(
                      customization.copyWith(showRating: value),
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: customization.showStock,
              title: const Text('Mostrar stock'),
              onChanged: saving
                  ? null
                  : (value) => context.read<BusinessSettingsCubit>().update(
                      customization.copyWith(showStock: value),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final String color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: _hex(color),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white),
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.text,
  });

  final String name;
  final String primary;
  final String secondary;
  final String accent;
  final String background;
  final String text;
}

const _palettes = [
  _Palette(
    name: 'Dorado',
    primary: '#D4AF37',
    secondary: '#111512',
    accent: '#3B82F6',
    background: '#0D0D0D',
    text: '#FFFFFF',
  ),
  _Palette(
    name: 'Tropical',
    primary: '#12806A',
    secondary: '#F7C948',
    accent: '#2563EB',
    background: '#F8FAF7',
    text: '#111827',
  ),
  _Palette(
    name: 'Urbano',
    primary: '#111827',
    secondary: '#F9FAFB',
    accent: '#EF4444',
    background: '#FFFFFF',
    text: '#111827',
  ),
  _Palette(
    name: 'Mar',
    primary: '#0EA5E9',
    secondary: '#0F172A',
    accent: '#22C55E',
    background: '#F8FAFC',
    text: '#0F172A',
  ),
];

Color _hex(String value) {
  final normalized = value.replaceAll('#', '');
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  return Color(int.tryParse(hex, radix: 16) ?? 0xFF111512);
}
