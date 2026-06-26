import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/environment/app_environment.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../blocs/business_wizard/business_wizard_cubit.dart';
import '../../blocs/business_wizard/business_wizard_state.dart';
import '../../data/models/business_type_model.dart';
import '../../../business/data/services/local_product_ocr_service.dart';

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
  final _firstItemNameController = TextEditingController();
  final _firstItemBrandController = TextEditingController();
  final _firstItemDescriptionController = TextEditingController();
  final _firstItemPriceController = TextEditingController();
  final _firstItemStockController = TextEditingController(text: '1');
  final _firstItemCategoryController = TextEditingController();
  int _step = 0;
  String? _selectedTypeId;
  String? _electricBackupType;
  String _firstItemCurrency = 'CUP';
  bool _firstItemInInventory = true;
  bool _firstItemPurchasable = true;
  picker.XFile? _firstItemFrontPhoto;
  picker.XFile? _firstItemBackPhoto;
  List<String> _firstItemImageUrls = const [];
  Map<String, dynamic> _firstItemDetectedFeatures = const {};
  bool _detectingFirstItem = false;
  double? _latitude;
  double? _longitude;
  bool _resolvingAddress = false;
  bool _availableNow = true;
  bool _acceptsTransfer = false;
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
    _firstItemNameController.dispose();
    _firstItemBrandController.dispose();
    _firstItemDescriptionController.dispose();
    _firstItemPriceController.dispose();
    _firstItemStockController.dispose();
    _firstItemCategoryController.dispose();
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
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: Theme.of(context).inputDecorationTheme
                    .copyWith(
                      contentPadding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
                      floatingLabelStyle: Theme.of(context).textTheme.bodySmall,
                    ),
              ),
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
                          child: Text(
                            _step == 3
                                ? 'Finalizar configuracion'
                                : 'Continuar',
                          ),
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
                        : _BusinessTypeSelector(
                            types: state.types,
                            selectedTypeId: _selectedTypeId,
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
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
                                  value: _acceptsTransfer,
                                  title: const Text(
                                    'Acepta pagos por transferencia',
                                  ),
                                  subtitle: const Text(
                                    'Visible para clientes en la tienda y al coordinar pedidos.',
                                  ),
                                  onChanged: (value) =>
                                      setState(() => _acceptsTransfer = value),
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
                                    title: const Text(
                                      'Tiene respaldo electrico',
                                    ),
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
                                          controller:
                                              _electricCircuitController,
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
                  Step(
                    title: Text(_firstItemLabelTitle(state)),
                    isActive: _step >= 3,
                    content: _FirstItemStep(
                      title: _firstItemLabelTitle(state),
                      subtitle: _firstItemLabelSubtitle(state),
                      nameController: _firstItemNameController,
                      brandController: _firstItemBrandController,
                      descriptionController: _firstItemDescriptionController,
                      priceController: _firstItemPriceController,
                      stockController: _firstItemStockController,
                      categoryController: _firstItemCategoryController,
                      currency: _firstItemCurrency,
                      requiredNow: _step == 3,
                      inInventory: _firstItemInInventory,
                      purchasable: _firstItemPurchasable,
                      frontPhoto: _firstItemFrontPhoto,
                      backPhoto: _firstItemBackPhoto,
                      detecting: _detectingFirstItem,
                      onPickFrontPhoto: () => _pickFirstItemPhoto(front: true),
                      onPickBackPhoto: () => _pickFirstItemPhoto(front: false),
                      onDetectPhotos:
                          _firstItemFrontPhoto == null &&
                              _firstItemBackPhoto == null
                          ? null
                          : _detectFirstItemFromPhotos,
                      onCurrencyChanged: (value) =>
                          setState(() => _firstItemCurrency = value),
                      onInInventoryChanged: (value) =>
                          setState(() => _firstItemInInventory = value),
                      onPurchasableChanged: (value) =>
                          setState(() => _firstItemPurchasable = value),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _continue(BuildContext context) async {
    if (_step < 3) {
      if ((_step == 1 || _step == 2) && !_formKey.currentState!.validate()) {
        return;
      }
      setState(() => _step += 1);
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    final firstItemPrice = double.tryParse(
      _firstItemPriceController.text.trim().replaceAll(',', '.'),
    );
    final wizardCubit = context.read<BusinessWizardCubit>();
    final uploadedImageUrls = _firstItemImageUrls.isNotEmpty
        ? _firstItemImageUrls
        : await _uploadFirstItemPhotos();
    if (!mounted) return;
    wizardCubit.createBusiness(
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
      acceptsTransfer: _acceptsTransfer,
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
      firstItemName: _firstItemNameController.text.trim(),
      firstItemBrand: _firstItemBrandController.text.trim(),
      firstItemDescription: _firstItemDescriptionController.text.trim(),
      firstItemPrice: firstItemPrice,
      firstItemCurrency: _firstItemCurrency,
      firstItemStock: int.tryParse(_firstItemStockController.text.trim()),
      firstItemCategory: _firstItemCategoryController.text.trim(),
      firstItemImageUrls: uploadedImageUrls,
      firstItemDetectedFeatures: _firstItemDetectedFeatures,
      firstItemInInventory: _firstItemInInventory,
      firstItemPurchasable: _firstItemPurchasable,
    );
  }

  Future<List<String>> _uploadFirstItemPhotos() async {
    final photos = [
      ('frente', _firstItemFrontPhoto),
      ('reverso', _firstItemBackPhoto),
    ].where((item) => item.$2 != null).toList();
    if (photos.isEmpty) return const [];

    final uploaded = <String>[];
    for (final photo in photos) {
      try {
        final bytes = await photo.$2!.readAsBytes();
        final result = await sl<ApiClient>().post<Map<String, dynamic>>(
          '/storage/subir',
          data: {
            'archivo_base64': base64Encode(bytes),
            'nombre_archivo': 'producto-${photo.$1}.jpg',
            'content_type': 'image/jpeg',
            'bucket': 'productos',
            'scope': 'wizard-productos',
          },
          parser: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
        );
        final url = result.data?['public_url']?.toString();
        if (result.isSuccess && url != null && url.isNotEmpty) {
          uploaded.add(url);
        }
      } catch (_) {
        // Si la red falla, el producto se crea igual y el usuario puede editar fotos luego.
      }
    }
    return uploaded;
  }

  String _firstItemLabelTitle(BusinessWizardState state) {
    final category = _selectedBusinessType(state)?.parentCategory;
    if (category == 'servicio' || category == 'transporte') {
      return 'Primer servicio';
    }
    if (category == 'gastronomia') return 'Primer plato o oferta';
    if (category == 'inmobiliaria') return 'Primera publicacion';
    return 'Primer producto';
  }

  String _firstItemLabelSubtitle(BusinessWizardState state) {
    final category = _selectedBusinessType(state)?.parentCategory;
    if (category == 'servicio' || category == 'transporte') {
      return 'Agrega un servicio inicial para que tu negocio aparezca operativo desde el primer dia.';
    }
    if (category == 'gastronomia') {
      return 'Agrega un plato, menu u oferta inicial. Luego podras crear cartas completas y QR.';
    }
    if (category == 'inmobiliaria') {
      return 'Agrega una publicacion inicial. Luego podras ampliar fotos, ubicacion y caracteristicas.';
    }
    return 'Agrega un producto inicial con precio y stock para probar tu tienda.';
  }

  BusinessTypeModel? _selectedBusinessType(BusinessWizardState state) {
    for (final type in state.types) {
      if (type.id == _selectedTypeId) return type;
    }
    return null;
  }

  Future<void> _pickFirstItemPhoto({required bool front}) async {
    final source = await _chooseFirstItemImageSource();
    if (source == null) return;
    final image = await picker.ImagePicker().pickImage(
      source: source,
      imageQuality: 68,
      maxWidth: 960,
    );
    if (image == null || !mounted) return;
    setState(() {
      if (front) {
        _firstItemFrontPhoto = image;
      } else {
        _firstItemBackPhoto = image;
      }
    });
  }

  Future<picker.ImageSource?> _chooseFirstItemImageSource() {
    return showModalBottomSheet<picker.ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tomar foto'),
                subtitle: const Text('Usar la camara del telefono'),
                onTap: () =>
                    Navigator.of(context).pop(picker.ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir desde galeria'),
                subtitle: const Text('Usar una imagen guardada'),
                onTap: () =>
                    Navigator.of(context).pop(picker.ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _detectFirstItemFromPhotos() async {
    final cubit = context.read<BusinessWizardCubit>();
    setState(() => _detectingFirstItem = true);
    try {
      final frontBytes = await _firstItemFrontPhoto?.readAsBytes();
      final backBytes = await _firstItemBackPhoto?.readAsBytes();
      var detection = await const LocalProductOcrService().detectPackage(
        frontImagePath: _firstItemFrontPhoto?.path,
        backImagePath: _firstItemBackPhoto?.path,
      );
      detection ??= await cubit.detectFirstProduct(
        frontImageBase64: frontBytes == null ? null : base64Encode(frontBytes),
        backImageBase64: backBytes == null ? null : base64Encode(backBytes),
      );
      if (!mounted || detection == null) return;
      final detected = detection;
      if (detected.name != null) {
        _firstItemNameController.text = detected.name!;
      }
      if (detected.brand != null) {
        _firstItemBrandController.text = detected.brand!;
      }
      if (detected.description != null) {
        _firstItemDescriptionController.text = detected.description!;
      }
      if (detected.category != null) {
        _firstItemCategoryController.text = detected.category!;
      }
      if (detected.price != null) {
        _firstItemPriceController.text = detected.price!.toStringAsFixed(2);
      }
      setState(() {
        if (detected.currency != null &&
            ['CUP', 'MLC', 'USD'].contains(detected.currency)) {
          _firstItemCurrency = detected.currency!;
        }
        _firstItemImageUrls = detected.imageUrls;
        _firstItemDetectedFeatures = detected.toProductFeatures(
          category: _firstItemCategoryController.text,
        );
      });
      if (detected.properties['fuente_deteccion'] == 'ocr_local') {
        showSnackOrAuthDialog(
          context,
          'Datos detectados localmente. Revisa y corrige antes de finalizar.',
        );
      }
    } finally {
      if (mounted) setState(() => _detectingFirstItem = false);
    }
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

class _FirstItemStep extends StatelessWidget {
  const _FirstItemStep({
    required this.title,
    required this.subtitle,
    required this.nameController,
    required this.brandController,
    required this.descriptionController,
    required this.priceController,
    required this.stockController,
    required this.categoryController,
    required this.currency,
    required this.requiredNow,
    required this.inInventory,
    required this.purchasable,
    required this.frontPhoto,
    required this.backPhoto,
    required this.detecting,
    required this.onPickFrontPhoto,
    required this.onPickBackPhoto,
    required this.onDetectPhotos,
    required this.onCurrencyChanged,
    required this.onInInventoryChanged,
    required this.onPurchasableChanged,
  });

  final String title;
  final String subtitle;
  final TextEditingController nameController;
  final TextEditingController brandController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController stockController;
  final TextEditingController categoryController;
  final String currency;
  final bool requiredNow;
  final bool inInventory;
  final bool purchasable;
  final picker.XFile? frontPhoto;
  final picker.XFile? backPhoto;
  final bool detecting;
  final VoidCallback onPickFrontPhoto;
  final VoidCallback onPickBackPhoto;
  final VoidCallback? onDetectPhotos;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<bool> onInInventoryChanged;
  final ValueChanged<bool> onPurchasableChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.add_business_outlined,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(subtitle),
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
                  'Autocompletar escaneando empaque',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Toma foto del frente y reverso. La app lee el texto localmente y rellena marca, nombre, tamano, peso e ingredientes.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _WizardPackagePhotoButton(
                        title: 'Frente',
                        image: frontPhoto,
                        onPressed: detecting ? null : onPickFrontPhoto,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _WizardPackagePhotoButton(
                        title: 'Reverso',
                        image: backPhoto,
                        onPressed: detecting ? null : onPickBackPhoto,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: detecting ? null : onDetectPhotos,
                    icon: detecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      detecting
                          ? 'Analizando empaque...'
                          : 'Detectar y rellenar formulario',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej: Pizza napolitana, corte clasico, arroz 5kg',
          ),
          validator: (value) =>
              requiredNow && (value == null || value.trim().isEmpty)
              ? 'Agrega al menos un producto o servicio inicial'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: brandController,
          decoration: const InputDecoration(
            labelText: 'Marca o proveedor',
            hintText: 'Opcional',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: categoryController,
          decoration: const InputDecoration(
            labelText: 'Categoria interna',
            hintText: 'Ej: Alimentos, Barberia, Delivery, Menu',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Descripcion',
            hintText: 'Cuenta que incluye, condiciones o detalles importantes.',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Precio'),
                validator: (value) {
                  if (!requiredNow) return null;
                  final parsed = double.tryParse(
                    (value ?? '').trim().replaceAll(',', '.'),
                  );
                  if (parsed == null || parsed < 0) {
                    return 'Precio invalido';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: currency,
                decoration: const InputDecoration(labelText: 'Moneda'),
                items: const [
                  DropdownMenuItem(value: 'CUP', child: Text('CUP')),
                  DropdownMenuItem(value: 'MLC', child: Text('MLC')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                ],
                onChanged: (value) {
                  if (value != null) onCurrencyChanged(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: stockController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Cantidad o cupos disponibles',
            hintText: 'Ej: 10',
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: inInventory,
          title: const Text('Agregar al inventario'),
          subtitle: const Text(
            'Si esta apagado queda creado, pero no se muestra a clientes.',
          ),
          onChanged: onInInventoryChanged,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: purchasable,
          title: const Text('Visible para clientes'),
          subtitle: const Text(
            'Debe estar activo, en inventario y con disponibilidad para aparecer en tienda.',
          ),
          onChanged: onPurchasableChanged,
        ),
      ],
    );
  }
}

class _BusinessTypeSelector extends StatelessWidget {
  const _BusinessTypeSelector({
    required this.types,
    required this.selectedTypeId,
    required this.onChanged,
  });

  final List<BusinessTypeModel> types;
  final String? selectedTypeId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedType;
    return InkWell(
      onTap: () => _openPicker(context),
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        isEmpty: selected == null,
        decoration: InputDecoration(
          labelText: selected == null ? null : 'Selecciona un tipo',
          hintText: 'Selecciona un tipo',
          suffixIcon: const Icon(Icons.keyboard_arrow_down),
          contentPadding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
        ),
        child: Text(
          selected == null
              ? 'Toca para elegir el tipo de negocio'
              : _typeLabel(selected),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  BusinessTypeModel? get _selectedType {
    for (final type in types) {
      if (type.id == selectedTypeId) return type;
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BusinessTypePickerSheet(
        types: types,
        selectedTypeId: selectedTypeId,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  static String _typeLabel(BusinessTypeModel type) {
    return [
      type.name,
      if (type.parentCategory?.isNotEmpty == true) '(${type.parentCategory})',
    ].join(' ');
  }
}

class _BusinessTypePickerSheet extends StatefulWidget {
  const _BusinessTypePickerSheet({
    required this.types,
    required this.selectedTypeId,
  });

  final List<BusinessTypeModel> types;
  final String? selectedTypeId;

  @override
  State<_BusinessTypePickerSheet> createState() =>
      _BusinessTypePickerSheetState();
}

class _BusinessTypePickerSheetState extends State<_BusinessTypePickerSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.types.where((type) {
      if (query.isEmpty) return true;
      return type.name.toLowerCase().contains(query) ||
          (type.parentCategory ?? '').toLowerCase().contains(query);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar tipo de negocio',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final type = filtered[index];
                  final selected = type.id == widget.selectedTypeId;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: selected
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    leading: Icon(
                      selected ? Icons.check_circle : Icons.storefront_outlined,
                      color: selected
                          ? Theme.of(context).colorScheme.secondary
                          : null,
                    ),
                    title: Text(type.name, maxLines: 1),
                    subtitle: Text(
                      type.parentCategory ?? 'Sin categoria',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(context).pop(type.id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WizardPackagePhotoButton extends StatelessWidget {
  const _WizardPackagePhotoButton({
    required this.title,
    required this.image,
    required this.onPressed,
  });

  final String title;
  final picker.XFile? image;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          image: image == null
              ? null
              : DecorationImage(
                  image: FileImage(File(image!.path)),
                  fit: BoxFit.cover,
                ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: image == null ? null : Colors.black.withValues(alpha: 0.34),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  image == null
                      ? Icons.add_a_photo_outlined
                      : Icons.check_circle,
                ),
                const SizedBox(height: 8),
                Text(
                  image == null ? 'Foto $title' : '$title listo',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
