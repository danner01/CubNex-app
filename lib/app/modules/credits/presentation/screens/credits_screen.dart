import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/injection/injection.dart';
import '../../blocs/credits_cubit.dart';
import '../../blocs/credits_state.dart';
import '../../data/models/credit_movement.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CreditsCubit>()..load(),
      child: const _CreditsView(),
    );
  }
}

class _CreditsView extends StatelessWidget {
  const _CreditsView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreditsCubit, CreditsState>(
      listener: (context, state) {
        if (state.message != null && state.message!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      builder: (context, state) {
        final summary = state.summary;
        final movements = state.movements;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Créditos'),
          ),
          body: RefreshIndicator(
            onRefresh: () => context.read<CreditsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                const Text(
                  'Saldo de créditos, recargas, transferencias y historial.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                if (state.status == CreditStatus.loading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tu saldo actual',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            summary == null
                                ? 'Cargando...'
                                : '${summary.balance} CUP',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricTile(
                                  label: 'Disponibles',
                                  value: summary == null
                                      ? '—'
                                      : '${summary.availableBalance} CUP',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricTile(
                                  label: 'Ganados',
                                  value: summary == null
                                      ? '—'
                                      : '${summary.totalEarned} CUP',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '1 grano = 1 CUP. Haz transferencias, recargas y solicita retiros al superadmin si hay fondos disponibles.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _showTransferSheet(context),
                        icon: const Icon(Icons.send_to_mobile_rounded),
                        label: const Text('Transferir créditos'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showRechargeSheet(context),
                        icon: const Icon(Icons.account_balance_wallet_rounded),
                        label: const Text('Recargar créditos'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showSellSheet(context),
                        icon: const Icon(Icons.sell_rounded),
                        label: const Text('Retirar granos'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Movimientos recientes',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  if (movements.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('Aún no hay movimientos de crédito.'),
                      ),
                    )
                  else
                    ...movements.map((movement) => _CreditMovementTile(movement: movement)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTransferSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TransferCreditsSheet(),
    );
  }

  Future<void> _showRechargeSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RechargeCreditsSheet(),
    );
  }

  Future<void> _showSellSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SellCreditsSheet(),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _CreditMovementTile extends StatelessWidget {
  const _CreditMovementTile({required this.movement});

  final CreditMovement movement;

  @override
  Widget build(BuildContext context) {
    final title = movement.description?.isNotEmpty == true
        ? movement.description!
        : movement.type.replaceAll('_', ' ').toUpperCase();
    final date = movement.createdAt == null
        ? 'Sin fecha'
        : '${movement.createdAt!.day.toString().padLeft(2, '0')}/${movement.createdAt!.month.toString().padLeft(2, '0')}/${movement.createdAt!.year} ${movement.createdAt!.hour.toString().padLeft(2, '0')}:${movement.createdAt!.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title),
        subtitle: Text(date),
        trailing: Text(
          '${movement.amount > 0 ? '+' : ''}${movement.amount} CUP',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: movement.amount < 0 ? Colors.redAccent : Colors.green,
          ),
        ),
      ),
    );
  }
}

class _TransferCreditsSheet extends StatefulWidget {
  const _TransferCreditsSheet();

  @override
  State<_TransferCreditsSheet> createState() => _TransferCreditsSheetState();
}

class _TransferCreditsSheetState extends State<_TransferCreditsSheet> {
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transferir créditos',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo electrónico destinatario'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad de créditos'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : () async {
              final email = _emailController.text.trim();
              final amount = int.tryParse(_amountController.text.trim()) ?? 0;
              if (email.isEmpty || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa un correo válido y una cantidad mayor que cero.')),
                );
                return;
              }
              setState(() => _submitting = true);
              await context.read<CreditsCubit>().transferCredits(
                    recipientEmail: email,
                    amount: amount,
                  );
              setState(() => _submitting = false);
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_to_mobile_rounded),
            label: const Text('Enviar transferencia'),
          ),
        ],
      ),
    );
  }
}

class _RechargeCreditsSheet extends StatefulWidget {
  const _RechargeCreditsSheet();

  @override
  State<_RechargeCreditsSheet> createState() => _RechargeCreditsSheetState();
}

class _RechargeCreditsSheetState extends State<_RechargeCreditsSheet> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  String _method = 'Cuenta';
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recargar créditos',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Método de recarga'),
            items: const [
              DropdownMenuItem(value: 'Cuenta', child: Text('Cuenta bancaria / CUP')),
              DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta en CUB')),
            ],
            onChanged: (value) => setState(() => _method = value ?? 'Cuenta'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad en CUP'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _referenceController,
            decoration: const InputDecoration(
              labelText: 'Cuenta / Tarjeta / Referencia',
              hintText: 'Número de cuenta o tarjeta',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : () async {
              final amount = int.tryParse(_amountController.text.trim()) ?? 0;
              final reference = _referenceController.text.trim();
              if (amount <= 0 || reference.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Completa monto y referencia de recarga.')),
                );
                return;
              }
              setState(() => _submitting = true);
              await context.read<CreditsCubit>().requestRecharge(
                    amount: amount,
                    method: _method,
                    reference: reference,
                  );
              setState(() => _submitting = false);
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.account_balance_wallet_rounded),
            label: const Text('Solicitar recarga'),
          ),
        ],
      ),
    );
  }
}

class _SellCreditsSheet extends StatefulWidget {
  const _SellCreditsSheet();

  @override
  State<_SellCreditsSheet> createState() => _SellCreditsSheetState();
}

class _SellCreditsSheetState extends State<_SellCreditsSheet> {
  final _amountController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Retirar granos',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad de granos'),
          ),
          const SizedBox(height: 12),
          Text(
            'Envía una solicitud para retirar o vender granos al superadmin si tiene fondos disponibles.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : () async {
              final amount = int.tryParse(_amountController.text.trim()) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa una cantidad mayor que cero.')),
                );
                return;
              }
              setState(() => _submitting = true);
              await context.read<CreditsCubit>().sellCredits(amount: amount);
              setState(() => _submitting = false);
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sell_rounded),
            label: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );
  }
}
