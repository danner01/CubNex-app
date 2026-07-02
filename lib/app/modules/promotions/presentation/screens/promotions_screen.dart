import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../home/data/models/product_model.dart';
import '../../blocs/promotions/promotions_cubit.dart';
import '../../blocs/promotions/promotions_state.dart';
import '../../data/models/promotion_model.dart';

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PromotionsCubit>()..loadPublic(),
      child: const _PromotionsView(),
    );
  }
}

class _PromotionsView extends StatelessWidget {
  const _PromotionsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<PromotionsCubit, PromotionsState>(
        listener: _listen,
        builder: (context, state) => RefreshIndicator(
          onRefresh: () => context.read<PromotionsCubit>().loadPublic(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                'Promociones',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Ofertas, sorteos y cashback activos.'),
              const SizedBox(height: 16),
              if (state.status == PromotionsStatus.loading)
                const Center(child: CircularProgressIndicator())
              else if (state.items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No hay promociones activas ahora.'),
                  ),
                )
              else
                ...state.items.map((item) => _PromotionCard(item: item)),
            ],
          ),
        ),
      ),
    );
  }

  void _listen(BuildContext context, PromotionsState state) {
    if (state.redemption != null) {
      final redemption = state.redemption!;
      context.read<PromotionsCubit>().clearRedemption();
      showDialog<void>(
        context: context,
        builder: (_) => _RedemptionQrDialog(redemption: redemption),
      );
      return;
    }

    if (state.message != null) {
      showSnackOrAuthDialog(context, state.message);
    }
  }
}

class BusinessPromotionsScreen extends StatelessWidget {
  const BusinessPromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final businessId = context
        .read<ActiveBusinessCubit>()
        .state
        .activeBusiness
        ?.id;
    return BlocProvider(
      create: (_) {
        final cubit = sl<PromotionsCubit>();
        if (businessId == null) {
          cubit.loadMine();
        } else {
          cubit.loadForBusiness(businessId);
        }
        return cubit;
      },
      child: const _BusinessPromotionsView(),
    );
  }
}

class _BusinessPromotionsView extends StatelessWidget {
  const _BusinessPromotionsView();

