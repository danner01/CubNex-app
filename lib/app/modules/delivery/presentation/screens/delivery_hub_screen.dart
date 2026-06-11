import 'package:flutter/material.dart';

enum DeliveryHubSection { dashboard, requests, route, history, profile }

class DeliveryHubScreen extends StatelessWidget {
  const DeliveryHubScreen({required this.section, super.key});

  final DeliveryHubSection section;

  @override
  Widget build(BuildContext context) {
    final data = _sectionData(section);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            data.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(data.subtitle),
          const SizedBox(height: 18),
          if (section == DeliveryHubSection.dashboard) ...[
            const _DeliveryStatusCard(),
            const SizedBox(height: 14),
            const _MetricsGrid(),
          ] else if (section == DeliveryHubSection.requests) ...[
            _ActionCard(
              icon: Icons.notifications_active_outlined,
              title: 'Solicitudes pendientes',
              subtitle:
                  'Aqui llegaran pedidos de tiendas y paquetes de clientes para aceptar o rechazar.',
            ),
            _ActionCard(
              icon: Icons.storefront_outlined,
              title: 'Deliverys asociados',
              subtitle:
                  'Las tiendas podran asociarte como delivery frecuente y enviarte solicitudes directas.',
            ),
          ] else if (section == DeliveryHubSection.route) ...[
            _ActionCard(
              icon: Icons.map_outlined,
              title: 'Ruta activa',
              subtitle:
                  'Mapa con recogida, destino, distancia, tarifa estimada y ruta optimizada.',
            ),
            _ActionCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Escanear QR',
              subtitle:
                  'Validaras recogida, entrega y liquidacion desde el QR del pedido o paquete.',
            ),
          ] else if (section == DeliveryHubSection.history) ...[
            _ActionCard(
              icon: Icons.inventory_2_outlined,
              title: 'Entregas completadas',
              subtitle:
                  'Historial con km recorridos, cobros, liquidaciones y calificaciones.',
            ),
            _ActionCard(
              icon: Icons.local_shipping_outlined,
              title: 'Paquetes entre clientes',
              subtitle:
                  'Envios creados por clientes con QR publico para destinatarios.',
            ),
          ] else ...[
            _ActionCard(
              icon: Icons.two_wheeler_outlined,
              title: 'Vehiculo y tarifas',
              subtitle:
                  'Configura tipo de vehiculo, tarifa base, precio por km y radio de operacion.',
            ),
            _ActionCard(
              icon: Icons.verified_user_outlined,
              title: 'Verificacion',
              subtitle:
                  'Documentos, nivel de confianza, disponibilidad y estado operativo.',
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliveryStatusCard extends StatelessWidget {
  const _DeliveryStatusCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  child: const Icon(Icons.delivery_dining_rounded, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo delivery activo',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Disponible para solicitudes verificadas.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.power_settings_new_rounded),
              label: const Text('Cambiar disponibilidad'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid();

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Hoy', '0', Icons.today_outlined),
      ('Km', '0', Icons.route_outlined),
      ('Ingresos', '0 CUP', Icons.payments_outlined),
      ('Rating', '0.0', Icons.star_border_rounded),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(metric.$3, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(height: 8),
                Text(metric.$1),
                Text(
                  metric.$2,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

_SectionData _sectionData(DeliveryHubSection section) {
  return switch (section) {
    DeliveryHubSection.dashboard => const _SectionData(
      'Panel delivery',
      'Solicitudes, entregas, ruta activa y confianza.',
    ),
    DeliveryHubSection.requests => const _SectionData(
      'Solicitudes',
      'Pedidos de tiendas y paquetes entre clientes.',
    ),
    DeliveryHubSection.route => const _SectionData(
      'Ruta y mapa',
      'Seguimiento en tiempo real, QR y entregas activas.',
    ),
    DeliveryHubSection.history => const _SectionData(
      'Entregas',
      'Historial, liquidaciones y calificaciones.',
    ),
    DeliveryHubSection.profile => const _SectionData(
      'Perfil delivery',
      'Vehiculo, tarifas, verificacion y disponibilidad.',
    ),
  };
}

class _SectionData {
  const _SectionData(this.title, this.subtitle);

  final String title;
  final String subtitle;
}
