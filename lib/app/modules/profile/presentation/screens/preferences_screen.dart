import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../common/blocs/app_theme/app_theme_cubit.dart';
import '../../../../common/blocs/role_mode/role_mode_cubit.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../wizard/data/models/business_type_model.dart';
import '../../blocs/preferences/preferences_cubit.dart';
import '../../blocs/preferences/preferences_state.dart';

enum _PreferencePanel { theme, categories, privacy }

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

class _PreferencesView extends StatefulWidget {
  const _PreferencesView();

  @override
  State<_PreferencesView> createState() => _PreferencesViewState();
}

class _PreferencesViewState extends State<_PreferencesView> {
  _PreferencePanel _panel = _PreferencePanel.theme;

  @override
  Widget build(BuildContext context) {
    final roleMode = context.watch<RoleModeCubit>().state.activeMode;
    return Scaffold(
      body: BlocConsumer<PreferencesCubit, PreferencesState>(
        listener: (context, state) {
          if (state.message != null) {
            showSnackOrAuthDialog(context, state.message);
          }
        },
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _HeaderCard(panel: _panel, roleMode: roleMode),
              const SizedBox(height: 12),
              _PanelSelector(
                selected: _panel,
                onSelected: (panel) => setState(() => _panel = panel),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: switch (_panel) {
                  _PreferencePanel.theme => const _ThemeModeSection(
                    key: ValueKey('theme'),
                  ),
                  _PreferencePanel.categories => _CategoriesSection(
                    key: const ValueKey('categories'),
                    state: state,
                    roleMode: roleMode,
                  ),
                  _PreferencePanel.privacy => const _PrivacySection(
                    key: ValueKey('privacy'),
                  ),
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: _panel == _PreferencePanel.categories
          ? BlocBuilder<PreferencesCubit, PreferencesState>(
              builder: (context, state) {
                final saving = state.status == PreferencesStatus.saving;
                return FloatingActionButton.extended(
                  onPressed: saving
                      ? null
                      : () => context.read<PreferencesCubit>().save(),
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Guardando' : 'Guardar categorias'),
                );
              },
            )
          : null,
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.panel, required this.roleMode});

  final _PreferencePanel panel;
  final RoleMode roleMode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final roleLabel = switch (roleMode) {
      RoleMode.client => 'cliente',
      RoleMode.business => 'negocio',
      RoleMode.delivery => 'delivery',
    };
    final title = switch (panel) {
      _PreferencePanel.theme => 'Preferencias de $roleLabel',
      _PreferencePanel.categories => 'Categorias de $roleLabel',
      _PreferencePanel.privacy => 'Privacidad de $roleLabel',
    };
    final subtitle = switch (panel) {
      _PreferencePanel.theme =>
        'Controla el modo claro, oscuro o automatico de ConKkao.',
      _PreferencePanel.categories => switch (roleMode) {
        RoleMode.client => 'Elige que negocios y servicios quieres ver primero.',
        RoleMode.business => 'Prioriza aliados, proveedores y servicios utiles para tus negocios.',
        RoleMode.delivery => 'Configura los tipos de negocios y entregas que quieres recibir primero.',
      },
      _PreferencePanel.privacy =>
        'Decide como se usa tu actividad dentro de la app.',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                switch (panel) {
                  _PreferencePanel.theme => Icons.palette_outlined,
                  _PreferencePanel.categories => Icons.tune_outlined,
                  _PreferencePanel.privacy => Icons.lock_outline_rounded,
                },
                color: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelSelector extends StatelessWidget {
  const _PanelSelector({required this.selected, required this.onSelected});

  final _PreferencePanel selected;
  final ValueChanged<_PreferencePanel> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PanelChip(
          selected: selected == _PreferencePanel.theme,
          icon: Icons.palette_outlined,
          label: 'Tema',
          onTap: () => onSelected(_PreferencePanel.theme),
        ),
        _PanelChip(
          selected: selected == _PreferencePanel.categories,
          icon: Icons.category_outlined,
          label: 'Categorias',
          onTap: () => onSelected(_PreferencePanel.categories),
        ),
        _PanelChip(
          selected: selected == _PreferencePanel.privacy,
          icon: Icons.privacy_tip_outlined,
          label: 'Privacidad',
          onTap: () => onSelected(_PreferencePanel.privacy),
        ),
      ],
    );
  }
}

class _PanelChip extends StatelessWidget {
  const _PanelChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) => onTap(),
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({required this.state, required this.roleMode, super.key});

  final PreferencesState state;
  final RoleMode roleMode;

  @override
  Widget build(BuildContext context) {
    final loading = state.status == PreferencesStatus.loading;
    final saving = state.status == PreferencesStatus.saving;
    final grouped = <String, List<BusinessTypeModel>>{};
    for (final type in _typesForMode(state.types)) {
      grouped.putIfAbsent(type.parentCategory ?? 'otros', () => []).add(type);
    }

    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (state.status == PreferencesStatus.failure) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            state.message ?? 'No se pudieron cargar las categorias.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (grouped.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'No hay categorias disponibles todavia.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('categories-content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          switch (roleMode) {
            RoleMode.client => 'Recomendaciones',
            RoleMode.business => 'Preferencias comerciales',
            RoleMode.delivery => 'Preferencias de entregas',
          },
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          switch (roleMode) {
            RoleMode.client =>
              'Marca los tipos de negocios que quieres priorizar en el home, promociones y busqueda.',
            RoleMode.business =>
              'Selecciona categorias de proveedores, aliados y clientes potenciales para recomendaciones B2B.',
            RoleMode.delivery =>
              'Selecciona negocios y servicios que generan entregas para ordenar tus solicitudes.',
          },
        ),
        const SizedBox(height: 12),
        ...grouped.entries.map(
          (entry) => _CategoryGroupCard(
            title: _categoryLabel(entry.key),
            types: entry.value,
            selectedTypeIds: state.selectedTypeIds,
            saving: saving,
          ),
        ),
      ],
    );
  }

  List<BusinessTypeModel> _typesForMode(List<BusinessTypeModel> types) {
    if (roleMode == RoleMode.client || roleMode == RoleMode.business) {
      return types;
    }

    const deliveryParents = {'transporte', 'gastronomia', 'tienda', 'servicio'};
    return types
        .where((type) => deliveryParents.contains(type.parentCategory))
        .toList();
  }

  static String _categoryLabel(String value) {
    return switch (value) {
      'tienda' => 'Tiendas',
      'servicio' => 'Servicios',
      'transporte' => 'Transporte',
      'inmobiliaria' => 'Propiedades y vehiculos',
      'gastronomia' => 'Gastronomia',
      _ => 'Otros',
    };
  }
}

