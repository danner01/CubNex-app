import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/injection/injection.dart';
import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/blocs/role_mode/role_mode_cubit.dart';
import '../../../business/presentation/widgets/business_switcher.dart';
import '../../blocs/credits_cubit.dart';
import '../../blocs/credits_state.dart';
import '../../data/models/credit_movement.dart';
import '../../data/models/credit_summary.dart';
import '../../data/models/verified_topup.dart';
import '../widgets/wallet_chart.dart';

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

class _CreditsScreenState extends State<CreditsScreen>
    with WidgetsBindingObserver {
  String? _loadedNegocioId;
  bool _loadingModeDone = false;
  Timer? _refreshTimer;

  String? get _targetNegocioId {
    final roleMode = context.watch<RoleModeCubit>().state.activeMode;
    if (roleMode != RoleMode.business) return null;
    final active = context.watch<ActiveBusinessCubit>().state.activeBusiness;
    return active?.id;
  }

  String? get _targetNegocioIdRead {
    final roleMode = context.read<RoleModeCubit>().state.activeMode;
    if (roleMode != RoleMode.business) return null;
    final active = context.read<ActiveBusinessCubit>().state.activeBusiness;
    return active?.id;
  }

  bool _isBusinessWallet() {
    final roleMode = context.watch<RoleModeCubit>().state.activeMode;
    if (roleMode != RoleMode.business) return false;
    final active = context.watch<ActiveBusinessCubit>().state.activeBusiness;
    return active != null && (active.id.isNotEmpty);
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshIfVisible(),
    );
  }

  void _refreshIfVisible() {
    if (!mounted) return;
    final observer = WidgetsBinding.instance;
    final appIsVisible = observer.lifecycleState == AppLifecycleState.resumed;
    if (!appIsVisible) return;
    sl<CreditsCubit>().load(force: true, negocioId: _targetNegocioIdRead);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPeriodicRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hasPrefill =
          (widget.initialAlias?.isNotEmpty ?? false) ||
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
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshIfVisible();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBusiness = context
        .watch<ActiveBusinessCubit>()
        .state
        .activeBusiness;
    final isBusiness = _isBusinessWallet();
    final target = _targetNegocioId;
    if (!_loadingModeDone) {
      _loadingModeDone = true;
      _loadedNegocioId = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) sl<CreditsCubit>().load(negocioId: target);
      });
    } else if (target != _loadedNegocioId) {
      _loadedNegocioId = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) sl<CreditsCubit>().load(force: true, negocioId: target);
      });
    }
    return BlocProvider.value(
      value: sl<CreditsCubit>(),
      child: _CreditsView(
        isBusiness: isBusiness,
        businessName: activeBusiness?.name,
        walletScope: target == null ? 'personal' : 'business:$target',
        onTransfer: () => _showTransferSheet(context),
        onRecharge: () => _showRechargeSheet(context),
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
    final negocioId = _currentNegocioId(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: sl<CreditsCubit>(),
        child: _TransferWalletSheet(
          initialAlias: initialAlias,
          initialUserId: initialUserId,
          initialQrPayload: initialQrPayload,
          sourceNegocioId: negocioId,
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
    final negocioId = _currentNegocioId(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: sl<CreditsCubit>(),
        child: _RechargeCreditsSheet(sourceNegocioId: negocioId),
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

String? _currentNegocioId(BuildContext context) {
  final roleMode = context.read<RoleModeCubit>().state.activeMode;
  if (roleMode != RoleMode.business) return null;
  final active = context.read<ActiveBusinessCubit>().state.activeBusiness;
  return active?.id;
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
      userId:
          uri.queryParameters['uid'] ??
          uri.queryParameters['user_id'] ??
          uri.queryParameters['usuario_id'],
      alias:
          uri.queryParameters['alias'] ??
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
    required this.isBusiness,
    this.businessName,
    required this.walletScope,
    required this.onTransfer,
    required this.onRecharge,
    required this.onReceive,
    required this.onScanPay,
    required this.onConvertGrains,
  });

  final bool isBusiness;
  final String? businessName;
  final String walletScope;
  final VoidCallback onTransfer;
  final VoidCallback onRecharge;
  final VoidCallback onReceive;
  final VoidCallback onScanPay;
  final VoidCallback onConvertGrains;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreditsCubit, CreditsState>(
      listener: (context, state) {
        if (state.message != null && state.message!.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message!)));
        }
      },
      builder: (context, state) {
        final isCurrentWallet = state.walletScope == walletScope;
        final summary = isCurrentWallet ? state.summary : null;
        final movements = isCurrentWallet
            ? state.movements
            : const <CreditMovement>[];
        final topupRequests = isCurrentWallet
            ? state.topupRequests
            : const <VerifiedTopupRequest>[];

        return Scaffold(
          appBar: AppBar(
            title: Text(isBusiness ? 'Billetera del negocio' : 'Billetera'),
            actions: [
              IconButton(
                tooltip: 'Recibir',
                onPressed: onReceive,
                icon: const Icon(Icons.qr_code_2_rounded),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => context.read<CreditsCubit>().load(
              force: true,
              negocioId: isBusiness ? _currentNegocioId(context) : null,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  isBusiness
                      ? 'Saldo de granos del negocio, movimientos y ventas recibidas.'
                      : 'Saldo ConKkao, transferencias por alias o QR, recargas y movimientos.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                if (isBusiness) ...[
                  BusinessSwitcher(
                    onChanged: () => context.read<CreditsCubit>().load(
                      force: true,
                      negocioId: _currentNegocioId(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                              Text(
                                isBusiness
                                    ? (businessName == null ||
                                              businessName!.isEmpty
                                          ? 'Billetera del negocio'
                                          : businessName!)
                                    : 'Tu billetera',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            summary == null
                                ? 'Cargando...'
                                : '${summary.grains}',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            summary == null ? '' : 'granos totales (saldo)',
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
                          Row(
                            children: [
                              _CircularActionButton(
                                icon: Icons.add_card_rounded,
                                label: 'Recargar',
                                onTap: onRecharge,
                              ),
                              const Spacer(),
                              _CircularActionButton(
                                icon: Icons.send_rounded,
                                label: 'Enviar',
                                onTap: onTransfer,
                              ),
                              const Spacer(),
                              _CircularActionButton(
                                icon: Icons.qr_code_2_rounded,
                                label: 'QR',
                                onTap: onReceive,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isBusiness
                                ? 'Granos de la billetera del negocio. 1 grano = 1 CUP. Se suman las ventas y recargas; se restan conversiones y transferencias.'
                                : '1 grano = 1 CUP. El saldo suma lo ganado, recargado y depositado; se resta con transferencias.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _WalletStatsCard(summary: summary, movements: movements),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: onConvertGrains,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Convertir granos'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (topupRequests.isNotEmpty) ...[
                    const Text(
                      'Solicitudes de recarga',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...topupRequests.map(
                      (request) => _VerifiedTopupRequestTile(
                        request: request,
                        isBusinessWallet: isBusiness,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
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

class _CircularActionButton extends StatelessWidget {
  const _CircularActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colors.onPrimaryContainer, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _WalletStatsCard extends StatelessWidget {
  const _WalletStatsCard({this.summary, this.movements = const []});

  final CreditSummary? summary;
  final List<CreditMovement> movements;

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
            WalletChart(movements: movements),
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
                  'Granos (saldo)',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  '${summary?.grains ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  'CUP disponible',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  '${summary?.availableBalance ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '1 grano = 1 CUP. Saldo = Ganados + Recargados + Depositados − Transferidos − Retirados − Gastados. CUP disponible = granos convertidos.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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

class _VerifiedTopupRequestTile extends StatelessWidget {
  const _VerifiedTopupRequestTile({
    required this.request,
    required this.isBusinessWallet,
  });

  final VerifiedTopupRequest request;
  final bool isBusinessWallet;

  @override
  Widget build(BuildContext context) {
    final status = request.status.toLowerCase();
    final isPending = status == 'pendiente';
    final isApproved = status == 'aprobada';
    final color = isPending
        ? Colors.orange
        : isApproved
        ? Colors.green
        : Colors.redAccent;
    final date = request.createdAt == null
        ? 'Sin fecha'
        : '${request.createdAt!.day.toString().padLeft(2, '0')}/'
              '${request.createdAt!.month.toString().padLeft(2, '0')}/'
              '${request.createdAt!.year}';
    final target = request.walletScope == 'negocio' || isBusinessWallet
        ? 'Billetera del negocio'
        : 'Billetera personal';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(Icons.account_balance_rounded, color: color),
        ),
        title: Text('Recarga $target'),
        subtitle: Text(
          'Ref.: ${request.reference ?? '—'}\n'
          '${request.status.toUpperCase()} · $date'
          '${request.adminNotes?.isNotEmpty == true ? '\n${request.adminNotes}' : ''}',
        ),
        isThreeLine: request.adminNotes?.isNotEmpty == true,
        trailing: Text(
          '${request.amount} CUP',
          style: TextStyle(fontWeight: FontWeight.w900, color: color),
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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text('Alias: $alias'),
          const SizedBox(height: 16),
          if (qr == null || qr.isEmpty)
            const Text('No se pudo generar tu QR de billetera.')
          else ...[
            QrImageView(data: qr, size: 220, backgroundColor: Colors.white),
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
    this.sourceNegocioId,
  });

  final String? initialAlias;
  final String? initialUserId;
  final String? initialQrPayload;
  final String? sourceNegocioId;

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
    _destinationController = TextEditingController(
      text: widget.initialAlias ?? '',
    );
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
            widget.sourceNegocioId?.isNotEmpty == true
                ? 'Transferir desde billetera del negocio'
                : 'Transferir desde billetera',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
            decoration: const InputDecoration(labelText: 'Concepto (opcional)'),
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
                      sourceNegocioId: widget.sourceNegocioId,
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
                  shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
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
  const _RechargeCreditsSheet({this.sourceNegocioId});

  final String? sourceNegocioId;

  @override
  State<_RechargeCreditsSheet> createState() => _RechargeCreditsSheetState();
}

class _RechargeCreditsSheetState extends State<_RechargeCreditsSheet> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  WalletReceivingAccount? _account;
  VerifiedTopupRequest? _request;
  String? _accountError;
  bool _loadingAccount = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    setState(() {
      _loadingAccount = true;
      _accountError = null;
    });
    final account = await context.read<CreditsCubit>().loadReceivingAccount();
    if (!mounted) return;
    setState(() {
      _account = account;
      _loadingAccount = false;
      _accountError = account == null
          ? 'La cuenta receptora no está disponible en este momento.'
          : null;
    });
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final reference = _referenceController.text.trim();
    if (amount <= 0 || reference.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa el monto y el código de operación.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final request = await context.read<CreditsCubit>().requestRecharge(
      amount: amount,
      reference: reference,
      sourceNegocioId: widget.sourceNegocioId,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _request = request;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final account = _account;

    if (_request != null) {
      final target = _request!.walletScope == 'negocio'
          ? 'Billetera del negocio'
          : 'Billetera personal';
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Solicitud enviada',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Paso 2 de 2 · Espera la verificación de la transferencia antes de que se acredite el saldo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusLine(
                      label: 'Estado',
                      value: _request!.status.toUpperCase(),
                    ),
                    _StatusLine(
                      label: 'Referencia',
                      value: _request!.reference ?? '—',
                    ),
                    _StatusLine(label: 'Destino', value: target),
                    _StatusLine(
                      label: 'Monto solicitado',
                      value: '${_request!.amount} CUP / granos',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar y volver a la billetera'),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recargar billetera',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          const Text(
            'Paso 1 de 2 · Transfiere el monto a la cuenta configurada y después registra aquí el código de operación.',
          ),
          const SizedBox(height: 12),
          if (_loadingAccount)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ))
          else if (account == null) ...[
            Text(
              _accountError ?? 'No hay cuenta receptora configurada.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadAccount,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ] else ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.type == 'tarjeta'
                          ? 'TARJETA RECEPTORA'
                          : 'CUENTA RECEPTORA',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      account.cardNumber ??
                          account.accountNumber ??
                          'Cuenta no disponible',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Titular: ${account.holder}'),
                    if (account.bank?.isNotEmpty == true)
                      Text('Banco: ${account.bank}'),
                    if (account.instructions?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(account.instructions!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad en CUP',
                helperText: '1 CUP = 1 grano',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _referenceController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código de operación o referencia',
                hintText: 'Obligatorio; debe coincidir con la transferencia',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_rounded),
                label: const Text('Confirmar transferencia'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(child: SelectableText(value)),
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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
                    await context.read<CreditsCubit>().sellCredits(
                      amount: amount,
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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
                    await context.read<CreditsCubit>().convertGrains(
                      grains: amount,
                      negocioId: _currentNegocioId(context),
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
                : const Icon(Icons.swap_horiz_rounded),
            label: const Text('Convertir'),
          ),
        ],
      ),
    );
  }
}
