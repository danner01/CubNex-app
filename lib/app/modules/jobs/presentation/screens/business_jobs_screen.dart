import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../business/presentation/widgets/business_switcher.dart';
import '../../data/models/job_model.dart';

class BusinessJobsScreen extends StatefulWidget {
  const BusinessJobsScreen({super.key});

  @override
  State<BusinessJobsScreen> createState() => _BusinessJobsScreenState();
}

class _BusinessJobsScreenState extends State<BusinessJobsScreen> {
  final _apiClient = sl<ApiClient>();
  bool _loading = true;
  String? _error;
  List<JobModel> _jobs = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final activeBusiness = context
        .read<ActiveBusinessCubit>()
        .state
        .activeBusiness;
    if (activeBusiness == null) {
      setState(() {
        _loading = false;
        _jobs = const [];
        _error = 'Selecciona o crea un negocio para publicar empleos.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _apiClient.get<List<JobModel>>(
      '/empleos',
      queryParameters: {
        'negocio_id': activeBusiness.id,
        'order': 'created_at.desc',
      },
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

  Future<void> _createJob() async {
    final activeBusiness = context
        .read<ActiveBusinessCubit>()
        .state
        .activeBusiness;
    if (activeBusiness == null) return;

    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _JobFormSheet(businessName: activeBusiness.name),
    );
    if (payload == null || !mounted) return;

    setState(() => _loading = true);
    final result = await _apiClient.post<dynamic>(
      '/empleos',
      data: {
        ...payload,
        'negocio_id': activeBusiness.id,
        'provincia': activeBusiness.province,
        'municipio': activeBusiness.municipality,
        'contacto_telefono':
            payload['contacto_telefono'] ?? activeBusiness.phone,
        'contacto_whatsapp':
            payload['contacto_whatsapp'] ?? activeBusiness.whatsapp,
      },
    );
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _error = result.error?.message ?? 'No se pudo publicar el empleo.';
      });
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Empleo publicado.')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createJob,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Empleo'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Text(
              'Empleos del negocio',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            BusinessSwitcher(onChanged: _load),
            const SizedBox(height: 16),
            if (_error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_jobs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Todavia no has publicado empleos.'),
                ),
              )
            else
              ..._jobs.map((job) => _BusinessJobCard(job: job)),
          ],
        ),
      ),
    );
  }
}

class _BusinessJobCard extends StatelessWidget {
  const _BusinessJobCard({required this.job});

  final JobModel job;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  job.active ? Icons.work_rounded : Icons.work_off_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    job.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${job.role} · ${job.salaryLabel}'),
            const SizedBox(height: 6),
            Text(job.description ?? 'Sin descripcion.'),
            const SizedBox(height: 8),
            Text(
              '${job.locationLabel} · ${job.schedule ?? 'Horario a definir'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _JobFormSheet extends StatefulWidget {
  const _JobFormSheet({required this.businessName});

  final String businessName;

  @override
  State<_JobFormSheet> createState() => _JobFormSheetState();
}

class _JobFormSheetState extends State<_JobFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _role = TextEditingController();
  final _description = TextEditingController();
  final _requirements = TextEditingController();
  final _schedule = TextEditingController();
  final _salaryMin = TextEditingController();
  final _salaryMax = TextEditingController();
  final _bannerUrl = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  String _modality = 'presencial';
  String _currency = 'CUP';
  DateTime? _expiresAt;

  @override
  void dispose() {
    _title.dispose();
    _role.dispose();
    _description.dispose();
    _requirements.dispose();
    _schedule.dispose();
    _salaryMin.dispose();
    _salaryMax.dispose();
    _bannerUrl.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Solicitar empleado',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(widget.businessName),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Titulo del empleo',
                ),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _role,
                decoration: const InputDecoration(labelText: 'Cargo o funcion'),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripcion'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _requirements,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Requisitos'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _schedule,
                decoration: const InputDecoration(labelText: 'Horario'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMin,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Salario min',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMax,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Salario max',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _modality,
                      decoration: const InputDecoration(labelText: 'Modalidad'),
                      items: const [
                        DropdownMenuItem(
                          value: 'presencial',
                          child: Text('Presencial'),
                        ),
                        DropdownMenuItem(
                          value: 'remoto',
                          child: Text('Remoto'),
                        ),
                        DropdownMenuItem(value: 'mixto', child: Text('Mixto')),
                        DropdownMenuItem(
                          value: 'por_turnos',
                          child: Text('Por turnos'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _modality = value ?? _modality),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                      items: const [
                        DropdownMenuItem(value: 'CUP', child: Text('CUP')),
                        DropdownMenuItem(value: 'MLC', child: Text('MLC')),
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                      ],
                      onChanged: (value) =>
                          setState(() => _currency = value ?? _currency),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _bannerUrl,
                decoration: const InputDecoration(
                  labelText: 'Banner URL opcional',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefono de contacto',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _whatsapp,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp de contacto',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickExpiration,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _expiresAt == null
                      ? 'Fecha de caducidad'
                      : 'Caduca ${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.publish_outlined),
                  label: const Text('Publicar empleo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Campo requerido' : null;
  }

  Future<void> _pickExpiration() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) setState(() => _expiresAt = date);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'titulo': _title.text.trim(),
      'cargo': _role.text.trim(),
      'descripcion': _emptyToNull(_description.text),
      'requisitos': _emptyToNull(_requirements.text),
      'horario': _emptyToNull(_schedule.text),
      'modalidad': _modality,
      'salario_min': double.tryParse(
        _salaryMin.text.trim().replaceAll(',', '.'),
      ),
      'salario_max': double.tryParse(
        _salaryMax.text.trim().replaceAll(',', '.'),
      ),
      'moneda': _currency,
      'banner_url': _emptyToNull(_bannerUrl.text),
      'contacto_telefono': _emptyToNull(_phone.text),
      'contacto_whatsapp': _emptyToNull(_whatsapp.text),
      'fecha_caducidad': _expiresAt?.toIso8601String(),
      'activo': true,
    });
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
