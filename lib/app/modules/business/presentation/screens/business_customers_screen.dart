import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../common/services/contact_service.dart';
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
                (item) => _SubscriberCard(
                  subscriber: item,
                  onCall: item.phone == null || item.phone!.trim().isEmpty
                      ? null
                      : () => _openPhone(context, item.phone!),
                  onWhatsApp:
                      (item.whatsapp == null ||
                              item.whatsapp!.trim().isEmpty)
                          ? null
                          : () => _openWhatsApp(context, item),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPhone(BuildContext context, String phone) async {
    final message = await sl<ContactService>().openPhone(phone);
    if (message != null && context.mounted) {
      showSnackOrAuthDialog(context, message);
    }
  }

  Future<void> _openWhatsApp(
    BuildContext context,
    BusinessSubscriber subscriber,
  ) async {
    final message = await sl<ContactService>().openWhatsApp(
      subscriber.whatsapp,
      message: 'Hola ${subscriber.name}, te escribimos desde ConKkao.',
    );
    if (message != null && context.mounted) {
      showSnackOrAuthDialog(context, message);
    }
  }
}

class _SubscriberCard extends StatelessWidget {
  const _SubscriberCard({
    required this.subscriber,
    this.onCall,
    this.onWhatsApp,
  });

  final BusinessSubscriber subscriber;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contactPhone = subscriber.phone?.trim().isNotEmpty == true;
    final contactWhatsApp = subscriber.whatsapp?.trim().isNotEmpty == true;
    final contactEmail = subscriber.email?.trim().isNotEmpty == true;
    final contactAddress = subscriber.address?.trim().isNotEmpty == true;
    final hasContact =
        contactPhone || contactWhatsApp || contactEmail || contactAddress;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage:
                      subscriber.avatarUrl == null ||
                          subscriber.avatarUrl!.isEmpty
                      ? null
                      : NetworkImage(subscriber.avatarUrl!),
                  child:
                      subscriber.avatarUrl == null ||
                          subscriber.avatarUrl!.isEmpty
                      ? Icon(
                          Icons.person_outline,
                          size: 28,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscriber.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            subscriber.notificationsEnabled
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_outlined,
                            size: 14,
                            color: subscriber.notificationsEnabled
                                ? Colors.green.shade700
                                : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              subscriber.notificationsEnabled
                                  ? 'Acepta avisos del negocio'
                                  : 'Suscrito sin avisos',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (hasContact) ...[
              if (contactPhone)
                _contactRow(
                  context: context,
                  icon: Icons.phone_outlined,
                  label: subscriber.phone!,
                  onTap: onCall,
                ),
              if (contactEmail)
                _contactRow(
                  context: context,
                  icon: Icons.email_outlined,
                  label: subscriber.email!,
                ),
              if (contactAddress)
                _contactRow(
                  context: context,
                  icon: Icons.location_on_outlined,
                  label: subscriber.address!,
                ),
              if (contactWhatsApp) ...[
                const SizedBox(height: 4),
                FilledButton.tonalIcon(
                  onPressed: onWhatsApp,
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('Contactar por WhatsApp'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _contactRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (onTap != null)
            IconButton(
              icon: const Icon(Icons.call_outlined, size: 20),
              color: theme.colorScheme.primary,
              tooltip: 'Llamar',
              visualDensity: VisualDensity.compact,
              onPressed: onTap,
            ),
        ],
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
