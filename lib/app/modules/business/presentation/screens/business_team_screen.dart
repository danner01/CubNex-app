import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/entities/employee_permissions.dart';
import '../../../../common/presentation/widgets/auth_required_dialog.dart';
import '../../../../config/http/api_client.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/theme/app_colors.dart';
import '../../data/models/business_employee_model.dart';
import '../widgets/business_switcher.dart';

class BusinessTeamScreen extends StatefulWidget {
  const BusinessTeamScreen({super.key});

  @override
  State<BusinessTeamScreen> createState() => _BusinessTeamScreenState();
}

class _BusinessTeamScreenState extends State<BusinessTeamScreen> {
  final _api = sl<ApiClient>();
  var _loading = true;
  String? _error;
  String? _loadedBusinessId;
  List<BusinessEmployeeModel> _employees = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final business = context.read<ActiveBusinessCubit>().state.activeBusiness;
    final businessId = business?.id;
    if (businessId == null) {
      setState(() {
        _loading = false;
        _error = 'Selecciona un negocio activo.';
        _employees = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _loadedBusinessId = businessId;
    });

    try {
      final result = await _api.get<List<BusinessEmployeeModel>>(
        '/empleados',
        queryParameters: {
          'negocio_id': businessId,
          'limit': 100,
          'order': 'created_at.desc',
        },
        parser: (json) {
          if (json is! List) return const <BusinessEmployeeModel>[];
          return json
              .whereType<Map>()
              .map(
                (item) => BusinessEmployeeModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.status != 'eliminado')
              .toList();
        },
      );

      if (!mounted) return;
      if (!result.isSuccess) {
        setState(() {
          _loading = false;
          _error = result.error?.message ?? 'No se pudo cargar el equipo.';
        });
        return;
      }

      setState(() {
        _loading = false;
        _employees = result.data ?? const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar el equipo. Revisa la conexion e intentalo de nuevo.';
      });
    }
  }

  Future<void> _openInviteSheet() async {
    final business = context.read<ActiveBusinessCubit>().state.activeBusiness;
    if (business == null) {
      showSnackOrAuthDialog(context, 'Selecciona un negocio activo.');
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _InviteEmployeeSheet(businessId: business.id),
    );

    if (created == true && mounted) {
      await _load();
    }
  }

