import 'package:flutter/material.dart';

import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../home/data/models/business_model.dart';

class BusinessSpecialCatalogScreen extends StatefulWidget {
  const BusinessSpecialCatalogScreen({required this.business, super.key});

  final BusinessModel business;

  @override
  State<BusinessSpecialCatalogScreen> createState() =>
      _BusinessSpecialCatalogScreenState();
}

class _BusinessSpecialCatalogScreenState
    extends State<BusinessSpecialCatalogScreen> {
  final _apiClient = sl<ApiClient>();
  late Future<List<Map<String, dynamic>>> _catalog;

  bool get _isFuel => widget.business.isFuelBusiness;
  String get _endpoint => _isFuel ? '/combustibles' : '/tasas-cambio';
  String get _title => _isFuel ? 'Combustibles y precios' : 'Tasas de cambio';

  @override
  void initState() {
    super.initState();
    _catalog = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await _apiClient.get<List<Map<String, dynamic>>>(
      _endpoint,
      queryParameters: {
        'negocio_id': widget.business.id,
        'limit': 50,
        'order': 'created_at.asc',
      },
      parser: (json) {
        if (json is! List) return const [];
        return json
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      },
    );
    if (!response.isSuccess) {
      throw StateError(response.error?.message ?? 'No fue posible cargar.');
    }
    return response.data ?? const [];
  }

  void _reload() => setState(() => _catalog = _load());

  Future<void> _edit([Map<String, dynamic>? current]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SpecialCatalogEditor(
        businessId: widget.business.id,
        endpoint: _endpoint,
        isFuel: _isFuel,
        current: current,
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text('Esta accion dejara de mostrar este dato en tu negocio.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await _apiClient.delete<void>(
      '$_endpoint/${item['id']}',
      parser: (_) {},
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Registro eliminado.'
              : (result.error?.message ?? 'No se pudo eliminar.'),
        ),
      ),
    );
    if (result.isSuccess) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(_isFuel ? 'Combustible' : 'Moneda'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _catalog,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'No fue posible cargar esta configuracion.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              );
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Icon(
                    _isFuel
                        ? Icons.local_gas_station_outlined
                        : Icons.currency_exchange,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isFuel
                        ? 'Agrega los combustibles que tienes disponibles.'
                        : 'Agrega las monedas y tasas con que operas.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        _isFuel
                            ? Icons.local_gas_station_outlined
                            : Icons.currency_exchange,
                      ),
                    ),
                    title: Text(_isFuel
                        ? '${item['nombre'] ?? _fuelLabel('${item['tipo'] ?? ''}')}'
                        : '${item['moneda'] ?? 'Moneda'}'),
                    subtitle: Text(
                      _isFuel
                          ? '${_number(item['precio_cup'])} CUP/L  |  ${_number(item['stock_litros'])} L'
                          : 'Compra ${_number(item['tasa_compra_cup'])} CUP | Venta ${_number(item['tasa_venta_cup'])} CUP',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'editar') _edit(item);
                        if (action == 'eliminar') _delete(item);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'editar', child: Text('Editar')),
                        PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _number(dynamic value) {
    final number = value is num ? value : num.tryParse('$value');
    if (number == null) return '-';
    return number % 1 == 0 ? number.toStringAsFixed(0) : number.toStringAsFixed(2);
  }

  String _fuelLabel(String type) {
    const labels = {
      'gasolina_b83': 'Gasolina B-83',
      'gasolina_b87': 'Gasolina B-87',
      'gasolina_b90': 'Gasolina B-90',
      'gasolina_b94': 'Gasolina B-94',
      'gasolina_b100': 'Gasolina B-100',
      'diesel': 'Diesel',
      'diesel_especial': 'Diesel especial',
      'gas_lp': 'Gas licuado',
    };
    return labels[type] ?? 'Combustible';
  }
}

class _SpecialCatalogEditor extends StatefulWidget {
  const _SpecialCatalogEditor({
    required this.businessId,
    required this.endpoint,
    required this.isFuel,
    this.current,
  });

  final String businessId;
  final String endpoint;
  final bool isFuel;
  final Map<String, dynamic>? current;

  @override
  State<_SpecialCatalogEditor> createState() => _SpecialCatalogEditorState();
}

