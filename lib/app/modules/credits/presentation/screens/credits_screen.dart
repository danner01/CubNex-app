import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/injection/injection.dart';
import '../../blocs/credits_cubit.dart';
import '../../blocs/credits_state.dart';
import '../../data/models/credit_movement.dart';
import '../../data/models/credit_summary.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({
    super.key,
    this.initialAlias,
    this.initialUserId,
    this.initialQrPayload,
  });

  final String? initialAlias;
  final String? initialUserId;
  final String? initialQrPayload;

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  @override
  void initState() {
    super.initState();
    final cubit = sl<CreditsCubit>();
    cubit.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hasPrefill = (widget.initialAlias?.isNotEmpty ?? false) ||
          (widget.initialUserId?.isNotEmpty ?? false) ||
          (widget.initialQrPayload?.isNotEmpty ?? false);
      if (hasPrefill) {
        _showTransferSheet(
          context,
          initialAlias: widget.initialAlias,
          initialUserId: widget.initialUserId,
          initialQrPayload: widget.initialQrPayload,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<CreditsCubit>(),
      child: _CreditsView(
        onTransfer: () => _showTransferSheet(context),
        onRecharge: () => _showRechargeSheet(context),
        onSell: () => _showSellSheet(context),
        onReceive: () => _showReceiveSheet(context),
        onScanPay: () => _scanAndPay(context),
        onConvertGrains: () => _showConvertGrainsSheet(context),
      ),
    );
  }

  Future<void> _showTransferSheet(
    BuildContext context, {
    String? initialAlias,
    String? initialUserId,
    String? initialQrPayload,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: sl<CreditsCubit>(),
        child: _TransferWalletSheet(
          initialAlias: initialAlias,
          initialUserId: initialUserId,
          initialQrPayload: initialQrPayload,
        ),
      ),
    );
  }

  Future<void> _showReceiveSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: sl<CreditsCubit>(),
        child: const _ReceiveWalletSheet(),
      ),
    );
  }

  Future<void> _showRechargeSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: sl<CreditsCubit>(),
        child: const _RechargeCreditsSheet(),
      ),
    );
  }

  Future<void> _showSellSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: sl<CreditsCubit>(),
        child: const _SellCreditsSheet(),
      ),
    );
  }

  Future<void> _showConvertGrainsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: sl<CreditsCubit>(),
        child: const _ConvertGrainsSheet(),
      ),
    );
  }

  Future<void> _scanAndPay(BuildContext context) async {
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _WalletQrScanPage()),
    );
    if (!mounted || payload == null || payload.isEmpty) return;
    final parsed = parseWalletQrPayload(payload);
        if (!mounted) return;
        await _showTransferSheet(
          this.context,
          initialAlias: parsed.alias,
          initialUserId: parsed.userId,
          initialQrPayload: payload,
        );
      }
    }

class WalletQrParts {
  const WalletQrParts({this.userId, this.alias});
  final String? userId;
  final String? alias;
}

WalletQrParts parseWalletQrPayload(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return const WalletQrParts();
  final uri = Uri.tryParse(value);
  if (uri != null &&
      (uri.scheme == 'conkkao' ||
          uri.host.contains('wallet') ||
          value.toLowerCase().contains('wallet/pay'))) {
    return WalletQrParts(
      userId: uri.queryParameters['uid'] ??
          uri.queryParameters['user_id'] ??
          uri.queryParameters['usuario_id'],
      alias: uri.queryParameters['alias'] ??
          uri.queryParameters['email'] ??
          uri.queryParameters['telefono'],
    );
  }
  final uidMatch = RegExp(
    r'(?:uid|user_id|usuario_id)=([0-9a-fA-F-]{36})',
    caseSensitive: false,
  ).firstMatch(value);
  final aliasMatch = RegExp(
    r'(?:alias|email|telefono)=([^&\s]+)',
    caseSensitive: false,
  ).firstMatch(value);
  return WalletQrParts(
    userId: uidMatch?.group(1),
    alias: aliasMatch != null
        ? Uri.decodeComponent(aliasMatch.group(1)!)
        : null,
  );
}

bool isWalletQrPayload(String raw) {
  final lower = raw.trim().toLowerCase();
  if (lower.isEmpty) return false;
  if (lower.startsWith('conkkao://wallet')) return true;
  if (lower.contains('wallet/pay')) return true;
  if (lower.contains('uid=') &&
      (lower.contains('alias=') || lower.contains('conkkao'))) {
    return true;
  }
  return false;
}