  Future<void> _editEmployee(BusinessEmployeeModel employee) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EditEmployeeSheet(employee: employee),
    );
    if (updated == true && mounted) {
      await _load();
    }
  }

  Future<void> _removeEmployee(BusinessEmployeeModel employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar empleado'),
        content: Text(
          '¿Eliminar a ${employee.userName ?? employee.userEmail ?? 'este usuario'} del equipo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await _api.delete<Map<String, dynamic>>(
      '/empleados/${employee.id}',
      parser: (json) {
        if (json is Map<String, dynamic>) return json;
        if (json is Map) return Map<String, dynamic>.from(json);
        return <String, dynamic>{};
      },
    );
    if (!mounted) return;
    if (!result.isSuccess) {
      showSnackOrAuthDialog(
        context,
        result.error?.message ?? 'No se pudo eliminar.',
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openInviteSheet,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Invitar'),
      ),
      body: BlocListener<ActiveBusinessCubit, ActiveBusinessState>(
        listenWhen: (previous, current) =>
            previous.activeBusiness?.id != current.activeBusiness?.id,
        listener: (_, __) => _load(),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              Text(
                'Equipo del negocio',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Invita usuarios de la app, define cargo y marca que pueden hacer.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              BusinessSwitcher(onChanged: _load),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!),
                  ),
                )
              else if (_employees.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Icon(Icons.groups_outlined, size: 42),
                        const SizedBox(height: 10),
                        Text(
                          'Aun no hay empleados en ${_loadedBusinessId == null ? 'este negocio' : 'el equipo'}.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Usa Invitar para enviar una solicitud de asociacion.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._employees.map(
                  (employee) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _EmployeeCard(
                      employee: employee,
                      onEdit: () => _editEmployee(employee),
                      onRemove: () => _removeEmployee(employee),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.onEdit,
    required this.onRemove,
  });

  final BusinessEmployeeModel employee;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final enabledCount =
        employee.permissions.values.where((value) => value).length;
    final statusColor = switch (employee.status) {
      'activo' => AppColors.success,
      'pendiente' => AppColors.warning,
      'rechazado' => AppColors.danger,
      _ => Theme.of(context).colorScheme.outline,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                  child: Text(
                                      () {
                                        final label =
                                            (employee.userName ?? employee.userEmail ?? '?')
                                                .trim();
                                        return label.isEmpty
                                            ? '?'
                                            : label.substring(0, 1).toUpperCase();
                                      }(),
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.userName ?? 'Usuario',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        employee.userEmail ?? employee.userId,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    employee.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(employee.roleTitle)),
                if (employee.isDelivery)
                  const Chip(
                    avatar: Icon(Icons.delivery_dining, size: 16),
                    label: Text('Delivery'),
                  ),
                Chip(label: Text('$enabledCount permisos')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Cargo y permisos'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteEmployeeSheet extends StatefulWidget {
  const _InviteEmployeeSheet({required this.businessId});

  final String businessId;

  @override
  State<_InviteEmployeeSheet> createState() => _InviteEmployeeSheetState();
}

class _InviteEmployeeSheetState extends State<_InviteEmployeeSheet> {
  final _api = sl<ApiClient>();
  final _emailController = TextEditingController();
  final _cargoController = TextEditingController(text: 'Empleado');
  final _messageController = TextEditingController();
  var _isDelivery = false;
  var _saving = false;
  late Map<String, bool> _permissions;

  @override
  void initState() {
    super.initState();
    _permissions =
        EmployeePermissionKeys.defaultsForCargo(_cargoController.text);
    _cargoController.addListener(() {
      setState(() {
        _permissions =
            EmployeePermissionKeys.defaultsForCargo(_cargoController.text);
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _cargoController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final identifier = _emailController.text.trim();
    if (identifier.isEmpty) {
      showSnackOrAuthDialog(
        context,
        'Indica el email o telefono del usuario registrado en la app.',
      );
      return;
    }

    final isEmail = identifier.contains('@');
    final data = <String, dynamic>{
      'negocio_id': widget.businessId,
      'cargo': _cargoController.text.trim().isEmpty
          ? 'Empleado'
          : _cargoController.text.trim(),
      'es_delivery': _isDelivery,
      'permisos': _permissions,
      'mensaje_invitacion': _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim(),
    };
    if (isEmail) {
      data['email'] = identifier.toLowerCase();
    } else {
      data['telefono'] = identifier;
      data['alias'] = identifier;
    }

    setState(() => _saving = true);
    try {
      final result = await _api.post<Map<String, dynamic>>(
        '/empleados/invitar',
        data: data,
        parser: (json) {
          if (json is Map<String, dynamic>) return json;
          if (json is Map) return Map<String, dynamic>.from(json);
          return <String, dynamic>{};
        },
      );
      if (!mounted) return;
      setState(() => _saving = false);

      if (!result.isSuccess) {
        showSnackOrAuthDialog(context, _inviteErrorMessage(result.error?.code, result.error?.message));
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnackOrAuthDialog(
        context,
        'No se pudo enviar la invitacion por un problema de conexion. Intentalo otra vez.',
      );
    }
  }

  String _inviteErrorMessage(String? code, String? fallback) {
    switch (code?.toUpperCase()) {
      case 'USUARIO_NO_ENCONTRADO':
        return 'No encontramos una cuenta con ese email o telefono. La persona debe registrarse primero en ConKkao.';
      case 'AUTO_INVITACION':
        return 'No puedes invitarte a ti mismo al equipo.';
      case 'NEGOCIO_REQUERIDO':
        return 'Selecciona un negocio activo antes de invitar a alguien.';
      case 'NO_AUTORIZADO':
      case 'SOLO_PROPIETARIO':
        return 'No tienes permiso para gestionar el equipo de este negocio.';
      case 'NO_AUTENTICADO':
      case 'SIN_TOKEN':
        return 'Tu sesion vencio. Inicia sesion de nuevo para enviar la invitacion.';
      case 'DUPLICADO':
      case 'CONFLICTO':
        return 'Esa persona ya tiene una invitacion o pertenece al equipo.';
    }
    final message = fallback?.trim() ?? '';
    if (message.toLowerCase().contains('relationship') ||
        message.toLowerCase().contains('could not embed')) {
      return 'No se pudo guardar la invitacion por una configuracion temporal del servidor. Intentalo de nuevo.';
    }
    return message.isEmpty ? 'No se pudo enviar la invitacion.' : message;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invitar empleado',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                            labelText: 'Email o telefono del usuario',
                            hintText: 'ej. emilyelena@yopmail.com',
                            helperText:
                                'Debe ser una cuenta ya registrada en la app (email exacto).',
                            border: OutlineInputBorder(),
                          ),
                        ),
            const SizedBox(height: 12),
            TextField(
              controller: _cargoController,
              decoration: const InputDecoration(
                labelText: 'Cargo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Mensaje (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tambien puede operar como delivery'),
              value: _isDelivery,
              onChanged: (value) => setState(() => _isDelivery = value),
            ),
            const SizedBox(height: 8),
            Text(
              'Permisos',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...EmployeePermissionKeys.all.map((key) {
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _permissions[key] == true,
                onChanged: (value) {
                  setState(() => _permissions[key] = value == true);
                },
                title: Text(EmployeePermissionKeys.labels[key] ?? key),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_saving ? 'Enviando...' : 'Enviar solicitud'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditEmployeeSheet extends StatefulWidget {
  const _EditEmployeeSheet({required this.employee});

  final BusinessEmployeeModel employee;

  @override
  State<_EditEmployeeSheet> createState() => _EditEmployeeSheetState();
}

class _EditEmployeeSheetState extends State<_EditEmployeeSheet> {
  final _api = sl<ApiClient>();
  late final TextEditingController _cargoController;
  late bool _isDelivery;
  late String _status;
  late Map<String, bool> _permissions;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _cargoController = TextEditingController(text: widget.employee.roleTitle);
    _isDelivery = widget.employee.isDelivery;
    _status = widget.employee.status == 'pendiente'
        ? 'pendiente'
        : widget.employee.status == 'activo'
            ? 'activo'
            : widget.employee.status;
    _permissions = Map<String, bool>.from(widget.employee.permissions);
  }

  @override
  void dispose() {
    _cargoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final result = await _api.put<Map<String, dynamic>>(
      '/empleados/${widget.employee.id}',
          data: {
        'cargo': _cargoController.text.trim().isEmpty
            ? 'Empleado'
            : _cargoController.text.trim(),
        'es_delivery': _isDelivery,
        'estado': _status == 'pendiente' ? widget.employee.status : _status,
        'permisos': _permissions,
      },
      parser: (json) {
        if (json is Map<String, dynamic>) return json;
        if (json is Map) return Map<String, dynamic>.from(json);
        return <String, dynamic>{};
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!result.isSuccess) {
      showSnackOrAuthDialog(
        context,
        result.error?.message ?? 'No se pudo actualizar.',
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Editar empleado',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cargoController,
              decoration: const InputDecoration(
                labelText: 'Cargo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status == 'rechazado' ? 'inactivo' : _status,
              items: const [
                DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                DropdownMenuItem(value: 'activo', child: Text('Activo')),
                DropdownMenuItem(value: 'inactivo', child: Text('Inactivo')),
              ],
              onChanged: widget.employee.isPending
                  ? null
                  : (value) {
                      if (value != null) setState(() => _status = value);
                    },
              decoration: const InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Puede operar como delivery'),
              value: _isDelivery,
              onChanged: (value) => setState(() => _isDelivery = value),
            ),
            const SizedBox(height: 8),
            Text(
              'Permisos habilitados',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            ...EmployeePermissionKeys.all.map((key) {
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _permissions[key] == true,
                onChanged: (value) {
                  setState(() => _permissions[key] = value == true);
                },
                title: Text(EmployeePermissionKeys.labels[key] ?? key),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
