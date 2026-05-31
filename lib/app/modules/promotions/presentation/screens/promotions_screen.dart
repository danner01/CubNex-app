import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
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
    if (state.message != null) {
      showSnackOrAuthDialog(context, state.message);
    }
  }
}

class BusinessPromotionsScreen extends StatelessWidget {
  const BusinessPromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PromotionsCubit>()..loadMine(),
      child: const _BusinessPromotionsView(),
    );
  }
}

class _BusinessPromotionsView extends StatelessWidget {
  const _BusinessPromotionsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => BlocProvider.value(
            value: context.read<PromotionsCubit>(),
            child: const _PromotionFormSheet(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Promocion'),
      ),
      body: BlocConsumer<PromotionsCubit, PromotionsState>(
        listener: (context, state) {
          if (state.message != null) {
            showSnackOrAuthDialog(context, state.message);
          }
        },
        builder: (context, state) => RefreshIndicator(
          onRefresh: () => context.read<PromotionsCubit>().loadMine(),
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
              const Text('Crea descuentos, sorteos y cashback para clientes.'),
              const SizedBox(height: 16),
              if (state.status == PromotionsStatus.loading)
                const Center(child: CircularProgressIndicator())
              else if (state.items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Aun no tienes promociones creadas.'),
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
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({required this.item});

  final PromotionModel item;

  @override
  Widget build(BuildContext context) {
    final end = item.endAt == null
        ? 'Sin vencimiento'
        : 'Hasta ${DateFormat('dd/MM/yyyy').format(item.endAt!)}';
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
                Chip(label: Text(end)),
              ],
            ),
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
                      : context
                            .read<PromotionsCubit>()
                            .redeem(item.id, code: item.code),
                  icon: Icon(isRaffle ? Icons.how_to_reg : Icons.redeem),
                  label: Text(isRaffle ? 'Participar' : 'Canjear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PromotionFormSheet extends StatefulWidget {
  const _PromotionFormSheet();

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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'descuento', child: Text('Descuento')),
                    DropdownMenuItem(value: 'sorteo', child: Text('Sorteo')),
                    DropdownMenuItem(value: 'cashback', child: Text('Cashback')),
                    DropdownMenuItem(value: '2x1', child: Text('2x1')),
                    DropdownMenuItem(value: 'regalo', child: Text('Regalo')),
                  ],
                  onChanged: (value) => setState(() => _type = value ?? 'descuento'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Titulo'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Escribe titulo' : null,
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
                  decoration: const InputDecoration(labelText: 'Codigo opcional'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _percentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Porcentaje opcional'),
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
    context.read<PromotionsCubit>().create(
      title: _titleController.text.trim(),
      type: _type,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      code: _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
      percent: int.tryParse(_percentController.text.trim()),
    );
    Navigator.of(context).pop();
  }
}
