import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/http/api_client.dart';
import '../../../config/injection/injection.dart';
import '../../blocs/app_session/app_session_cubit.dart';
import '../../services/proximity_alert_service.dart';

/// Arranca el aviso por cercania para usuarios con sesion y muestra la
/// tarjeta con "Como llegar" (ruta en el mapa) y "Conectar" para negocios.
class ProximityAlertHost extends StatefulWidget {
  const ProximityAlertHost({required this.child, super.key});

  final Widget child;

  @override
  State<ProximityAlertHost> createState() => _ProximityAlertHostState();
}

class _ProximityAlertHostState extends State<ProximityAlertHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (!mounted) return;
    final status = context.read<AppSessionCubit>().state.status;
    if (status == AppSessionStatus.authenticated) {
      ProximityAlertService.instance.start(sl<ApiClient>());
    } else if (status != AppSessionStatus.loading) {
      ProximityAlertService.instance.stop();
    }
  }

  Future<void> _route(ProximityAlert a) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${a.lat},${a.lng}'
      '&travelmode=walking',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppSessionCubit, AppSessionState>(
      listener: (_, __) => _sync(),
      child: Column(
        children: [
          ValueListenableBuilder<ProximityAlert?>(
            valueListenable: ProximityAlertService.instance.current,
            builder: (context, alert, _) {
              if (alert == null) return const SizedBox.shrink();
              final scheme = Theme.of(context).colorScheme;
              return Material(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                  child: Row(
                    children: [
                      Icon(
                        alert.isOpportunity
                            ? Icons.handshake_outlined
                            : Icons.near_me_rounded,
                        color: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              alert.body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            Wrap(
                              spacing: 6,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _route(alert),
                                  icon: const Icon(Icons.directions, size: 16),
                                  label: const Text('Como llegar'),
                                ),
                                if (alert.connectPath != null)
                                  TextButton.icon(
                                    onPressed: () {
                                      ProximityAlertService.instance.dismiss();
                                      context.go('/business/network');
                                    },
                                    icon: const Icon(Icons.link, size: 16),
                                    label: const Text('Conectar'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: ProximityAlertService.instance.dismiss,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