  @override
  Widget build(BuildContext context) {
    final activeBusiness = context
        .watch<ActiveBusinessCubit>()
        .state
        .activeBusiness;
    final businessId = activeBusiness?.id;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: businessId == null
            ? null
            : () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => BlocProvider.value(
                  value: context.read<PromotionsCubit>(),
                  child: _PromotionFormSheet(businessId: businessId),
                ),
              ),
        icon: const Icon(Icons.add),
        label: const Text('Promocion'),
      ),
      body: BlocListener<ActiveBusinessCubit, ActiveBusinessState>(
        listenWhen: (previous, current) =>
            previous.activeBusiness?.id != current.activeBusiness?.id &&
            current.activeBusiness?.id != null,
        listener: (context, activeState) {
          final nextBusinessId = activeState.activeBusiness?.id;
          if (nextBusinessId != null) {
            context.read<PromotionsCubit>().loadForBusiness(nextBusinessId);
          }
        },
        child: BlocConsumer<PromotionsCubit, PromotionsState>(
          listener: (context, state) {
            if (state.message != null) {
              showSnackOrAuthDialog(context, state.message);
            }
          },
          builder: (context, state) => RefreshIndicator(
            onRefresh: () async {
              if (businessId == null) {
                await context.read<PromotionsCubit>().loadMine();
              } else {
                await context.read<PromotionsCubit>().loadForBusiness(
                  businessId,
                );
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Text(
                  'Mis promociones',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  activeBusiness == null
                      ? 'Selecciona o crea un negocio para crear promociones.'
                      : 'Promociones del negocio activo: ${activeBusiness.name}.',
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: businessId == null
                      ? null
                      : () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => BlocProvider.value(
                            value: context.read<PromotionsCubit>(),
                            child: const _ValidateRedemptionSheet(),
                          ),
                        ),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Escanear canje'),
                ),
                const SizedBox(height: 12),
                if (state.status == PromotionsStatus.loading)
                  const Center(child: CircularProgressIndicator())
                else if (state.status == PromotionsStatus.failure)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        state.message ?? 'No se pudieron cargar promociones.',
                      ),
                    ),
                  )
                else if (state.items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Aun no tienes promociones creadas.'),
                    ),
                  )
                else ...[
                  _PromotionSummary(
                    items: _businessItems(state.items, businessId),
                  ),
                  const SizedBox(height: 12),
                  ..._businessItems(state.items, businessId).map(
                    (item) =>
                        _PromotionCard(item: item, showClientActions: false),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<PromotionModel> _businessItems(
    List<PromotionModel> items,
    String? businessId,
  ) {
    if (businessId == null) return items;
    return items.where((item) => item.businessId == businessId).toList();
  }
}

class _PromotionSummary extends StatelessWidget {
  const _PromotionSummary({required this.items});

  final List<PromotionModel> items;

  @override
  Widget build(BuildContext context) {
    final active = items.where((item) => item.active).length;
    final discounts = items.where((item) => item.type == 'descuento').length;
    final raffles = items.where((item) => item.type == 'sorteo').length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _MiniStat(label: 'Activas', value: active),
            _MiniStat(label: 'Descuentos', value: discounts),
            _MiniStat(label: 'Sorteos', value: raffles),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            '$value',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({required this.item, this.showClientActions = true});

  final PromotionModel item;
  final bool showClientActions;

  @override
  Widget build(BuildContext context) {
    final end = item.endAt == null
        ? 'Sin vencimiento'
        : 'Hasta ${DateFormat('dd/MM/yyyy HH:mm').format(item.endAt!)}';
    final start = item.startAt == null
        ? null
        : 'Desde ${DateFormat('dd/MM/yyyy HH:mm').format(item.startAt!)}';
    final isRaffle = item.type == 'sorteo';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  child: Icon(isRaffle ? Icons.card_giftcard : Icons.sell),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (item.description != null) ...[
              const SizedBox(height: 10),
              Text(item.description!),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(item.type)),
                if (item.percent != null) Chip(label: Text('${item.percent}%')),
                if (item.value != null) Chip(label: Text('\$${item.value}')),
                if (start != null) Chip(label: Text(start)),
                Chip(label: Text(end)),
              ],
            ),
            if (showClientActions) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (item.code != null)
                    Expanded(
                      child: SelectableText(
                        'Codigo: ${item.code}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    )
                  else
                    const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => isRaffle
                        ? context.read<PromotionsCubit>().participate(item.id)
                        : context.read<PromotionsCubit>().redeem(
                            item.id,
                            code: item.code,
                          ),
                    icon: Icon(
                      isRaffle ? Icons.how_to_reg : Icons.qr_code_2_rounded,
                    ),
                    label: Text(isRaffle ? 'Participar' : 'Generar QR'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PromotionFormSheet extends StatefulWidget {
  const _PromotionFormSheet({required this.businessId});

  final String businessId;

  @override
  State<_PromotionFormSheet> createState() => _PromotionFormSheetState();
}

class _PromotionFormSheetState extends State<_PromotionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _codeController = TextEditingController();
  final _percentController = TextEditingController();
  String _type = 'descuento';
  String? _productId;
  DateTime _startAt = DateTime.now();
  late DateTime _endAt;
  late final Future<List<ProductModel>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _endAt = _startAt.add(const Duration(days: 30));
    _productsFuture = _loadProducts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _codeController.dispose();
    _percentController.dispose();
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
                  'Nueva promocion',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'descuento',
                      child: Text('Descuento'),
                    ),
                    DropdownMenuItem(value: 'sorteo', child: Text('Sorteo')),
                    DropdownMenuItem(
                      value: 'cashback',
                      child: Text('Cashback'),
                    ),
                    DropdownMenuItem(value: '2x1', child: Text('2x1')),
                    DropdownMenuItem(value: 'regalo', child: Text('Regalo')),
                  ],
                  onChanged: (value) =>
                      setState(() => _type = value ?? 'descuento'),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<ProductModel>>(
                  future: _productsFuture,
                  builder: (context, snapshot) {
                    final products = snapshot.data ?? const <ProductModel>[];
                    return DropdownButtonFormField<String>(
                      initialValue: _productId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Producto del inventario',
                        helperText: 'Opcional: aplica la promo a un producto.',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Todos los productos visibles'),
                        ),
                        ...products.map(
                          (product) => DropdownMenuItem<String>(
                            value: product.id,
                            child: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(
                        () => _productId = value == null || value.isEmpty
                            ? null
                            : value,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Titulo'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe titulo'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripcion'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Codigo opcional',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _percentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Porcentaje opcional',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DateTimeTile(
                        label: 'Inicio',
                        value: _startAt,
                        onTap: () async {
                          final picked = await _pickDateTime(context, _startAt);
                          if (picked == null) return;
                          setState(() {
                            _startAt = picked;
                            if (!_endAt.isAfter(_startAt)) {
                              _endAt = _startAt.add(const Duration(days: 1));
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateTimeTile(
                        label: 'Finaliza',
                        value: _endAt,
                        onTap: () async {
                          final picked = await _pickDateTime(context, _endAt);
                          if (picked == null) return;
                          setState(() => _endAt = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Crear'),
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
    if (!_endAt.isAfter(_startAt)) {
      showSnackOrAuthDialog(
        context,
        'La fecha final debe ser posterior al inicio.',
      );
      return;
    }
    context.read<PromotionsCubit>().create(
      title: _titleController.text.trim(),
      type: _type,
      startAt: _startAt,
      endAt: _endAt,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      code: _codeController.text.trim().isEmpty
          ? null
          : _codeController.text.trim(),
      percent: int.tryParse(_percentController.text.trim()),
      productIds: _productId == null ? const [] : [_productId!],
    );
    Navigator.of(context).pop();
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<List<ProductModel>> _loadProducts() async {
    final result = await sl<ApiClient>().get<List<ProductModel>>(
      '/negocios/${widget.businessId}/productos',
      queryParameters: const {'limit': 80, 'order': 'created_at.desc'},
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map>()
              .map(
                (item) =>
                    ProductModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.inInventory && item.available)
              .toList();
        }
        return const [];
      },
    );
    return result.data ?? const [];
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(DateFormat('dd/MM/yyyy HH:mm').format(value)),
      ),
    );
  }
}

class _RedemptionQrDialog extends StatelessWidget {
  const _RedemptionQrDialog({required this.redemption});

  final PromotionRedemption redemption;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataUrlBytes(redemption.qrUrl);
    return AlertDialog(
      title: Text(redemption.title ?? 'QR de promocion'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bytes != null)
            Image.memory(bytes, width: 220, height: 220)
          else
            const Icon(Icons.qr_code_2_rounded, size: 120),
          const SizedBox(height: 12),
          const Text(
            'Muestra este QR al negocio para aplicar la promocion. Cuando sea escaneado, quedara consumido.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          SelectableText(
            redemption.token,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (redemption.expiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Vence: ${DateFormat('dd/MM/yyyy HH:mm').format(redemption.expiresAt!)}',
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Uint8List? _dataUrlBytes(String? value) {
    if (value == null || !value.startsWith('data:image')) return null;
    final comma = value.indexOf(',');
    if (comma == -1) return null;
    return base64Decode(value.substring(comma + 1));
  }
}

class _ValidateRedemptionSheet extends StatefulWidget {
  const _ValidateRedemptionSheet();

  @override
  State<_ValidateRedemptionSheet> createState() =>
      _ValidateRedemptionSheetState();
}

class _ValidateRedemptionSheetState extends State<_ValidateRedemptionSheet> {
  bool _locked = false;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        child: SizedBox(
          height: 460,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Escanear promocion',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escanea el QR del cliente para validar descuento, fecha y estado.',
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: MobileScanner(
                    onDetect: _locked
                        ? null
                        : (capture) {
                            final token = capture.barcodes.isEmpty
                                ? null
                                : capture.barcodes.first.rawValue;
                            if (token == null || token.trim().isEmpty) return;
                            setState(() => _locked = true);
                            context.read<PromotionsCubit>().validateRedemption(
                              token.trim(),
                            );
                            Navigator.of(context).pop();
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
