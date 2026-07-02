import 'dart:async';
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

const Map<String, List<String>> _cubaMunicipalities = {
  'Pinar del Rio': [
    'Consolacion del Sur',
    'Guane',
    'La Palma',
    'Los Palacios',
    'Mantua',
    'Minas de Matahambre',
    'Pinar del Rio',
    'San Juan y Martinez',
    'San Luis',
    'Sandino',
    'Vinales',
  ],
  'Artemisa': [
    'Alquizar',
    'Artemisa',
    'Bahia Honda',
    'Bauta',
    'Caimito',
    'Candelaria',
    'Guanajay',
    'Guira de Melena',
    'Mariel',
    'San Antonio de los Banos',
    'San Cristobal',
  ],
  'La Habana': [
    'Arroyo Naranjo',
    'Boyeros',
    'Centro Habana',
    'Cerro',
    'Cotorro',
    'Diez de Octubre',
    'Guanabacoa',
    'Habana del Este',
    'Habana Vieja',
    'La Lisa',
    'Marianao',
    'Playa',
    'Plaza de la Revolucion',
    'Regla',
    'San Miguel del Padron',
  ],
  'Mayabeque': [
    'Batabano',
    'Bejucal',
    'Guines',
    'Jaruco',
    'Madruga',
    'Melena del Sur',
    'Nueva Paz',
    'Quivican',
    'San Jose de las Lajas',
    'San Nicolas',
    'Santa Cruz del Norte',
  ],
  'Matanzas': [
    'Calimete',
    'Cardenas',
    'Cienaga de Zapata',
    'Colon',
    'Jaguey Grande',
    'Jovellanos',
    'Limonar',
    'Los Arabos',
    'Marti',
    'Matanzas',
    'Pedro Betancourt',
    'Perico',
    'Union de Reyes',
  ],
  'Cienfuegos': [
    'Abreus',
    'Aguada de Pasajeros',
    'Cienfuegos',
    'Cruces',
    'Cumanayagua',
    'Lajas',
    'Palmira',
    'Rodas',
  ],
  'Villa Clara': [
    'Caibarien',
    'Camajuani',
    'Cifuentes',
    'Corralillo',
    'Encrucijada',
    'Manicaragua',
    'Placetas',
    'Quemado de Guines',
    'Ranchuelo',
    'Remedios',
    'Sagua la Grande',
    'Santa Clara',
    'Santo Domingo',
  ],
  'Sancti Spiritus': [
    'Cabaiguan',
    'Fomento',
    'Jatibonico',
    'La Sierpe',
    'Sancti Spiritus',
    'Taguasco',
    'Trinidad',
    'Yaguajay',
  ],
  'Ciego de Avila': [
    'Baragua',
    'Bolivia',
    'Chambas',
    'Ciego de Avila',
    'Ciro Redondo',
    'Florencia',
    'Majagua',
    'Moron',
    'Primero de Enero',
    'Venezuela',
  ],
  'Camaguey': [
    'Camaguey',
    'Carlos Manuel de Cespedes',
    'Esmeralda',
    'Florida',
    'Guaimaro',
    'Jimaguayu',
    'Minas',
    'Najasa',
    'Nuevitas',
    'Santa Cruz del Sur',
    'Sibanicu',
    'Sierra de Cubitas',
    'Vertientes',
  ],
  'Las Tunas': [
    'Amancio',
    'Colombia',
    'Jesus Menendez',
    'Jobabo',
    'Las Tunas',
    'Majibacoa',
    'Manati',
    'Puerto Padre',
  ],
  'Holguin': [
    'Antilla',
    'Baguanos',
    'Banes',
    'Cacocum',
    'Calixto Garcia',
    'Cueto',
    'Frank Pais',
    'Gibara',
    'Holguin',
    'Mayari',
    'Moa',
    'Rafael Freyre',
    'Sagua de Tanamo',
    'Urbano Noris',
  ],
  'Granma': [
    'Bartolome Maso',
    'Bayamo',
    'Buey Arriba',
    'Campechuela',
    'Cauto Cristo',
    'Guisa',
    'Jiguani',
    'Manzanillo',
    'Media Luna',
    'Niquero',
    'Pilon',
    'Rio Cauto',
    'Yara',
  ],
  'Santiago de Cuba': [
    'Contramaestre',
    'Guama',
    'Mella',
    'Palma Soriano',
    'San Luis',
    'Santiago de Cuba',
    'Segundo Frente',
    'Songo-La Maya',
    'Tercer Frente',
  ],
  'Guantanamo': [
    'Baracoa',
    'Caimanera',
    'El Salvador',
    'Guantanamo',
    'Imias',
    'Maisi',
    'Manuel Tames',
    'Niceto Perez',
    'San Antonio del Sur',
    'Yateras',
  ],
  'Isla de la Juventud': ['Isla de la Juventud'],
};

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
  Timer? _addressDebounce;
  List<_AddressSuggestion> _addressSuggestions = const [];
  bool _searchingAddress = false;
  String? _addressSearchMessage;

  @override
  void dispose() {
    _addressDebounce?.cancel();
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

  String? get _selectedProvince {
    final value = _provinceController.text.trim();
    return _cubaMunicipalities.containsKey(value) ? value : null;
  }

  List<String> get _municipalitiesForSelectedProvince {
    return _cubaMunicipalities[_selectedProvince] ?? const [];
  }

  String? get _selectedMunicipality {
    final value = _municipalityController.text.trim();
    return _municipalitiesForSelectedProvince.contains(value) ? value : null;
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
                      contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      floatingLabelStyle: Theme.of(context).textTheme.bodySmall,
                    ),
              ),
              child: Stepper(
                currentStep: _step,
                type: StepperType.vertical,
                onStepTapped: (step) {
                  if (step <= _step) {
                    setState(() => _step = step);
                  }
                },
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
                                _selectBusinessType(value, state),
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
                        DropdownButtonFormField<String>(
                          key: ValueKey('province-${_selectedProvince ?? ''}'),
                          initialValue: _selectedProvince,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Provincia',
                          ),
                          items: _cubaMunicipalities.keys
                              .map(
                                (province) => DropdownMenuItem(
                                  value: province,
                                  child: Text(
                                    province,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          validator: (value) =>
                              value == null ? 'Selecciona la provincia' : null,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _provinceController.text = value;
                              if (!_municipalitiesForSelectedProvince.contains(
                                _municipalityController.text.trim(),
                              )) {
                                _municipalityController.clear();
                              }
                              _addressSuggestions = const [];
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'municipality-${_selectedProvince ?? ''}-${_selectedMunicipality ?? ''}',
                          ),
                          initialValue: _selectedMunicipality,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Municipio',
                          ),
                          items: _municipalitiesForSelectedProvince
                              .map(
                                (municipality) => DropdownMenuItem(
                                  value: municipality,
                                  child: Text(
                                    municipality,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          validator: (value) =>
                              value == null ? 'Selecciona el municipio' : null,
                          onChanged: _selectedProvince == null
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _municipalityController.text = value;
                                    _addressSuggestions = const [];
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Direccion',
                            hintText: 'Calle, numero, reparto o referencia',
                            suffixIcon: _searchingAddress
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.travel_explore),
                          ),
                          onChanged: _onAddressChanged,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Escribe o selecciona la direccion'
                              : null,
                        ),
                        if (_addressSearchMessage != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _addressSearchMessage!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                        if (_addressSuggestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _AddressSuggestionsList(
                            suggestions: _addressSuggestions,
                            onSelected: _selectAddressSuggestion,
                          ),
                        ],
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
                      mode: _firstItemMode(state),
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
                          _firstItemMode(state).usesPackageScan &&
                              (_firstItemFrontPhoto != null ||
                                  _firstItemBackPhoto != null)
                          ? _detectFirstItemFromPhotos
                          : null,
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
      final error = _validateStep(_step);
      if (error != null) {
        showSnackOrAuthDialog(context, error);
        return;
      }
      setState(() => _step += 1);
      return;
    }

    final error = _validateStep(1) ?? _validateStep(2) ?? _validateStep(3);
    if (error != null) {
      showSnackOrAuthDialog(context, error);
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

  String? _validateStep(int step) {
    if (step == 0 && _selectedTypeId == null) {
      return 'Selecciona el tipo de negocio.';
    }
    if (step == 1 && _nameController.text.trim().isEmpty) {
      return 'Escribe el nombre del negocio.';
    }
    if (step == 2) {
      if (_selectedProvince == null) return 'Selecciona la provincia.';
      if (_selectedMunicipality == null) return 'Selecciona el municipio.';
      if (_addressController.text.trim().isEmpty) {
        return 'Escribe o selecciona la direccion.';
      }
    }
    if (step == 3) {
      final name = _firstItemNameController.text.trim();
      final price = double.tryParse(
        _firstItemPriceController.text.trim().replaceAll(',', '.'),
      );
      if (name.isEmpty) {
        return _firstItemMode(
              context.read<BusinessWizardCubit>().state,
            ).usesPackageScan
            ? 'Agrega el nombre del primer producto.'
            : 'Agrega el nombre del primer servicio o elemento.';
      }
      if (price == null || price <= 0) {
        return 'Agrega un precio valido.';
      }
    }
    return null;
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

  _FirstItemMode _firstItemMode(BusinessWizardState state) {
    final category = _selectedBusinessType(state)?.parentCategory;
    if (category == 'gastronomia') return _FirstItemMode.food;
    if (category == 'servicio') return _FirstItemMode.service;
    if (category == 'transporte') return _FirstItemMode.transport;
    if (category == 'inmobiliaria') return _FirstItemMode.listing;
    return _FirstItemMode.packagedProduct;
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

  void _selectBusinessType(String? value, BusinessWizardState state) {
    final nextType = state.types
        .where((type) => type.id == value)
        .cast<BusinessTypeModel?>()
        .firstOrNull;
    final nextMode = switch (nextType?.parentCategory) {
      'gastronomia' => _FirstItemMode.food,
      'servicio' => _FirstItemMode.service,
      'transporte' => _FirstItemMode.transport,
      'inmobiliaria' => _FirstItemMode.listing,
      _ => _FirstItemMode.packagedProduct,
    };

    setState(() {
      _selectedTypeId = value;
      if (!nextMode.usesPackageScan) {
        _firstItemBackPhoto = null;
        _firstItemDetectedFeatures = const {};
      }
      if (!nextMode.showSecondaryField) {
        _firstItemBrandController.clear();
      }
    });
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

  void _onAddressChanged(String value) {
    _addressDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      setState(() {
        _addressSuggestions = const [];
        _addressSearchMessage = null;
      });
      return;
    }

    _addressDebounce = Timer(const Duration(milliseconds: 450), () {
      _searchAddressSuggestions(trimmed);
    });
  }

  Future<void> _searchAddressSuggestions(String address) async {
    if (!mounted) return;
    setState(() {
      _searchingAddress = true;
      _addressSearchMessage = null;
    });

    final parts = [
      address,
      if (_selectedMunicipality != null) _selectedMunicipality,
      if (_selectedProvince != null) _selectedProvince,
      'Cuba',
    ];
    final query = parts.whereType<String>().join(', ');
    final result = await sl<ApiClient>().get<List<_AddressSuggestion>>(
      '/mapbox/geocodificar',
      queryParameters: {'direccion': query},
      parser: _parseAddressSuggestions,
    );

    if (!mounted) return;
    setState(() {
      _searchingAddress = false;
      if (result.isSuccess) {
        _addressSuggestions = result.data ?? const [];
        _addressSearchMessage = _addressSuggestions.isEmpty
            ? 'No encontramos coincidencias. Ajusta el texto o usa el mapa.'
            : null;
      } else {
        _addressSuggestions = const [];
        _addressSearchMessage =
            'No se pudo consultar Mapbox. Puedes escribir la direccion o usar el mapa.';
      }
    });
  }

  List<_AddressSuggestion> _parseAddressSuggestions(dynamic json) {
    final rawFeatures = json is Map
        ? (json['features'] ?? json['resultados'] ?? json['lugares'])
        : json;
    if (rawFeatures is! List) return const [];

    return rawFeatures
        .whereType<Map>()
        .map((feature) {
          final map = Map<String, dynamic>.from(feature);
          final placeName =
              map['place_name'] ??
              map['placeName'] ??
              map['direccion'] ??
              map['nombre'] ??
              map['text'];
          if (placeName is! String || placeName.trim().isEmpty) {
            return null;
          }

          final contextItems = map['context'] is List
              ? (map['context'] as List).whereType<Map>().toList()
              : const <Map>[];
          final province = _matchProvince(
            _readContextValue(contextItems, 'region') ??
                map['provincia']?.toString() ??
                map['region']?.toString() ??
                map['state']?.toString() ??
                map['province']?.toString(),
          );
          final municipality = _matchMunicipality(
            _readContextValue(contextItems, 'place') ??
                _readContextValue(contextItems, 'locality') ??
                map['municipio']?.toString() ??
                map['localidad']?.toString() ??
                map['place']?.toString() ??
                map['city']?.toString(),
            province,
          );

          final coordinates = _extractCoordinates(map);
          return _AddressSuggestion(
            title: placeName.trim(),
            subtitle: [
              if (municipality != null) municipality,
              if (province != null) province,
            ].join(' - '),
            province: province,
            municipality: municipality,
            latitude: coordinates?.$1,
            longitude: coordinates?.$2,
          );
        })
        .whereType<_AddressSuggestion>()
        .take(5)
        .toList();
  }

  String? _readContextValue(List<Map> contextItems, String prefix) {
    for (final item in contextItems) {
      final id = item['id']?.toString() ?? '';
      if (id.startsWith('$prefix.')) {
        return (item['text_es'] ?? item['text'] ?? item['place_name'])
            ?.toString();
      }
    }
    return null;
  }

  (double, double)? _extractCoordinates(Map<String, dynamic> map) {
    final center = map['center'];
    if (center is List && center.length >= 2) {
      final lng = _toDouble(center[0]);
      final lat = _toDouble(center[1]);
      if (lat != null && lng != null) return (lat, lng);
    }

    final geometry = map['geometry'];
    if (geometry is Map && geometry['coordinates'] is List) {
      final coordinates = geometry['coordinates'] as List;
      if (coordinates.length >= 2) {
        final lng = _toDouble(coordinates[0]);
        final lat = _toDouble(coordinates[1]);
        if (lat != null && lng != null) return (lat, lng);
      }
    }

    final coordinates = map['coordenadas'];
    if (coordinates is Map) {
      final lat = _toDouble(coordinates['lat'] ?? coordinates['latitude']);
      final lng = _toDouble(coordinates['lng'] ?? coordinates['longitude']);
      if (lat != null && lng != null) return (lat, lng);
    }
    return null;
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void _selectAddressSuggestion(_AddressSuggestion suggestion) {
    setState(() {
      _addressController.text = suggestion.title;
      _applyProvinceMunicipality(
        province: suggestion.province,
        municipality: suggestion.municipality,
      );
      _latitude = suggestion.latitude ?? _latitude;
      _longitude = suggestion.longitude ?? _longitude;
      _addressSuggestions = const [];
      _addressSearchMessage = null;
    });
  }

  void _applyProvinceMunicipality({String? province, String? municipality}) {
    final matchedProvince = _matchProvince(province) ?? _selectedProvince;
    if (matchedProvince != null) {
      _provinceController.text = matchedProvince;
    }

    final matchedMunicipality = _matchMunicipality(
      municipality,
      matchedProvince,
    );
    if (matchedMunicipality != null) {
      _municipalityController.text = matchedMunicipality;
    } else if (matchedProvince != null &&
        !_municipalitiesForSelectedProvince.contains(
          _municipalityController.text.trim(),
        )) {
      _municipalityController.clear();
    }
  }

  String? _matchProvince(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = _normalizeText(raw);
    for (final province in _cubaMunicipalities.keys) {
      final candidate = _normalizeText(province);
      if (normalized == candidate ||
          normalized.contains(candidate) ||
          candidate.contains(normalized)) {
        return province;
      }
    }
    if (normalized.contains('habana') || normalized.contains('havana')) {
      return 'La Habana';
    }
    if (normalized.contains('isla')) return 'Isla de la Juventud';
    return null;
  }

  String? _matchMunicipality(String? raw, String? province) {
    if (raw == null || raw.trim().isEmpty || province == null) return null;
    final normalized = _normalizeText(raw);
    for (final municipality in _cubaMunicipalities[province] ?? const []) {
      final candidate = _normalizeText(municipality);
      if (normalized == candidate ||
          normalized.contains(candidate) ||
          candidate.contains(normalized)) {
        return municipality;
      }
    }
    return null;
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
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
    _applyProvinceMunicipality(
      province: province is String ? province : null,
      municipality: municipality is String ? municipality : null,
    );
  }
}

class _AddressSuggestion {
  const _AddressSuggestion({
    required this.title,
    required this.subtitle,
    this.province,
    this.municipality,
    this.latitude,
    this.longitude,
  });

  final String title;
  final String subtitle;
  final String? province;
  final String? municipality;
  final double? latitude;
  final double? longitude;
}

class _AddressSuggestionsList extends StatelessWidget {
  const _AddressSuggestionsList({
    required this.suggestions,
    required this.onSelected,
  });

  final List<_AddressSuggestion> suggestions;
  final ValueChanged<_AddressSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final suggestion in suggestions)
            ListTile(
              dense: true,
              leading: Icon(
                Icons.place_outlined,
                color: theme.colorScheme.secondary,
              ),
              title: Text(
                suggestion.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: suggestion.subtitle.isEmpty
                  ? null
                  : Text(
                      suggestion.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => onSelected(suggestion),
            ),
        ],
      ),
    );
  }
}

enum _FirstItemMode {
  packagedProduct,
  food,
  service,
  transport,
  listing;

  bool get usesPackageScan => this == _FirstItemMode.packagedProduct;

  bool get showSecondaryField {
    return switch (this) {
      _FirstItemMode.packagedProduct => true,
      _FirstItemMode.transport => true,
      _FirstItemMode.listing => true,
      _FirstItemMode.food || _FirstItemMode.service => false,
    };
  }

  String get mediaTitle {
    return switch (this) {
      _FirstItemMode.packagedProduct => 'Autocompletar escaneando empaque',
      _FirstItemMode.food => 'Foto del plato u oferta',
      _FirstItemMode.service => 'Foto del servicio',
      _FirstItemMode.transport => 'Foto del vehiculo o servicio',
      _FirstItemMode.listing => 'Foto principal de la publicacion',
    };
  }

  String get mediaDescription {
    return switch (this) {
      _FirstItemMode.packagedProduct =>
        'Toma foto del frente y reverso. La app lee el texto localmente y rellena marca, nombre, tamano, peso e ingredientes.',
      _FirstItemMode.food =>
        'Agrega una imagen atractiva del plato, combo, menu u oferta. Los datos se completan manualmente.',
      _FirstItemMode.service =>
        'Agrega una foto representativa del servicio. No hace falta reverso ni escaneo de etiqueta.',
      _FirstItemMode.transport =>
        'Agrega una foto del vehiculo, ruta o servicio de transporte. Completa los datos manualmente.',
      _FirstItemMode.listing =>
        'Agrega la foto principal de la propiedad, vehiculo o anuncio. Podras sumar mas fotos luego.',
    };
  }

  String get primaryPhotoLabel {
    return switch (this) {
      _FirstItemMode.packagedProduct => 'Frente',
      _FirstItemMode.food => 'Plato',
      _FirstItemMode.service => 'Servicio',
      _FirstItemMode.transport => 'Transporte',
      _FirstItemMode.listing => 'Principal',
    };
  }

  String get nameHint {
    return switch (this) {
      _FirstItemMode.packagedProduct => 'Ej: Arroz 5kg, cerveza, shampoo',
      _FirstItemMode.food => 'Ej: Pizza napolitana, combo familiar',
      _FirstItemMode.service => 'Ej: Corte clasico, instalacion electrica',
      _FirstItemMode.transport => 'Ej: Delivery urbano, mudanza pequena',
      _FirstItemMode.listing => 'Ej: Apartamento 2 cuartos, auto moderno',
    };
  }

  String get brandLabel {
    return switch (this) {
      _FirstItemMode.packagedProduct => 'Marca o proveedor',
      _FirstItemMode.food => 'Cocina o proveedor',
      _FirstItemMode.service => 'Especialidad',
      _FirstItemMode.transport => 'Tipo de vehiculo',
      _FirstItemMode.listing => 'Zona, marca o tipo',
    };
  }

  String get categoryLabel {
    return switch (this) {
      _FirstItemMode.packagedProduct => 'Categoria del producto',
      _FirstItemMode.food => 'Categoria del menu',
      _FirstItemMode.service => 'Categoria del servicio',
      _FirstItemMode.transport => 'Categoria del transporte',
      _FirstItemMode.listing => 'Categoria de la publicacion',
    };
  }

  String get categoryHint {
    return switch (this) {
      _FirstItemMode.packagedProduct => 'Ej: Alimentos, Bebidas, Aseo',
      _FirstItemMode.food => 'Ej: Pizzas, Combos, Bebidas, Postres',
      _FirstItemMode.service => 'Ej: Barberia, Plomeria, Belleza',
      _FirstItemMode.transport => 'Ej: Delivery, Carga, Pasajeros',
      _FirstItemMode.listing => 'Ej: Casas, Autos, Alquileres',
    };
  }

  String get descriptionHint {
    return switch (this) {
      _FirstItemMode.packagedProduct =>
        'Presentacion, tamano, sabor, detalles o condiciones.',
      _FirstItemMode.food =>
        'Ingredientes, acompanantes, tamano, alergenos o tiempo estimado.',
      _FirstItemMode.service =>
        'Que incluye, duracion, condiciones, materiales o zona de cobertura.',
      _FirstItemMode.transport =>
        'Capacidad, cobertura, condiciones, horarios o tipo de carga.',
      _FirstItemMode.listing =>
        'Caracteristicas, ubicacion, estado, condiciones de venta o alquiler.',
    };
  }

  String get priceLabel {
    return switch (this) {
      _FirstItemMode.transport => 'Precio base',
      _FirstItemMode.listing => 'Precio',
      _FirstItemMode.service => 'Precio del servicio',
      _FirstItemMode.food => 'Precio del plato',
      _FirstItemMode.packagedProduct => 'Precio',
    };
  }

  String get stockLabel {
    return switch (this) {
      _FirstItemMode.packagedProduct => 'Cantidad disponible',
      _FirstItemMode.food => 'Porciones disponibles',
      _FirstItemMode.service => 'Cupos o turnos disponibles',
      _FirstItemMode.transport => 'Capacidad disponible',
      _FirstItemMode.listing => 'Unidades disponibles',
    };
  }

  String get stockHint {
    return switch (this) {
      _FirstItemMode.packagedProduct => 'Ej: 10',
      _FirstItemMode.food => 'Ej: 20',
      _FirstItemMode.service => 'Ej: 6',
      _FirstItemMode.transport => 'Ej: 1',
      _FirstItemMode.listing => 'Ej: 1',
    };
  }

  String get inventoryTitle {
    return switch (this) {
      _FirstItemMode.food => 'Agregar al menu',
      _FirstItemMode.service => 'Publicar servicio',
      _FirstItemMode.transport => 'Publicar transporte',
      _FirstItemMode.listing => 'Publicar anuncio',
      _FirstItemMode.packagedProduct => 'Agregar al inventario',
    };
  }

  String get inventorySubtitle {
    return switch (this) {
      _FirstItemMode.food =>
        'Si esta apagado queda guardado, pero no aparece en el menu.',
      _FirstItemMode.service =>
        'Si esta apagado queda guardado, pero no aparece para reservas.',
      _FirstItemMode.transport =>
        'Si esta apagado queda guardado, pero no aparece para solicitudes.',
      _FirstItemMode.listing =>
        'Si esta apagado queda guardado, pero no aparece a clientes.',
      _FirstItemMode.packagedProduct =>
        'Si esta apagado queda creado, pero no se muestra a clientes.',
    };
  }

  String get purchasableTitle {
    return switch (this) {
      _FirstItemMode.food => 'Disponible para ordenar',
      _FirstItemMode.service => 'Disponible para reservar',
      _FirstItemMode.transport => 'Disponible para contratar',
      _FirstItemMode.listing => 'Visible para interesados',
      _FirstItemMode.packagedProduct => 'Visible para clientes',
    };
  }

  String get purchasableSubtitle {
    return switch (this) {
      _FirstItemMode.food =>
        'Debe estar en menu y disponible para aparecer en la tienda.',
      _FirstItemMode.service =>
        'Debe estar publicado y con cupos para aceptar reservas.',
      _FirstItemMode.transport =>
        'Debe estar publicado y disponible para recibir solicitudes.',
      _FirstItemMode.listing =>
        'Debe estar publicado para aparecer en busqueda y tienda.',
      _FirstItemMode.packagedProduct =>
        'Debe estar activo, en inventario y con disponibilidad para aparecer en tienda.',
    };
  }
}

class _FirstItemStep extends StatelessWidget {
  const _FirstItemStep({
    required this.mode,
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

  final _FirstItemMode mode;
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
                  mode.mediaTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(mode.mediaDescription, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                if (mode.usesPackageScan)
                  Row(
                    children: [
                      Expanded(
                        child: _WizardPackagePhotoButton(
                          title: mode.primaryPhotoLabel,
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
                  )
                else
                  _WizardPackagePhotoButton(
                    title: mode.primaryPhotoLabel,
                    image: frontPhoto,
                    height: 148,
                    onPressed: detecting ? null : onPickFrontPhoto,
                  ),
                if (mode.usesPackageScan) ...[
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Nombre',
            hintText: mode.nameHint,
          ),
          validator: (value) =>
              requiredNow && (value == null || value.trim().isEmpty)
              ? 'Agrega al menos un producto o servicio inicial'
              : null,
        ),
        const SizedBox(height: 12),
        if (mode.showSecondaryField) ...[
          TextFormField(
            controller: brandController,
            decoration: InputDecoration(
              labelText: mode.brandLabel,
              hintText: 'Opcional',
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextFormField(
          controller: categoryController,
          decoration: InputDecoration(
            labelText: mode.categoryLabel,
            hintText: mode.categoryHint,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: descriptionController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Descripcion',
            hintText: mode.descriptionHint,
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
                decoration: InputDecoration(labelText: mode.priceLabel),
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
          decoration: InputDecoration(
            labelText: mode.stockLabel,
            hintText: mode.stockHint,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: inInventory,
          title: Text(mode.inventoryTitle),
          subtitle: Text(mode.inventorySubtitle),
          onChanged: onInInventoryChanged,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: purchasable,
          title: Text(mode.purchasableTitle),
          subtitle: Text(mode.purchasableSubtitle),
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
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.keyboard_arrow_down),
          contentPadding: EdgeInsets.fromLTRB(18, 18, 18, 18),
        ),
        child: Text(
          selected == null
              ? 'Selecciona un tipo de negocio'
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
    this.height = 112,
  });

  final String title;
  final picker.XFile? image;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        height: height,
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
  static const _minZoom = 10.0;
  static const _maxZoom = 19.0;

  MapboxMap? _mapboxMap;
  late double _latitude = widget.initialLatitude ?? _defaultLatitude;
  late double _longitude = widget.initialLongitude ?? _defaultLongitude;
  late double _zoom = widget.initialLatitude == null ? 13.5 : 16;
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
                              zoom: _zoom,
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
                          Positioned(
                            right: 12,
                            top: 12,
                            child: _MapZoomControls(
                              zoom: _zoom,
                              minZoom: _minZoom,
                              maxZoom: _maxZoom,
                              onZoomIn: () => _changeZoom(1),
                              onZoomOut: () => _changeZoom(-1),
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
        _zoom = 16;
      });
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(_longitude, _latitude)),
          zoom: _zoom,
        ),
        MapAnimationOptions(duration: 650),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _changeZoom(double delta) async {
    final nextZoom = (_zoom + delta).clamp(_minZoom, _maxZoom).toDouble();
    if (nextZoom == _zoom) return;
    setState(() => _zoom = nextZoom);
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(_longitude, _latitude)),
        zoom: _zoom,
      ),
      MapAnimationOptions(duration: 250),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showSnackOrAuthDialog(context, message);
  }
}

class _MapZoomControls extends StatelessWidget {
  const _MapZoomControls({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Acercar',
            onPressed: zoom >= maxZoom ? null : onZoomIn,
            icon: const Icon(Icons.add),
          ),
          SizedBox(
            width: 34,
            child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ),
          IconButton(
            tooltip: 'Alejar',
            onPressed: zoom <= minZoom ? null : onZoomOut,
            icon: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
