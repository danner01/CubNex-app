import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/theme/store_brand_theme.dart';
import '../../../home/data/models/business_model.dart';
import '../../blocs/settings/business_settings_cubit.dart';
import '../../blocs/settings/business_settings_state.dart';
import '../../data/models/store_customization_model.dart';
import '../widgets/business_switcher.dart';

class BusinessSettingsScreen extends StatelessWidget {
  const BusinessSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BusinessSettingsCubit>()
        ..load(
          selectedBusiness: context
              .read<ActiveBusinessCubit>()
              .state
              .activeBusiness,
        ),
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
                'Apariencia del negocio',
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
              const SizedBox(height: 10),
              BusinessSwitcher(
                onChanged: () => context.read<BusinessSettingsCubit>().load(
                  selectedBusiness: context
                      .read<ActiveBusinessCubit>()
                      .state
                      .activeBusiness,
                ),
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
                _OperationsSection(business: state.business, saving: saving),
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
                    business?.name ?? 'Vista previa del negocio',
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
                border: Border.all(
                  color: brand.primary.withValues(alpha: 0.45),
                ),
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

class _OperationsSection extends StatelessWidget {
  const _OperationsSection({required this.business, required this.saving});

  final BusinessModel? business;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final enabled = !saving && business != null;
    final item = business;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operacion y electricidad',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Actualiza disponibilidad, horario y estado electrico visible para clientes en tiempo real.',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item?.openingTime ?? '',
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Apertura',
                      hintText: '08:00',
                      prefixIcon: Icon(Icons.schedule_outlined),
                    ),
                    onChanged: (value) => context
                        .read<BusinessSettingsCubit>()
                        .updateBusinessOperations(openingTime: value.trim()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: item?.closingTime ?? '',
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Cierre',
                      hintText: '18:00',
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    onChanged: (value) => context
                        .read<BusinessSettingsCubit>()
                        .updateBusinessOperations(closingTime: value.trim()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: item?.availableNow ?? true,
              title: const Text('Disponible ahora'),
              subtitle: const Text('Aparece abierto o atendiendo en la app.'),
              onChanged: enabled
                  ? (value) => context
                        .read<BusinessSettingsCubit>()
                        .updateBusinessOperations(availableNow: value)
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: item?.acceptsTransfer ?? false,
              title: const Text('Acepta pagos por transferencia'),
              subtitle: const Text(
                'Se muestra en el negocio para que clientes sepan si pueden pagar por transferencia bancaria.',
              ),
              onChanged: enabled
                  ? (value) => context
                        .read<BusinessSettingsCubit>()
                        .updateBusinessOperations(acceptsTransfer: value)
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: item?.hasPhysicalLocation ?? true,
              title: const Text('Tiene local fisico'),
              subtitle: const Text(
                'Tiendas, salones, restaurantes y oficinas.',
              ),
              onChanged: enabled
                  ? (value) => context
                        .read<BusinessSettingsCubit>()
                        .updateBusinessOperations(hasPhysicalLocation: value)
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: item?.requiresElectricity ?? false,
              title: const Text('Requiere electricidad para operar'),
              subtitle: const Text(
                'Activa datos de circuito y estado electrico.',
              ),
              onChanged: enabled
                  ? (value) => context
                        .read<BusinessSettingsCubit>()
                        .updateBusinessOperations(requiresElectricity: value)
                  : null,
            ),
            if (item?.requiresElectricity ?? false) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: item?.hasElectricService ?? true,
                title: const Text('Tiene fluido electrico'),
                subtitle: const Text('Interruptor rapido para apagones.'),
                onChanged: enabled
                    ? (value) => context
                          .read<BusinessSettingsCubit>()
                          .updateBusinessOperations(hasElectricService: value)
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: item?.hasElectricBackup ?? false,
                title: const Text('Tiene respaldo electrico'),
                subtitle: const Text('Paneles, planta, baterias u otra via.'),
                onChanged: enabled
                    ? (value) => context
                          .read<BusinessSettingsCubit>()
                          .updateBusinessOperations(hasElectricBackup: value)
                    : null,
              ),
              if (item?.hasElectricBackup ?? false) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _validBackupType(item?.electricBackupType),
                  decoration: const InputDecoration(
                    labelText: 'Tipo de respaldo',
                    prefixIcon: Icon(Icons.bolt_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'paneles_solares',
                      child: Text('Paneles solares'),
                    ),
                    DropdownMenuItem(
                      value: 'planta_electrica',
                      child: Text('Planta electrica'),
                    ),
                    DropdownMenuItem(
                      value: 'baterias_inversor',
                      child: Text('Baterias / inversor'),
                    ),
                    DropdownMenuItem(
                      value: 'otra_via',
                      child: Text('Otra via'),
                    ),
                  ],
                  onChanged: enabled
                      ? (value) => context
                            .read<BusinessSettingsCubit>()
                            .updateBusinessOperations(electricBackupType: value)
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: item?.electricBlock ?? '',
                      enabled: enabled,
                      decoration: const InputDecoration(
                        labelText: 'Bloque electrico',
                      ),
                      onChanged: (value) => context
                          .read<BusinessSettingsCubit>()
                          .updateBusinessOperations(
                            electricBlock: value.trim(),
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: item?.electricCircuit ?? '',
                      enabled: enabled,
                      decoration: const InputDecoration(labelText: 'Circuito'),
                      onChanged: (value) => context
                          .read<BusinessSettingsCubit>()
                          .updateBusinessOperations(
                            electricCircuit: value.trim(),
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _validBackupType(String? value) {
    const valid = {
      'paneles_solares',
      'planta_electrica',
      'baterias_inversor',
      'otra_via',
    };
    return valid.contains(value) ? value : null;
  }
}

class _BrandAssetsSection extends StatefulWidget {
  const _BrandAssetsSection({required this.business, required this.saving});

  final BusinessModel? business;
  final bool saving;

  @override
  State<_BrandAssetsSection> createState() => _BrandAssetsSectionState();
}

class _BrandAssetsSectionState extends State<_BrandAssetsSection> {
  bool _uploadingLogo = false;
  bool _uploadingBanner = false;

  @override
  Widget build(BuildContext context) {
    final enabled =
        !widget.saving &&
        widget.business != null &&
        !_uploadingLogo &&
        !_uploadingBanner;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Identidad visual',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sube el logo y banner desde la camara o galeria. Se guardan en Supabase Storage y luego quedan visibles en tu tienda.',
            ),
            const SizedBox(height: 14),
            _ImagePickerTile(
              title: 'Logo del negocio',
              subtitle: 'Formato cuadrado recomendado',
              imageUrl: widget.business?.logoUrl,
              icon: Icons.storefront_outlined,
              busy: _uploadingLogo,
              enabled: enabled,
              height: 88,
              onTap: () => _pickAndUpload(kind: _BrandAssetKind.logo),
            ),
            const SizedBox(height: 12),
            _ImagePickerTile(
              title: 'Banner principal',
              subtitle: 'Imagen horizontal para portada',
              imageUrl: widget.business?.bannerUrl,
              icon: Icons.panorama_outlined,
              busy: _uploadingBanner,
              enabled: enabled,
              height: 120,
              wide: true,
              onTap: () => _pickAndUpload(kind: _BrandAssetKind.banner),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload({required _BrandAssetKind kind}) async {
    final source = await _chooseImageSource();
    if (source == null || !mounted) return;

    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: kind == _BrandAssetKind.banner ? 76 : 82,
      maxWidth: kind == _BrandAssetKind.banner ? 1600 : 900,
    );
    if (image == null || !mounted) return;

    setState(() {
      if (kind == _BrandAssetKind.logo) {
        _uploadingLogo = true;
      } else {
        _uploadingBanner = true;
      }
    });

    final url = await _uploadBrandAsset(image, kind);
    if (!mounted) return;

    setState(() {
      if (kind == _BrandAssetKind.logo) {
        _uploadingLogo = false;
      } else {
        _uploadingBanner = false;
      }
    });

    if (url == null) {
      showSnackOrAuthDialog(
        context,
        'No se pudo subir la imagen. Revisa conexion y permisos.',
      );
      return;
    }

    context.read<BusinessSettingsCubit>().updateBusinessBrand(
      logoUrl: kind == _BrandAssetKind.logo ? url : null,
      bannerUrl: kind == _BrandAssetKind.banner ? url : null,
    );
  }

  Future<String?> _uploadBrandAsset(XFile image, _BrandAssetKind kind) async {
    final business = widget.business;
    if (business == null) return null;

    try {
      final bytes = await image.readAsBytes();
      final result = await sl<ApiClient>().post<Map<String, dynamic>>(
        '/storage/subir',
        data: {
          'archivo_base64': base64Encode(bytes),
          'nombre_archivo':
              '${kind.name}-${business.id}-${DateTime.now().millisecondsSinceEpoch}.jpg',
          'content_type': 'image/jpeg',
          'bucket': 'negocios',
          'scope': 'identidad-visual',
          'negocio_id': business.id,
        },
        parser: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
      );
      final url = result.data?['public_url']?.toString();
      if (result.isSuccess && url != null && url.isNotEmpty) return url;
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Tomar foto'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Escoger desde galeria'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _BrandAssetKind { logo, banner }

class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.imageUrl,
    this.busy = false,
    this.enabled = true,
    this.height = 96,
    this.wide = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? imageUrl;
  final bool busy;
  final bool enabled;
  final double height;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (wide && hasImage)
              Positioned.fill(
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (wide && hasImage)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.58),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: wide ? 58 : 64,
                    height: wide ? 58 : 64,
                    decoration: BoxDecoration(
                      shape: wide ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: wide ? BorderRadius.circular(14) : null,
                      color: colorScheme.primaryContainer,
                      image: !wide && hasImage
                          ? DecorationImage(
                              image: NetworkImage(imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (!wide && hasImage)
                        ? null
                        : Icon(icon, color: colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: wide && hasImage ? Colors.white : null,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasImage
                              ? 'Imagen cargada. Toca para cambiarla.'
                              : subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: wide && hasImage
                                    ? Colors.white.withValues(alpha: 0.82)
                                    : null,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (busy)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      hasImage
                          ? Icons.edit_outlined
                          : Icons.add_photo_alternate_outlined,
                      color: wide && hasImage ? Colors.white : null,
                    ),
                ],
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
              'Paletas rapidas',
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toca una muestra para ajustar cada color. La app corrige el contraste para que textos y botones se lean bien.',
            ),
            const SizedBox(height: 14),
            _PaletteColorField(
              label: 'Principal',
              value: customization.primaryColor,
              enabled: !saving,
              onChanged: (value) =>
                  _update(context, customization.copyWith(primaryColor: value)),
            ),
            _PaletteColorField(
              label: 'Secundario',
              value: customization.secondaryColor,
              enabled: !saving,
              onChanged: (value) => _update(
                context,
                customization.copyWith(secondaryColor: value),
              ),
            ),
            _PaletteColorField(
              label: 'Acento',
              value: customization.accentColor,
              enabled: !saving,
              onChanged: (value) =>
                  _update(context, customization.copyWith(accentColor: value)),
            ),
            _PaletteColorField(
              label: 'Fondo',
              value: customization.backgroundColor,
              enabled: !saving,
              onChanged: (value) => _update(
                context,
                customization.copyWith(backgroundColor: value),
              ),
            ),
            _PaletteColorField(
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
              _PaletteColorField(
                label: 'Gradiente inicio',
                value: customization.gradientStart,
                enabled: !saving,
                onChanged: (value) => _update(
                  context,
                  customization.copyWith(gradientStart: value),
                ),
              ),
              _PaletteColorField(
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

class _PaletteColorField extends StatelessWidget {
  const _PaletteColorField({
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
    final normalized = normalizeHexColor(value, fallback: '#D4AF37');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Swatch(color: normalized),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _brandColorOptions.map((color) {
              final selected =
                  normalizeHexColor(color, fallback: color).toUpperCase() ==
                  normalized.toUpperCase();
              return Tooltip(
                message: color,
                child: InkWell(
                  onTap: enabled
                      ? () =>
                            onChanged(normalizeHexColor(color, fallback: color))
                      : null,
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: selected ? 38 : 34,
                    height: selected ? 38 : 34,
                    decoration: BoxDecoration(
                      color: parseStoreColor(color, fallback: Colors.black),
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: selected ? 3 : 1,
                        color: selected
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondary.withValues(alpha: 0.28),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: selected
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: _onSwatchColor(color),
                          )
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _onSwatchColor(String color) {
    final parsed = parseStoreColor(color, fallback: Colors.black);
    return parsed.computeLuminance() > 0.45 ? Colors.black : Colors.white;
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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

const _brandColorOptions = [
  '#D4AF37',
  '#F59E0B',
  '#F97316',
  '#EF4444',
  '#EC4899',
  '#8B5CF6',
  '#3B82F6',
  '#0EA5E9',
  '#14B8A6',
  '#22C55E',
  '#12806A',
  '#84CC16',
  '#F9FAFB',
  '#E5E7EB',
  '#9CA3AF',
  '#374151',
  '#111827',
  '#0D0D0D',
];
