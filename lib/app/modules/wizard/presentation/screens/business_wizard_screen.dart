import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/environment/app_environment.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../blocs/business_wizard/business_wizard_cubit.dart';
import '../../blocs/business_wizard/business_wizard_state.dart';

class BusinessWizardScreen extends StatelessWidget {
  const BusinessWizardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BusinessWizardCubit>()..loadCatalog(),
      child: const _BusinessWizardView(),
    );
  }
}

class _BusinessWizardView extends StatefulWidget {
  const _BusinessWizardView();

  @override
  State<_BusinessWizardView> createState() => _BusinessWizardViewState();
}

class _BusinessWizardViewState extends State<_BusinessWizardView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _provinceController = TextEditingController();
  final _municipalityController = TextEditingController();
  final _addressController = TextEditingController();
  final _openingTimeController = TextEditingController(text: '08:00');
  final _closingTimeController = TextEditingController(text: '18:00');
  final _electricBlockController = TextEditingController();
  final _electricCircuitController = TextEditingController();
  int _step = 0;
  String? _selectedTypeId;
  String? _electricBackupType;
  double? _latitude;
  double? _longitude;
  bool _resolvingAddress = false;
  bool _availableNow = true;
  bool _hasPhysicalLocation = true;
  bool _requiresElectricity = false;
  bool _hasElectricService = true;
  bool _hasElectricBackup = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _provinceController.dispose();
    _municipalityController.dispose();
    _addressController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    _electricBlockController.dispose();
    _electricCircuitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BusinessWizardCubit, BusinessWizardState>(
      listener: (context, state) {
        if (state.message != null) {
          showSnackOrAuthDialog(context, state.message);
        }
        if (state.status == BusinessWizardStatus.success) {
          context.go(AppRoutes.businessInventory);
        }
      },
      builder: (context, state) {
        final loading =
            state.status == BusinessWizardStatus.loading ||
            state.status == BusinessWizardStatus.saving;

        return Scaffold(
          body: Form(
            key: _formKey,
            child: Stepper(
              currentStep: _step,
              type: StepperType.vertical,
              onStepTapped: (step) => setState(() => _step = step),
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      if (_step > 0)
                        OutlinedButton(
                          onPressed: loading
                              ? null
                              : () => setState(() => _step -= 1),
                          child: const Text('Atras'),
                        ),
                      if (_step > 0) const SizedBox(width: 10),
                      FilledButton(
                        onPressed: loading ? null : () => _continue(context),
                        child: Text(_step == 2 ? 'Crear negocio' : 'Continuar'),
                      ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Tipo de negocio'),
                  isActive: _step >= 0,
                  content: state.status == BusinessWizardStatus.loading
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          initialValue: _selectedTypeId,
                          decoration: const InputDecoration(
                            labelText: 'Selecciona un tipo',
                          ),
                          items: state.types
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type.id,
                                  child: Text(
                                    [
                                      type.name,
                                      if (type.parentCategory != null)
                                        '(${type.parentCategory})',
                                    ].join(' '),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedTypeId = value),
                        ),
                ),
                Step(
                  title: const Text('Informacion basica'),
                  isActive: _step >= 1,
                  content: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del negocio',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Escribe el nombre'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descripcion',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefono',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _whatsappController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Ubicacion'),
                  isActive: _step >= 2,
                  content: Column(
                    children: [
                      TextFormField(
                        controller: _provinceController,
                        decoration: const InputDecoration(
                          labelText: 'Provincia',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _municipalityController,
                        decoration: const InputDecoration(
                          labelText: 'Municipio',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Direccion',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _latitude == null
                                          ? 'Escoge la ubicacion en el mapa'
                                          : 'Ubicacion seleccionada',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _latitude == null
                                    ? 'Toca el mapa o usa la ubicacion actual para guardar coordenadas reales del negocio.'
                                    : '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _resolvingAddress
                                      ? null
                                      : () => _openLocationPicker(context),
                                  icon: _resolvingAddress
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.my_location),
                                  label: Text(
                                    _resolvingAddress
                                        ? 'Resolviendo direccion...'
                                        : 'Seleccionar en mapa',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Horario y disponibilidad',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _openingTimeController,
                                      decoration: const InputDecoration(
                                        labelText: 'Apertura',
                                        hintText: '08:00',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _closingTimeController,
                                      decoration: const InputDecoration(
                                        labelText: 'Cierre',
                                        hintText: '18:00',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _availableNow,
                                title: const Text('Disponible ahora'),
                                onChanged: (value) =>
                                    setState(() => _availableNow = value),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _hasPhysicalLocation,
                                title: const Text('Tiene local fisico'),
                                subtitle: const Text(
                                  'Tiendas, bares, restaurantes, salones u oficinas.',
                                ),
                                onChanged: (value) => setState(
                                  () => _hasPhysicalLocation = value,
                                ),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _requiresElectricity,
                                title: const Text('Requiere electricidad'),
                                subtitle: const Text(
                                  'Permite registrar bloque, circuito y estado electrico.',
                                ),
                                onChanged: (value) => setState(
                                  () => _requiresElectricity = value,
                                ),
                              ),
                              if (_requiresElectricity) ...[
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _hasElectricService,
                                  title: const Text('Tiene fluido electrico'),
                                  onChanged: (value) => setState(
                                    () => _hasElectricService = value,
                                  ),
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _hasElectricBackup,
                                  title: const Text('Tiene respaldo electrico'),
                                  onChanged: (value) => setState(
                                    () => _hasElectricBackup = value,
                                  ),
                                ),
                                if (_hasElectricBackup) ...[
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _electricBackupType,
                                    decoration: const InputDecoration(
                                      labelText: 'Tipo de respaldo',
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
                                    onChanged: (value) => setState(
                                      () => _electricBackupType = value,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _electricBlockController,
                                        decoration: const InputDecoration(
                                          labelText: 'Bloque electrico',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _electricCircuitController,
                                        decoration: const InputDecoration(
                                          labelText: 'Circuito',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _continue(BuildContext context) {
    if (_step < 2) {
      if (_step == 1 && !_formKey.currentState!.validate()) return;
      setState(() => _step += 1);
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    context.read<BusinessWizardCubit>().createBusiness(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      businessTypeId: _selectedTypeId,
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      whatsapp: _whatsappController.text.trim().isEmpty
          ? null
          : _whatsappController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      province: _provinceController.text.trim().isEmpty
          ? null
          : _provinceController.text.trim(),
      municipality: _municipalityController.text.trim().isEmpty
          ? null
          : _municipalityController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      openingTime: _openingTimeController.text.trim().isEmpty
          ? null
          : _openingTimeController.text.trim(),
      closingTime: _closingTimeController.text.trim().isEmpty
          ? null
          : _closingTimeController.text.trim(),
      availableNow: _availableNow,
      hasPhysicalLocation: _hasPhysicalLocation,
      requiresElectricity: _requiresElectricity,
      hasElectricService: _hasElectricService,
      hasElectricBackup: _hasElectricBackup,
      electricBackupType: _hasElectricBackup ? _electricBackupType : null,
      electricBlock: _electricBlockController.text.trim().isEmpty
          ? null
          : _electricBlockController.text.trim(),
      electricCircuit: _electricCircuitController.text.trim().isEmpty
          ? null
          : _electricCircuitController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
    );
  }

  Future<void> _openLocationPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<_PickedLocation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _LocationPickerSheet(
        initialLatitude: _latitude,
        initialLongitude: _longitude,
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _latitude = picked.latitude;
      _longitude = picked.longitude;
      _resolvingAddress = true;
    });

    await _resolveAddress(picked);
    if (mounted) {
      setState(() => _resolvingAddress = false);
    }
  }

  Future<void> _resolveAddress(_PickedLocation picked) async {
    final result = await sl<ApiClient>().get<Map<String, dynamic>>(
      '/mapbox/geocodificar-inverso',
      queryParameters: {'lat': picked.latitude, 'lng': picked.longitude},
      parser: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
    );

    if (!result.isSuccess || result.data == null) return;
    final data = result.data!;
    final address =
        data['direccion'] ??
        data['place_name'] ??
        data['placeName'] ??
        data['nombre'] ??
        data['address'];
    final province =
        data['provincia'] ??
        data['region'] ??
        data['state'] ??
        data['province'];
    final municipality =
        data['municipio'] ?? data['localidad'] ?? data['place'] ?? data['city'];

    if (!mounted) return;
    if (address is String && address.isNotEmpty) {
      _addressController.text = address;
    }
    if (province is String && province.isNotEmpty) {
      _provinceController.text = province;
    }
    if (municipality is String && municipality.isNotEmpty) {
      _municipalityController.text = municipality;
    }
  }
}

class _PickedLocation {
  const _PickedLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({this.initialLatitude, this.initialLongitude});

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  static const _defaultLatitude = 23.1136;
  static const _defaultLongitude = -82.3666;

  MapboxMap? _mapboxMap;
  late double _latitude = widget.initialLatitude ?? _defaultLatitude;
  late double _longitude = widget.initialLongitude ?? _defaultLongitude;
  bool _locating = false;
  bool _tokenReady = false;

  @override
  void initState() {
    super.initState();
    _tokenReady = AppEnvironment.mapboxAccessToken.isNotEmpty;
    if (_tokenReady) {
      MapboxOptions.setAccessToken(AppEnvironment.mapboxAccessToken);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.62,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Ubicacion del negocio', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Toca el mapa para fijar el punto exacto o usa la ubicacion actual del dispositivo.',
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 360,
                child: _tokenReady
                    ? Stack(
                        children: [
                          MapWidget(
                            viewport: CameraViewportState(
                              center: Point(
                                coordinates: Position(_longitude, _latitude),
                              ),
                              zoom: 13,
                            ),
                            onMapCreated: (mapboxMap) {
                              _mapboxMap = mapboxMap;
                              mapboxMap.addInteraction(
                                TapInteraction.onMap((gesture) {
                                  final coordinates = gesture.point.coordinates;
                                  setState(() {
                                    _longitude = coordinates.lng.toDouble();
                                    _latitude = coordinates.lat.toDouble();
                                  });
                                }),
                                interactionID: 'business_location_tap',
                              );
                            },
                          ),
                          Center(
                            child: Icon(
                              Icons.location_pin,
                              color: theme.colorScheme.error,
                              size: 42,
                            ),
                          ),
                        ],
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 44,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Configura MAPBOX_ACCESS_TOKEN para mostrar el mapa.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Coordenadas: ${_latitude.toStringAsFixed(6)}, ${_longitude.toStringAsFixed(6)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _useCurrentLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('Mi ubicacion'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      _PickedLocation(
                        latitude: _latitude,
                        longitude: _longitude,
                      ),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Usar punto'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showMessage('Activa la ubicacion del dispositivo.');
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        _showMessage('Permiso de ubicacion denegado.');
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(_longitude, _latitude)),
          zoom: 15,
        ),
        MapAnimationOptions(duration: 650),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showSnackOrAuthDialog(context, message);
  }
}