class _CategoryGroupCard extends StatelessWidget {
  const _CategoryGroupCard({
    required this.title,
    required this.types,
    required this.selectedTypeIds,
    required this.saving,
  });

  final String title;
  final List<BusinessTypeModel> types;
  final Set<String> selectedTypeIds;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: types.map((type) {
                  final selected = selectedTypeIds.contains(type.id);
                  return FilterChip(
                    selected: selected,
                    label: Text(type.name),
                    avatar: Icon(_iconFor(type.icon), size: 18),
                    onSelected: saving
                        ? null
                        : (_) =>
                              context.read<PreferencesCubit>().toggleType(type.id),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
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

class _PrivacySection extends StatefulWidget {
  const _PrivacySection({super.key});

  @override
  State<_PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends State<_PrivacySection> {
  static const _personalizedRecommendationsKey =
      'privacy.personalized_recommendations';
  static const _publicReviewActivityKey = 'privacy.public_review_activity';
  static const _marketingNotificationsKey = 'privacy.marketing_notifications';

  late final SharedPreferences _preferences;
  late bool _recommendations;
  late bool _publicReviews;
  late bool _marketing;

  @override
  void initState() {
    super.initState();
    _preferences = sl<SharedPreferences>();
    _recommendations =
        _preferences.getBool(_personalizedRecommendationsKey) ?? true;
    _publicReviews = _preferences.getBool(_publicReviewActivityKey) ?? true;
    _marketing = _preferences.getBool(_marketingNotificationsKey) ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('privacy-content'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacidad y permisos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Activa o desactiva como se usan tus datos dentro de la app. Estos ajustes se guardan en este dispositivo.',
            ),
            const SizedBox(height: 12),
            _PrivacyToggleTile(
              value: _recommendations,
              title: const Text('Recomendaciones personalizadas'),
              subtitle: const Text('Usar favoritos, escaneos y categorias.'),
              onChanged: (value) => _save(
                key: _personalizedRecommendationsKey,
                value: value,
                update: () => _recommendations = value,
              ),
            ),
            _PrivacyToggleTile(
              value: _publicReviews,
              title: const Text('Actividad de resenas visible'),
              subtitle: const Text('Permite mostrar tus opiniones publicas.'),
              onChanged: (value) => _save(
                key: _publicReviewActivityKey,
                value: value,
                update: () => _publicReviews = value,
              ),
            ),
            _PrivacyToggleTile(
              value: _marketing,
              title: const Text('Notificaciones comerciales'),
              subtitle: const Text('Promociones, sorteos y anuncios.'),
              onChanged: (value) => _save(
                key: _marketingNotificationsKey,
                value: value,
                update: () => _marketing = value,
              ),
            ),
            const SizedBox(height: 12),
            _PermissionsInfoCard(
              items: const [
                _PermissionInfo(
                  icon: Icons.camera_alt_outlined,
                  title: 'Camara',
                  description: 'Se solicita al escanear QR, codigos o etiquetas.',
                ),
                _PermissionInfo(
                  icon: Icons.photo_library_outlined,
                  title: 'Galeria',
                  description: 'Se solicita al subir logos, banners o productos.',
                ),
                _PermissionInfo(
                  icon: Icons.location_on_outlined,
                  title: 'Ubicacion',
                  description: 'Se solicita al buscar negocios cercanos o usar mapa.',
                ),
                _PermissionInfo(
                  icon: Icons.notifications_outlined,
                  title: 'Notificaciones',
                  description: 'Se solicita para avisos, promociones y pedidos.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save({
    required String key,
    required bool value,
    required VoidCallback update,
  }) async {
    await _preferences.setBool(key, value);
    if (!mounted) return;
    setState(update);
  }
}

class _PrivacyToggleTile extends StatelessWidget {
  const _PrivacyToggleTile({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final Widget title;
  final Widget subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
          value: value,
          title: Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 8),
              _StatusPill(active: value),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: subtitle,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? colorScheme.primary.withValues(alpha: 0.16)
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          active ? 'Activado' : 'Desactivado',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: active ? colorScheme.primary : colorScheme.onErrorContainer,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PermissionsInfoCard extends StatelessWidget {
  const _PermissionsInfoCard({required this.items});

  final List<_PermissionInfo> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permisos del dispositivo',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'La app pedira cada permiso solo cuando uses una funcion que lo necesite.',
            ),
            const SizedBox(height: 10),
            ...items.map((item) => _PermissionInfoRow(item: item)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: openAppSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Abrir ajustes de permisos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionInfoRow extends StatelessWidget {
  const _PermissionInfoRow({required this.item});

  final _PermissionInfo item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(item.description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionInfo {
  const _PermissionInfo({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _ThemeModeSection extends StatelessWidget {
  const _ThemeModeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('theme-content'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modo claro y oscuro',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Este tema se aplica a la app. Cada tienda conserva sus colores cuando entras a su perfil.',
            ),
            const SizedBox(height: 14),
            BlocBuilder<AppThemeCubit, ThemeMode>(
              builder: (context, mode) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ThemeChoice(
                      selected: mode == ThemeMode.system,
                      icon: Icons.brightness_auto_outlined,
                      title: 'Sistema',
                      onTap: () => context
                          .read<AppThemeCubit>()
                          .setThemeMode(ThemeMode.system),
                    ),
                    _ThemeChoice(
                      selected: mode == ThemeMode.light,
                      icon: Icons.light_mode_outlined,
                      title: 'Claro',
                      onTap: () => context
                          .read<AppThemeCubit>()
                          .setThemeMode(ThemeMode.light),
                    ),
                    _ThemeChoice(
                      selected: mode == ThemeMode.dark,
                      icon: Icons.dark_mode_outlined,
                      title: 'Oscuro',
                      onTap: () => context
                          .read<AppThemeCubit>()
                          .setThemeMode(ThemeMode.dark),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 108,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
