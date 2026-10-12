import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../data/models/business_opportunity.dart';

class BusinessCustomersScreen extends StatefulWidget {
  const BusinessCustomersScreen({super.key});

  @override
  State<BusinessCustomersScreen> createState() => _BusinessCustomersScreenState();
}

class _BusinessCustomersScreenState extends State<BusinessCustomersScreen> {
  bool _loading = true;
  String? _message;
  int _total = 0;
  int _recent = 0;
  int _notified = 0;
  List<BusinessSubscriber> _subscribers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final business = context.read<ActiveBusinessCubit>().state.activeBusiness;
    if (business == null) {
      setState(() {
        _loading = false;
        _message = 'Selecciona un negocio para ver clientes suscritos.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    final result = await sl<ApiClient>().get<Map<String, dynamic>?>(
      '/oportunidades/negocios/${business.id}/suscriptores',
      parser: (json) => json is Map ? Map<String, dynamic>.from(json) : null,
    );
    if (!mounted) return;
    if (!result.isSuccess || result.data == null) {
      setState(() {
        _loading = false;
        _message =
            result.error?.message ??
            'No se pudo cargar la lista de clientes suscritos.';
      });
      return;
    }
    final data = result.data!;
    final activity = data['actividad_agregada'];
    final activityMap = activity is Map
        ? Map<String, dynamic>.from(activity)
        : const <String, dynamic>{};
    final raw = data['suscriptores'];
    setState(() {
      _loading = false;
      _total = data['total'] is num ? (data['total'] as num).toInt() : 0;
      _recent = activityMap['nuevos_30d'] is num
          ? (activityMap['nuevos_30d'] as num).toInt()
          : 0;
      _notified = activityMap['con_avisos'] is num
          ? (activityMap['con_avisos'] as num).toInt()
          : 0;
      _subscribers = raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (item) => BusinessSubscriber.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes suscritos')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              'Solo aparecen clientes que se suscribieron de forma voluntaria. No se muestran compras, reservas ni solicitudes individuales.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatChip(label: 'Total', value: '$_total')),
                const SizedBox(width: 8),
                Expanded(child: _StatChip(label: 'Nuevos 30d', value: '$_recent')),
                const SizedBox(width: 8),
                Expanded(child: _StatChip(label: 'Con avisos', value: '$_notified')),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_message != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_message!),
                ),
              )
            else if (_subscribers.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Todavia no hay clientes suscritos a este negocio.'),
                ),
              )
            else
              ..._subscribers.map(
                (item) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          item.avatarUrl == null || item.avatarUrl!.isEmpty
                          ? null
                          : NetworkImage(item.avatarUrl!),
                      child: item.avatarUrl == null || item.avatarUrl!.isEmpty
                          ? const Icon(Icons.person_outline)
                          : null,
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      item.notificationsEnabled
                          ? 'Acepta avisos del negocio'
                          : 'Suscrito sin avisos',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