class _SpecialCatalogEditorState extends State<_SpecialCatalogEditor> {
  final _formKey = GlobalKey<FormState>();
  final _firstValueController = TextEditingController();
  final _secondValueController = TextEditingController();
  late String _selection;
  late bool _available;
  bool _saving = false;

  bool get _isFuel => widget.isFuel;
  bool get _editing => widget.current != null;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _selection = '${current?[_isFuel ? 'tipo' : 'moneda'] ?? (_isFuel ? 'gasolina_b90' : 'USD')}';
    _firstValueController.text = '${current?[_isFuel ? 'precio_cup' : 'tasa_compra_cup'] ?? ''}';
    _secondValueController.text = '${current?[_isFuel ? 'stock_litros' : 'tasa_venta_cup'] ?? ''}';
    _available = current?['disponible'] != false;
  }

  @override
  void dispose() {
    _firstValueController.dispose();
    _secondValueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final first = num.tryParse(_firstValueController.text.trim().replaceAll(',', '.'));
    final second = num.tryParse(_secondValueController.text.trim().replaceAll(',', '.'));
    final data = <String, dynamic>{
      'negocio_id': widget.businessId,
      'disponible': _available,
      if (_isFuel) ...{
        'tipo': _selection,
        'nombre': _fuelLabel(_selection),
        'precio_cup': first,
        'stock_litros': second,
      } else ...{
        'moneda': _selection,
        'tasa_compra_cup': first,
        'tasa_venta_cup': second,
      },
    };
    final api = sl<ApiClient>();
    final response = _editing
        ? await api.put<dynamic>('${widget.endpoint}/${widget.current!['id']}', data: data)
        : await api.post<dynamic>(widget.endpoint, data: data);
    if (!mounted) return;
    if (response.isSuccess) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response.error?.message ?? 'No se pudo guardar.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, padding + 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isFuel ? 'Configurar combustible' : 'Configurar tasa',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selection,
                decoration: InputDecoration(labelText: _isFuel ? 'Tipo de combustible' : 'Moneda'),
                items: (_isFuel ? _fuelTypes : _currencies)
                    .map((entry) => DropdownMenuItem(value: entry.$1, child: Text(entry.$2)))
                    .toList(),
                onChanged: _saving ? null : (value) => setState(() => _selection = value ?? _selection),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _isFuel ? 'Precio en CUP por litro' : 'Tasa de compra en CUP'),
                validator: _positiveNumber,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _secondValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _isFuel ? 'Litros disponibles' : 'Tasa de venta en CUP'),
                validator: _positiveNumber,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _available,
                title: const Text('Disponible ahora'),
                onChanged: _saving ? null : (value) => setState(() => _available = value),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Guardando...' : 'Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _positiveNumber(String? value) {
    final number = num.tryParse((value ?? '').trim().replaceAll(',', '.'));
    return number == null || number < 0 ? 'Introduce un valor valido.' : null;
  }

  String _fuelLabel(String type) => _fuelTypes
      .firstWhere((entry) => entry.$1 == type, orElse: () => ('otro', 'Combustible'))
      .$2;
}

const _fuelTypes = <(String, String)>[
  ('gasolina_b83', 'Gasolina B-83'),
  ('gasolina_b87', 'Gasolina B-87'),
  ('gasolina_b90', 'Gasolina B-90'),
  ('gasolina_b94', 'Gasolina B-94'),
  ('gasolina_b100', 'Gasolina B-100'),
  ('diesel', 'Diesel'),
  ('diesel_especial', 'Diesel especial'),
  ('gas_lp', 'Gas licuado'),
  ('otro', 'Otro combustible'),
];

const _currencies = <(String, String)>[
  ('USD', 'USD - Dolar estadounidense'),
  ('EUR', 'EUR - Euro'),
  ('MLC', 'MLC'),
  ('CAD', 'CAD - Dolar canadiense'),
  ('MXN', 'MXN - Peso mexicano'),
  ('GBP', 'GBP - Libra esterlina'),
  ('CHF', 'CHF - Franco suizo'),
  ('CUP', 'CUP - Peso cubano'),
  ('OTRA', 'Otra moneda'),
];