class _CreditsView extends StatelessWidget {
  const _CreditsView({
    required this.onTransfer,
    required this.onRecharge,
    required this.onSell,
    required this.onReceive,
    required this.onScanPay,
    required this.onConvertGrains,
  });

  final VoidCallback onTransfer;
  final VoidCallback onRecharge;
  final VoidCallback onSell;
  final VoidCallback onReceive;
  final VoidCallback onScanPay;
  final VoidCallback onConvertGrains;

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
            title: const Text('Billetera'),
            actions: [
              IconButton(
                tooltip: 'Recibir',
                onPressed: onReceive,
                icon: const Icon(Icons.qr_code_2_rounded),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => context.read<CreditsCubit>().load(force: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  'Saldo ConKkao, transferencias por alias o QR, recargas y movimientos.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                if (state.status == CreditStatus.loading && summary == null)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.monetization_on_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Tu billetera',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            summary == null
                                ? 'Cargando...'
                                : '${summary.grains}',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            summary == null
                                ? ''
                                : 'granos totales (saldo)',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (summary?.alias != null &&
                              summary!.alias!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Alias: ${summary.alias}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricTile(
                                  label: 'Ganados',
                                  value: summary == null
                                      ? '—'
                                      : '${summary.ganados}',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricTile(
                                  label: 'Recargados',
                                  value: summary == null
                                      ? '—'
                                      : '${summary.recargados}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricTile(
                                  label: 'Depositados',
                                  value: summary == null
                                      ? '—'
                                      : '${summary.depositados}',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricTile(
                                  label: 'Transferidos',
                                  value: summary == null
                                      ? '—'
                                      : '${summary.transferidos}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '1 grano = 1 CUP. El saldo suma lo ganado, recargado y depositado; se resta con retiros y transferencias.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _WalletStatsCard(summary: summary),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: onTransfer,
                        icon: const Icon(Icons.send_to_mobile_rounded),
                        label: const Text('Transferir'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onScanPay,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Pagar con QR'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onReceive,
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('Mi QR'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onRecharge,
                        icon: const Icon(Icons.account_balance_wallet_rounded),
                        label: const Text('Recargar'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onSell,
                        icon: const Icon(Icons.sell_rounded),
                        label: const Text('Retirar granos'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onConvertGrains,
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Convertir granos'),
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
                        child: Text('Aún no hay movimientos en la billetera.'),
                      ),
                    )
                  else
                    ...movements.map(
                      (movement) => _CreditMovementTile(movement: movement),
                    ),
                ],
              ],
            ),
          ),
        );
      },
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
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _WalletStatsCard extends StatelessWidget {
  const _WalletStatsCard({this.summary});

  final CreditSummary? summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = <({String label, int value, Color color})>[
      (label: 'Ganados', value: summary?.ganados ?? 0, color: colors.primary),
      (
        label: 'Recargados',
        value: summary?.recargados ?? 0,
        color: Colors.green,
      ),
      (
        label: 'Depositados',
        value: summary?.depositados ?? 0,
        color: Colors.teal,
      ),
      (
        label: 'Transferidos',
        value: summary?.transferidos ?? 0,
        color: Colors.orange,
      ),
      (
        label: 'Retirados',
        value: summary?.retirados ?? 0,
        color: Colors.redAccent,
      ),
      (
        label: 'Gastados',
        value: summary?.gastados ?? 0,
        color: Colors.blueGrey,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, color: colors.primary, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Estadísticas',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ScatterChart(entries: entries, total: summary?.grains ?? 0),
            const SizedBox(height: 16),
            ...entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: e.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(e.label),
                    const Spacer(),
                    Text(
                      '${e.value}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Text(
                  'Total (saldo)',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  '${summary?.grains ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Saldo = Ganados + Recargados + Depositados − Transferidos − Retirados − Gastados.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScatterChart extends StatelessWidget {
  const _ScatterChart({required this.entries, required this.total});

  final List<({String label, int value, Color color})> entries;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          width: double.infinity,
          child: CustomPaint(
            painter: _ScatterChartPainter(
              entries: entries,
              theme: Theme.of(context).colorScheme,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Gráfica de puntos por categoría',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ScatterChartPainter extends CustomPainter {
  _ScatterChartPainter({required this.entries, required this.theme});

  final List<({String label, int value, Color color})> entries;
  final ColorScheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = entries.fold<int>(
      1,
      (acc, e) => e.value > acc ? e.value : acc,
    );
    final leftPad = 34.0;
    final rightPad = 14.0;
    final topPad = 12.0;
    final bottomPad = 22.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    // axis labels (min/Max)
    final labelStyle = TextStyle(
      color: theme.onSurfaceVariant,
      fontSize: 10,
    );
    final tp = TextPainter(
      text: TextSpan(text: '$maxValue', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(leftPad - tp.width - 4, topPad - 4));

    final tp0 = TextPainter(
      text: const TextSpan(text: '0', style: TextStyle(fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp0.paint(
      canvas,
      Offset(leftPad - tp0.width - 4, topPad + chartHeight - 10),
    );

    // grid guides
    final guidePaint = Paint()
      ..color = theme.outlineVariant.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y =
          topPad + chartHeight - (chartHeight * (i / 3));
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + chartWidth, y),
        guidePaint,
      );
    }

    if (entries.isEmpty) return;

    final stepX = chartWidth / (entries.length - 1);
    final points = <Offset>[];
    for (int i = 0; i < entries.length; i++) {
      final v = entries[i].value.toDouble();
      final x = leftPad + stepX * i;
      final y = topPad + chartHeight - (v / maxValue) * chartHeight;
      points.add(Offset(x, y));
    }

    // lines between points
    final linePaint = Paint()
      ..color = theme.primary.withValues(alpha: 0.5)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    // points
    for (int i = 0; i < entries.length; i++) {
      final p = points[i];
      final color = entries[i].color;
      final halo = Paint()..color = color.withValues(alpha: 0.25);
      canvas.drawCircle(p, 8, halo);
      final dot = Paint()..color = color;
      canvas.drawCircle(p, 4.5, dot);

      final tpLabel = TextPainter(
        text: TextSpan(
          text: entries[i].label,
          style: TextStyle(fontSize: 9, color: theme.onSurfaceVariant),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelX = (p.dx - tpLabel.width / 2)
          .clamp(leftPad, leftPad + chartWidth - tpLabel.width);
      tpLabel.paint(canvas, Offset(labelX, topPad + chartHeight + 3));
    }
  }

  @override
  bool shouldRepaint(covariant _ScatterChartPainter oldDelegate) {
    return oldDelegate.entries != entries || oldDelegate.theme != theme;
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
        : '${movement.createdAt!.day.toString().padLeft(2, '0')}/'
            '${movement.createdAt!.month.toString().padLeft(2, '0')}/'
            '${movement.createdAt!.year} '
            '${movement.createdAt!.hour.toString().padLeft(2, '0')}:'
            '${movement.createdAt!.minute.toString().padLeft(2, '0')}';

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

class _ReceiveWalletSheet extends StatelessWidget {
  const _ReceiveWalletSheet();

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<CreditsCubit>().state.summary;
    final qr = summary?.qrPayload;
    final alias = summary?.alias ?? '—';
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Recibir en billetera',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text('Alias: $alias'),
          const SizedBox(height: 16),
          if (qr == null || qr.isEmpty)
            const Text('No se pudo generar tu QR de billetera.')
          else ...[
            QrImageView(
              data: qr,
              size: 220,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            SelectableText(
              qr,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: qr));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('QR copiado.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copiar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Share.share(
                      'Págame en ConKkao con este QR/alias ($alias):\n$qr',
                    ),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Compartir'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TransferWalletSheet extends StatefulWidget {
  const _TransferWalletSheet({
    this.initialAlias,
    this.initialUserId,
    this.initialQrPayload,
  });

  final String? initialAlias;
  final String? initialUserId;
  final String? initialQrPayload;

  @override
  State<_TransferWalletSheet> createState() => _TransferWalletSheetState();
}

class _TransferWalletSheetState extends State<_TransferWalletSheet> {
  late final TextEditingController _destinationController;
  final _amountController = TextEditingController();
  final _conceptController = TextEditingController();
  String? _userId;
  String? _qrPayload;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _destinationController =
        TextEditingController(text: widget.initialAlias ?? '');
    _userId = widget.initialUserId;
    _qrPayload = widget.initialQrPayload;
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _amountController.dispose();
    _conceptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final hasQr = _qrPayload != null && _qrPayload!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transferir desde billetera',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (hasQr)
            Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code_rounded),
                title: const Text('Destino por QR'),
                subtitle: Text(
                  _userId?.isNotEmpty == true
                      ? 'Usuario: ${_userId!.substring(0, 8)}…'
                      : (_destinationController.text.isNotEmpty
                          ? _destinationController.text
                          : 'QR de billetera detectado'),
                ),
                trailing: IconButton(
                  tooltip: 'Quitar QR',
                  onPressed: () => setState(() {
                    _qrPayload = null;
                    _userId = null;
                  }),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            )
          else
            TextField(
              controller: _destinationController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Alias, email o teléfono',
                hintText: 'usuario@correo.com / +53…',
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Monto (CUP)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _conceptController,
            decoration: const InputDecoration(
              labelText: 'Concepto (opcional)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting
                ? null
                : () async {
                    final amount =
                        int.tryParse(_amountController.text.trim()) ?? 0;
                    setState(() => _submitting = true);
                    await context.read<CreditsCubit>().transferWallet(
                          amount: amount,
                          destination: _destinationController.text.trim(),
                          destinationUserId: _userId,
                          qrPayload: _qrPayload,
                          concept: _conceptController.text.trim(),
                        );
                    setState(() => _submitting = false);
                    if (context.mounted) Navigator.of(context).pop();
                  },
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_to_mobile_rounded),
            label: const Text('Enviar transferencia'),
          ),
        ],
      ),
    );
  }
}

class _WalletQrScanPage extends StatefulWidget {
  const _WalletQrScanPage();

  @override
  State<_WalletQrScanPage> createState() => _WalletQrScanPageState();
}

class _WalletQrScanPageState extends State<_WalletQrScanPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR de billetera')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              final value = capture.barcodes.isEmpty
                  ? null
                  : capture.barcodes.first.rawValue;
              if (value == null || value.trim().isEmpty) return;
              if (!isWalletQrPayload(value) &&
                  !value.contains('uid=') &&
                  Uri.tryParse(value)?.queryParameters['uid'] == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ese QR no parece de billetera ConKkao.'),
                  ),
                );
                return;
              }
              _handled = true;
              Navigator.of(context).pop(value.trim());
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Apunta al QR de billetera del destinatario',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black),
                      ],
                    ),
              ),
            ),
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
            'Recargar billetera',
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
              DropdownMenuItem(
                value: 'Cuenta',
                child: Text('Cuenta bancaria / CUP'),
              ),
              DropdownMenuItem(
                value: 'Tarjeta',
                child: Text('Tarjeta en CUB'),
              ),
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
            onPressed: _submitting
                ? null
                : () async {
                    final amount =
                        int.tryParse(_amountController.text.trim()) ?? 0;
                    final reference = _referenceController.text.trim();
                    if (amount <= 0 || reference.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Completa monto y referencia de recarga.'),
                        ),
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
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
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
            onPressed: _submitting
                ? null
                : () async {
                    final amount =
                        int.tryParse(_amountController.text.trim()) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ingresa una cantidad mayor que cero.'),
                        ),
                      );
                      return;
                    }
                    setState(() => _submitting = true);
                    await context
                        .read<CreditsCubit>()
                        .sellCredits(amount: amount);
                    setState(() => _submitting = false);
                    if (context.mounted) Navigator.of(context).pop();
                  },
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sell_rounded),
            label: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );
  }
}

class _ConvertGrainsSheet extends StatefulWidget {
  const _ConvertGrainsSheet();

  @override
  State<_ConvertGrainsSheet> createState() => _ConvertGrainsSheetState();
}

class _ConvertGrainsSheetState extends State<_ConvertGrainsSheet> {
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
            'Convertir granos a creditos',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cantidad de granos a convertir',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tus granos acumulados se convertiran en creditos disponibles en tu billetera. Se aplicara una comision segun la configuracion del sistema.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting
                ? null
                : () async {
                    final amount =
                        int.tryParse(_amountController.text.trim()) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ingresa una cantidad mayor que cero.'),
                        ),
                      );
                      return;
                    }
                    setState(() => _submitting = true);
                    await context
                        .read<CreditsCubit>()
                        .convertGrains(grains: amount);
                    setState(() => _submitting = false);
                    if (context.mounted) Navigator.of(context).pop();
                  },
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.swap_horiz_rounded),
            label: const Text('Convertir'),
          ),
        ],
      ),
    );
  }
}
