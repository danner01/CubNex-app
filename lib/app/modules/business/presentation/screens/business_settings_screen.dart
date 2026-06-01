import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/theme/store_brand_theme.dart';
import '../../../home/data/models/business_model.dart';
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
            showSnackOrAuthDialog(context, state.message);
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
                _StorePreview(
                  customization: customization,
                  business: state.business,
                ),
                const SizedBox(height: 12),
                _BrandAssetsSection(business: state.business, saving: saving),
                const SizedBox(height: 12),
                _PaletteSection(customization: customization),
                const SizedBox(height: 12),
                _ColorFineTuneSection(
                  customization: customization,
                  saving: saving,
                ),
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
  const _StorePreview({required this.customization, this.business});

  final StoreCustomizationModel customization;
  final BusinessModel? business;

  @override
  Widget build(BuildContext context) {
    final brand = StoreBrandTheme.fromCustomization(
      customization,
      Theme.of(context).brightness,
    );

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: brand.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: brand.primary,
                  foregroundColor: brand.onPrimary,
                  backgroundImage: business?.logoUrl?.isNotEmpty == true
                      ? NetworkImage(business!.logoUrl!)
                      : null,
                  child: business?.logoUrl?.isNotEmpty == true
                      ? null
                      : const Icon(Icons.storefront_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    business?.name ?? 'Vista previa de tienda',
                    style: TextStyle(
                      color: brand.onBackground,
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
                color: brand.surface,
                borderRadius: BorderRadius.circular(
                  customization.cardRadius.toDouble(),
                ),
                border: Border.all(color: brand.primary.withValues(alpha: 0.45)),
              ),
              child: Center(
                child: Text(
                  'Producto destacado - ${customization.cardStyle}',
                  style: TextStyle(
                    color: brand.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandAssetsSection extends StatelessWidget {
  const _BrandAssetsSection({required this.business, required this.saving});

  final BusinessModel? business;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Identidad visual',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Usa enlaces de Supabase Storage para logo y banner. Luego podemos conectar selector de galeria y camara.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: business?.logoUrl ?? '',
              enabled: !saving && business != null,
              decoration: const InputDecoration(
                labelText: 'Logo de la tienda',
                prefixIcon: Icon(Icons.image_outlined),
                hintText: 'https://.../logo.png',
              ),
              onChanged: (value) => context
                  .read<BusinessSettingsCubit>()
                  .updateBusinessBrand(logoUrl: value.trim()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: business?.bannerUrl ?? '',
              enabled: !saving && business != null,
              decoration: const InputDecoration(
                labelText: 'Banner principal',
                prefixIcon: Icon(Icons.panorama_outlined),
                hintText: 'https://.../banner.png',
              ),
              onChanged: (value) => context
                  .read<BusinessSettingsCubit>()
                  .updateBusinessBrand(bannerUrl: value.trim()),
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
              'Paletas rapidas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
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
                        gradientStart: palette.primary,
                        gradientEnd: palette.accent,
                      ),
                    );
                  },
                  child: Container(
                    width: 96,
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

class _ColorFineTuneSection extends StatelessWidget {
  const _ColorFineTuneSection({
    required this.customization,
    required this.saving,
  });

  final StoreCustomizationModel customization;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Colores editables',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Puedes ajustar cada color en formato HEX. La app corrige el contraste para que textos y botones se lean bien.',
            ),
            const SizedBox(height: 14),
            _HexColorField(
              label: 'Principal',
              value: customization.primaryColor,
              enabled: !saving,
              onChanged: (value) => _update(
                context,
                customization.copyWith(primaryColor: value),
              ),
            ),
            _HexColorField(
              label: 'Secundario',
              value: customization.secondaryColor,
              enabled: !saving,
              onChanged: (value) => _update(
                context,
                customization.copyWith(secondaryColor: value),
              ),
            ),
            _HexColorField(
              label: 'Acento',
              value: customization.accentColor,
              enabled: !saving,
              onChanged: (value) => _update(
                context,
                customization.copyWith(accentColor: value),
              ),
            ),
            _HexColorField(
              label: 'Fondo',
              value: customization.backgroundColor,
              enabled: !saving,
              onChanged: (value) => _update(
                context,
                customization.copyWith(backgroundColor: value),
              ),
            ),
            _HexColorField(
              label: 'Texto sugerido',
              value: customization.textColor,
              enabled: !saving,
              onChanged: (value) =>
                  _update(context, customization.copyWith(textColor: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: customization.gradientEnabled,
              title: const Text('Usar gradiente en banner'),
              onChanged: saving
                  ? null
                  : (value) => _update(
                      context,
                      customization.copyWith(gradientEnabled: value),
                    ),
            ),
            if (customization.gradientEnabled) ...[
              _HexColorField(
                label: 'Gradiente inicio',
                value: customization.gradientStart,
                enabled: !saving,
                onChanged: (value) => _update(
                  context,
                  customization.copyWith(gradientStart: value),
                ),
              ),
              _HexColorField(
                label: 'Gradiente fin',
                value: customization.gradientEnd,
                enabled: !saving,
                onChanged: (value) => _update(
                  context,
                  customization.copyWith(gradientEnd: value),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: customization.gradientDirection,
                decoration: const InputDecoration(
                  labelText: 'Direccion del gradiente',
                ),
                items: const [
                  DropdownMenuItem(value: 'vertical', child: Text('Vertical')),
                  DropdownMenuItem(
                    value: 'horizontal',
                    child: Text('Horizontal'),
                  ),
                  DropdownMenuItem(value: 'diagonal', child: Text('Diagonal')),
                ],
                onChanged: saving
                    ? null
                    : (value) => _update(
                        context,
                        customization.copyWith(
                          gradientDirection: value ?? 'vertical',
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _update(BuildContext context, StoreCustomizationModel value) {
    context.read<BusinessSettingsCubit>().update(value);
  }
}

class _HexColorField extends StatelessWidget {
  const _HexColorField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeHexColor(value, fallback: value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: normalized,
        enabled: enabled,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: _Swatch(color: normalized),
          ),
          hintText: '#D4AF37',
        ),
        onChanged: (text) {
          final fallback = normalized.startsWith('#') ? normalized : '#D4AF37';
          onChanged(normalizeHexColor(text, fallback: fallback));
        },
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tarjetas y layout',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
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
        color: parseStoreColor(color, fallback: Colors.black),
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
  _Palette(
    name: 'Neon',
    primary: '#8B5CF6',
    secondary: '#111827',
    accent: '#22D3EE',
    background: '#09090B',
    text: '#FFFFFF',
  ),
];
