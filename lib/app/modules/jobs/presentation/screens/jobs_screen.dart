import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/injection/injection.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/routes/app_routes.dart';
import '../../data/models/job_model.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _apiClient = sl<ApiClient>();
  bool _loading = true;
  String? _error;
  List<JobModel> _jobs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _apiClient.get<List<JobModel>>(
      '/empleos',
      queryParameters: {'limit': 30, 'order': 'created_at.desc'},
      parser: (json) {
        if (json is! List) return const [];
        return json
            .whereType<Map>()
            .map((item) => JobModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      },
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _jobs = result.data ?? const [];
      _error = result.error?.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Empleos',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Buscar negocios',
                  onPressed: () => context.go(AppRoutes.search),
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Oportunidades publicadas por negocios cubanos. Contacta directamente y acuerda condiciones.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _jobs.isEmpty)
              _EmptyJobs(message: _error!)
            else if (_jobs.isEmpty)
              const _EmptyJobs(
                message: 'Aun no hay empleos publicados cerca de ti.',
              )
            else
              ..._jobs.map((job) => _JobCard(job: job)),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final JobModel job;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (job.bannerUrl?.isNotEmpty == true)
            AspectRatio(
              aspectRatio: 16 / 7,
              child: Image.network(job.bannerUrl!, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: job.businessLogoUrl?.isNotEmpty == true
                          ? NetworkImage(job.businessLogoUrl!)
                          : null,
                      child: job.businessLogoUrl?.isNotEmpty == true
                          ? null
                          : const Icon(Icons.storefront_rounded),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            job.businessName ?? 'Negocio',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(job.role)),
                    Chip(label: Text(job.modality ?? 'Presencial')),
                    Chip(label: Text(job.salaryLabel)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(job.description ?? 'Sin descripcion adicional.'),
                if (job.requirements?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Requisitos: ${job.requirements}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${job.locationLabel} · ${job.schedule ?? 'Horario a definir'}',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: job.contactWhatsapp?.isNotEmpty == true
                            ? () => _openWhatsApp(job.contactWhatsapp!)
                            : null,
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: job.contactPhone?.isNotEmpty == true
                            ? () => launchUrl(
                                Uri.parse('tel:${job.contactPhone}'),
                              )
                            : null,
                        icon: const Icon(Icons.call_outlined),
                        label: const Text('Llamar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openWhatsApp(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    launchUrl(Uri.parse('https://wa.me/$normalized'));
  }
}

class _EmptyJobs extends StatelessWidget {
  const _EmptyJobs({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.work_outline_rounded, size: 42),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
