import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../blocs/scan_history/scan_history_cubit.dart';
import '../../blocs/scan_history/scan_history_state.dart';
import '../../blocs/scanner/scanner_cubit.dart';

class ScanHistoryScreen extends StatelessWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ScanHistoryCubit>()..load(),
      child: const _ScanHistoryView(),
    );
  }
}

class _ScanHistoryView extends StatelessWidget {
  const _ScanHistoryView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ScanHistoryCubit, ScanHistoryState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () => context.read<ScanHistoryCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  'Historial de escaneos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'QR, codigos de barra y productos consultados desde la app.',
                ),
                const SizedBox(height: 16),
                if (state.status == ScanHistoryStatus.loading)
                  const Center(child: CircularProgressIndicator())
                else if (state.items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Todavia no tienes escaneos guardados.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...state.items.map((item) {
                    final date = item.createdAt == null
                        ? 'Sin fecha'
                        : DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt!);
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          item.type.startsWith('qr')
                              ? Icons.qr_code_2_rounded
                              : Icons.barcode_reader,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        title: Text(
                          item.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text('${item.type} · $date'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          final target = sl<ScannerCubit>().resolveDirectTarget(
                            item.content,
                          );
                          if (target != null) {
                            context.go(target);
                            return;
                          }
                          if (item.productId != null) {
                            context.go(AppRoutes.product(item.productId!));
                            return;
                          }
                          if (item.businessId != null) {
                            context.go(AppRoutes.store(item.businessId!));
                            return;
                          }
                          context.go('${AppRoutes.search}?q=${item.content}');
                        },
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
