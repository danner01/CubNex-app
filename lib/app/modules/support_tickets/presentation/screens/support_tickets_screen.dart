import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../blocs/support_tickets/support_tickets_cubit.dart';
import '../../blocs/support_tickets/support_tickets_state.dart';
import '../../data/models/soporte_ticket_model.dart';

class SupportTicketsScreen extends StatelessWidget {
  const SupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SupportTicketsCubit>()..load(),
      child: const _SupportTicketsView(),
    );
  }
}

class _SupportTicketsView extends StatefulWidget {
  const _SupportTicketsView();

  @override
  State<_SupportTicketsView> createState() => _SupportTicketsViewState();
}

class _SupportTicketsViewState extends State<_SupportTicketsView> {
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  bool _subiendoAdjunto = false;
  String? _adjuntoUrl;

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _pickAdjunto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Tomar foto del problema'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Captura de pantalla o galeria'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1000,
    );
    if (image == null || !mounted) return;

    setState(() => _subiendoAdjunto = true);
    final cubit = context.read<SupportTicketsCubit>();
    try {
      final bytes = await image.readAsBytes();
      final url = await cubit.uploadAttachment(
        'ticket-${DateTime.now().millisecondsSinceEpoch}.jpg',
        image.mimeType ?? 'image/jpeg',
        cubit.fileToBase64(bytes),
      );
      if (!mounted) return;
      setState(() {
        _subiendoAdjunto = false;
        if (url != null) _adjuntoUrl = url;
      });
      if (url == null) {
        showSnackOrAuthDialog(
          context,
          'No se pudo subir la captura. Revisa conexion e internet.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _subiendoAdjunto = false);
        showSnackOrAuthDialog(
          context,
          'No se pudo procesar la imagen seleccionada.',
        );
      }
    }
  }

  Future<void> _enviar() async {
    final descripcion = _descripcionController.text.trim();
    if (descripcion.isEmpty) {
      showSnackOrAuthDialog(context, 'Describe el problema que tienes.');
      return;
    }

    final result = await context.read<SupportTicketsCubit>().createTicket(
      descripcion: descripcion,
      titulo: _tituloController.text,
      adjuntoUrl: _adjuntoUrl,
    );
    if (!mounted) return;
    if (result != null) {
      _tituloController.clear();
      _descripcionController.clear();
      setState(() => _adjuntoUrl = null);
      showSnackOrAuthDialog(
        context,
        result.numeroTicket != null
            ? 'Ticket #${result.numeroTicket} enviado. El equipo de soporte lo atendera pronto.'
            : 'Ticket enviado. El equipo de soporte lo atendera pronto.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<SupportTicketsCubit, SupportTicketsState>(
        listener: (context, state) {
          if (state.message != null && state.status != SupportTicketsStatus.creating) {
            showSnackOrAuthDialog(context, state.message);
          }
        },
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () => context.read<SupportTicketsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
              children: [
                Text(
                  'Tickets de soporte',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cuentanos el problema y adjunta una captura; seguiremos tu ticket y veras cuando quede atendido.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _buildForm(context, state),
                const SizedBox(height: 28),
                Text(
                  'Mis tickets',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Solo ves los tickets que has creado.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (state.status == SupportTicketsStatus.loading &&
                    state.tickets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.tickets.isEmpty)
                  const _EmptyTickets()
                else
                  ...state.tickets.map(
                    (ticket) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TicketCard(ticket: ticket),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, SupportTicketsState state) {
    final submitting = state.status == SupportTicketsStatus.creating;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nuevo ticket',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tituloController,
            enabled: !submitting,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Titulo (opcional)',
              hintText: 'Ej: No puedo hacer login',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descripcionController,
            enabled: !submitting,
            maxLines: 4,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Describe el problema *',
              hintText: 'Explica que ocurrio, cuando y que esperabas que pasara.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: submitting || _subiendoAdjunto
                    ? null
                    : _pickAdjunto,
                icon: _subiendoAdjunto
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                label: Text(
                  _adjuntoUrl != null
                      ? 'Adjunto listo'
                      : 'Adjuntar captura de pantalla',
                ),
              ),
              const SizedBox(width: 8),
              if (_adjuntoUrl != null)
                IconButton(
                  tooltip: 'Quitar adjunto',
                  onPressed: submitting
                      ? null
                      : () => setState(() => _adjuntoUrl = null),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: submitting ? null : _enviar,
              icon: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.support_agent_rounded),
              label: Text(submitting ? 'Enviando...' : 'Enviar ticket'),
            ),
          ),
          if (_adjuntoUrl != null) ...[
            const SizedBox(height: 12),
            Text(
              'Captura adjunta.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.goldDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SoporteTicketModel ticket;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estadoColor = switch (ticket.estado) {
      'resuelto' => const Color(0xFF2E7D32),
      'cancelado' => scheme.onSurfaceVariant,
      _ => const Color(0xFF9A6A00),
    };
    final estadoLabel = switch (ticket.estado) {
      'resuelto' => 'Atendido',
      'cancelado' => 'Cancelado',
      _ => 'Pendiente',
    };

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showDetalle(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.titulo?.isNotEmpty == true
                        ? ticket.titulo!
                        : 'Ticket ${ticket.numeroTicket != null ? '#${ticket.numeroTicket}' : 'sin numero'}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: estadoColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        estadoLabel,
                        style: TextStyle(
                          color: estadoColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket.descripcion,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _fechaLabel(ticket.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (ticket.estaAtendido && ticket.resolucion?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                'Resolucion: ${ticket.resolucion}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.goldDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fechaLabel(DateTime? createdAt) {
    if (createdAt == null) return 'Fecha sin registrar';
    final local = createdAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Creado el ${two(local.day)}/${two(local.month)}/${local.year} a las '
        '${two(local.hour)}:${two(local.minute)}';
  }

  void _showDetalle(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            ticket.titulo?.isNotEmpty == true
                ? ticket.titulo!
                : 'Ticket ${ticket.numeroTicket != null ? '#${ticket.numeroTicket}' : 'sin numero'}',
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ticket.descripcion),
                const SizedBox(height: 12),
                Text(
                  _fechaLabel(ticket.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (ticket.adjuntoUrl != null) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    onLongPress: () {},
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        ticket.adjuntoUrl!,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
                if (ticket.estaAtendido && ticket.resolucion?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Resolucion del equipo:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(ticket.resolucion!),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyTickets extends StatelessWidget {
  const _EmptyTickets();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.support_agent_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            'Aun no has creado tickets.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cuando envies uno, aparecera aqui y podras seguir su estado.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}