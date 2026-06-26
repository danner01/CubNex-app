import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/blocs/active_business/active_business_cubit.dart';
import '../../../../common/blocs/app_session/app_session_cubit.dart';
import '../../../../common/presentation/widgets/cubnex_logo.dart';
import '../../../../config/injection/injection.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../domain/usecases/login_with_email.dart';
import '../../domain/usecases/login_with_google.dart';
import '../../domain/usecases/recover_password.dart';
import '../../domain/usecases/register_account.dart';

enum _AuthMode { login, register }

enum _RegisterRole { client, business, delivery }

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(
        loginWithEmail: sl<LoginWithEmail>(),
        loginWithGoogle: sl<LoginWithGoogle>(),
        registerAccount: sl<RegisterAccount>(),
        recoverPassword: sl<RecoverPassword>(),
      ),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _recoveryFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _recoveryEmailController = TextEditingController();
  final _deliveryPlateController = TextEditingController();
  final _deliveryCapacityController = TextEditingController();
  final _deliveryBaseFareController = TextEditingController(text: '0');
  final _deliveryKmFareController = TextEditingController(text: '0');
  final _deliveryRadiusController = TextEditingController(text: '8');
  _AuthMode _mode = _AuthMode.login;
  _RegisterRole _role = _RegisterRole.client;
  String _deliveryVehicleType = 'motorina';
  bool _deliveryAcceptsTransfer = false;
  bool _showPassword = false;
  bool _navigatingAfterAuth = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _recoveryEmailController.dispose();
    _deliveryPlateController.dispose();
    _deliveryCapacityController.dispose();
    _deliveryBaseFareController.dispose();
    _deliveryKmFareController.dispose();
    _deliveryRadiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) async {
        if (state.status == AuthStatus.success &&
            state.session != null &&
            !_navigatingAfterAuth) {
          _navigatingAfterAuth = true;
          try {
            await context
                .read<AppSessionCubit>()
                .setSession(state.session!)
                .timeout(const Duration(seconds: 5));
          } catch (_) {
            _navigatingAfterAuth = false;
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se pudo guardar la sesion. Intenta iniciar sesion nuevamente.',
                ),
              ),
            );
            return;
          }
          if (!context.mounted) return;
          final isNewBusinessRegistration =
              _mode == _AuthMode.register && _role == _RegisterRole.business;
          final role = state.session!.role;

          if (role.name == 'businessAdmin' || role.name == 'superadmin') {
            if (isNewBusinessRegistration) {
              await context.read<ActiveBusinessCubit>().clear();
              if (!context.mounted) return;
              context.go(AppRoutes.businessWizard);
              return;
            }

            final activeBusinessCubit = context.read<ActiveBusinessCubit>();
            await activeBusinessCubit.load().timeout(
              const Duration(seconds: 8),
              onTimeout: () {},
            );
            if (!context.mounted) return;
            final hasNoBusiness =
                activeBusinessCubit.state.status == ActiveBusinessStatus.empty;
            context.go(
              hasNoBusiness
                  ? AppRoutes.businessWizard
                  : AppRoutes.businessDashboard,
            );
            return;
          }

          context.go(
            role.name == 'delivery'
                ? AppRoutes.deliveryDashboard
                : AppRoutes.home,
          );
        }

        if ((state.status == AuthStatus.failure ||
                state.status == AuthStatus.recoverySent) &&
            state.errorMessage != null) {
          _navigatingAfterAuth = false;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
      builder: (context, state) {
        final isLoading = state.status == AuthStatus.loading;

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                _BrandHeader(
                  onGuest: isLoading ? null : () => _continueAsGuest(),
                ),
                const SizedBox(height: 22),
                _AuthCard(
                  mode: _mode,
                  role: _role,
                  formKey: _formKey,
                  nameController: _nameController,
                  phoneController: _phoneController,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  deliveryVehicleType: _deliveryVehicleType,
                  deliveryPlateController: _deliveryPlateController,
                  deliveryCapacityController: _deliveryCapacityController,
                  deliveryBaseFareController: _deliveryBaseFareController,
                  deliveryKmFareController: _deliveryKmFareController,
                  deliveryRadiusController: _deliveryRadiusController,
                  deliveryAcceptsTransfer: _deliveryAcceptsTransfer,
                  showPassword: _showPassword,
                  isLoading: isLoading,
                  onModeChanged: (mode) => setState(() => _mode = mode),
                  onRoleChanged: (role) => setState(() => _role = role),
                  onDeliveryVehicleChanged: (value) =>
                      setState(() => _deliveryVehicleType = value),
                  onDeliveryAcceptsTransferChanged: (value) =>
                      setState(() => _deliveryAcceptsTransfer = value),
                  onTogglePassword: () =>
                      setState(() => _showPassword = !_showPassword),
                  onSubmit: () => _submit(context),
                  onGoogle: isLoading
                      ? null
                      : () => context.read<AuthCubit>().loginWithGoogle(),
                ),
                const SizedBox(height: 16),
                _RecoveryCard(
                  formKey: _recoveryFormKey,
                  controller: _recoveryEmailController,
                  isLoading: isLoading,
                  onSubmit: () => _recover(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<AuthCubit>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName = _nameController.text.trim();

    if (_mode == _AuthMode.login) {
      cubit.loginWithEmail(email: email, password: password);
      return;
    }

    cubit.register(
      fullName: fullName,
      email: email,
      password: password,
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      role: switch (_role) {
        _RegisterRole.business => 'admin_negocio',
        _RegisterRole.delivery => 'delivery',
        _RegisterRole.client => 'cliente',
      },
      deliveryProfile: _role == _RegisterRole.delivery
          ? {
              'tipo_vehiculo': _deliveryVehicleType,
              'placa': _deliveryPlateController.text.trim().isEmpty
                  ? null
                  : _deliveryPlateController.text.trim(),
              'capacidad_carga': _deliveryCapacityController.text.trim().isEmpty
                  ? null
                  : _deliveryCapacityController.text.trim(),
              'tarifa_base': _parseDouble(_deliveryBaseFareController.text),
              'tarifa_por_km': _parseDouble(_deliveryKmFareController.text),
              'radio_operacion_km': _parseDouble(
                _deliveryRadiusController.text,
                fallback: 8,
              ),
              'acepta_transferencia': _deliveryAcceptsTransfer,
            }
          : null,
    );
  }

  void _recover(BuildContext context) {
    if (!_recoveryFormKey.currentState!.validate()) return;
    context.read<AuthCubit>().recoverPassword(
      email: _recoveryEmailController.text.trim(),
    );
  }

  Future<void> _continueAsGuest() async {
    await context.read<AppSessionCubit>().continueAsGuest();
    if (!mounted) return;
    context.go(AppRoutes.home);
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onGuest});

  final VoidCallback? onGuest;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.charcoal : AppColors.ink,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CubNexLogo(size: 56),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CubNex',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    Text(
                      'CONECTA',
                      style: TextStyle(
                        color: AppColors.greenLight,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Innovacion neural al mercado cubano para clientes y negocios.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onGuest,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
            ),
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Explorar como invitado'),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.mode,
    required this.role,
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.passwordController,
    required this.deliveryVehicleType,
    required this.deliveryPlateController,
    required this.deliveryCapacityController,
    required this.deliveryBaseFareController,
    required this.deliveryKmFareController,
    required this.deliveryRadiusController,
    required this.deliveryAcceptsTransfer,
    required this.showPassword,
    required this.isLoading,
    required this.onModeChanged,
    required this.onRoleChanged,
    required this.onDeliveryVehicleChanged,
    required this.onDeliveryAcceptsTransferChanged,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onGoogle,
  });

  final _AuthMode mode;
  final _RegisterRole role;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String deliveryVehicleType;
  final TextEditingController deliveryPlateController;
  final TextEditingController deliveryCapacityController;
  final TextEditingController deliveryBaseFareController;
  final TextEditingController deliveryKmFareController;
  final TextEditingController deliveryRadiusController;
  final bool deliveryAcceptsTransfer;
  final bool showPassword;
  final bool isLoading;
  final ValueChanged<_AuthMode> onModeChanged;
  final ValueChanged<_RegisterRole> onRoleChanged;
  final ValueChanged<String> onDeliveryVehicleChanged;
  final ValueChanged<bool> onDeliveryAcceptsTransferChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback? onGoogle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              SegmentedButton<_AuthMode>(
                segments: const [
                  ButtonSegment(value: _AuthMode.login, label: Text('Login')),
                  ButtonSegment(
                    value: _AuthMode.register,
                    label: Text('Registro'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: isLoading
                    ? null
                    : (value) => onModeChanged(value.first),
              ),
              if (mode == _AuthMode.register) ...[
                const SizedBox(height: 16),
                _RegisterRoleSelector(
                  role: role,
                  enabled: !isLoading,
                  onChanged: onRoleChanged,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) =>
                      mode == _AuthMode.register &&
                          (value == null || value.trim().isEmpty)
                      ? 'Escribe tu nombre completo'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Telefono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                if (role == _RegisterRole.delivery) ...[
                  const SizedBox(height: 14),
                  _DeliveryProfileFields(
                    vehicleType: deliveryVehicleType,
                    plateController: deliveryPlateController,
                    capacityController: deliveryCapacityController,
                    baseFareController: deliveryBaseFareController,
                    kmFareController: deliveryKmFareController,
                    radiusController: deliveryRadiusController,
                    acceptsTransfer: deliveryAcceptsTransfer,
                    enabled: !isLoading,
                    onVehicleChanged: onDeliveryVehicleChanged,
                    onAcceptsTransferChanged: onDeliveryAcceptsTransferChanged,
                  ),
                ],
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: passwordController,
                obscureText: !showPassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!isLoading) onSubmit();
                },
                decoration: InputDecoration(
                  labelText: 'Contrasena',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: showPassword
                        ? 'Ocultar contrasena'
                        : 'Mostrar contrasena',
                    onPressed: isLoading ? null : onTogglePassword,
                    icon: Icon(
                      showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: isLoading ? null : onSubmit,
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(mode == _AuthMode.login ? 'Entrar' : 'Crear cuenta'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onGoogle,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                label: const Text('Continuar con Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterRoleSelector extends StatelessWidget {
  const _RegisterRoleSelector({
    required this.role,
    required this.enabled,
    required this.onChanged,
  });

  final _RegisterRole role;
  final bool enabled;
  final ValueChanged<_RegisterRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _RoleChoice(
          selected: role == _RegisterRole.client,
          enabled: enabled,
          icon: Icons.person_outline,
          label: 'Cliente',
          onSelected: () => onChanged(_RegisterRole.client),
        ),
        _RoleChoice(
          selected: role == _RegisterRole.business,
          enabled: enabled,
          icon: Icons.storefront_outlined,
          label: 'Negocio',
          onSelected: () => onChanged(_RegisterRole.business),
        ),
        _RoleChoice(
          selected: role == _RegisterRole.delivery,
          enabled: enabled,
          icon: Icons.delivery_dining_outlined,
          label: 'Delivery',
          onSelected: () => onChanged(_RegisterRole.delivery),
        ),
      ],
    );
  }
}

class _RoleChoice extends StatelessWidget {
  const _RoleChoice({
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      selected: selected,
      onSelected: enabled ? (_) => onSelected() : null,
      avatar: Icon(
        selected ? Icons.check_rounded : icon,
        size: 18,
        color: selected ? scheme.onPrimaryContainer : scheme.primary,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w900,
        color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
      ),
      selectedColor: scheme.primaryContainer,
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      side: BorderSide(
        color: selected
            ? scheme.primary.withValues(alpha: 0.55)
            : scheme.outline.withValues(alpha: 0.35),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }
}

class _DeliveryProfileFields extends StatelessWidget {
  const _DeliveryProfileFields({
    required this.vehicleType,
    required this.plateController,
    required this.capacityController,
    required this.baseFareController,
    required this.kmFareController,
    required this.radiusController,
    required this.acceptsTransfer,
    required this.enabled,
    required this.onVehicleChanged,
    required this.onAcceptsTransferChanged,
  });

  final String vehicleType;
  final TextEditingController plateController;
  final TextEditingController capacityController;
  final TextEditingController baseFareController;
  final TextEditingController kmFareController;
  final TextEditingController radiusController;
  final bool acceptsTransfer;
  final bool enabled;
  final ValueChanged<String> onVehicleChanged;
  final ValueChanged<bool> onAcceptsTransferChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.22),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Perfil de delivery',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: vehicleType,
              decoration: const InputDecoration(
                labelText: 'Tipo de vehiculo',
                prefixIcon: Icon(Icons.two_wheeler_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'bicicleta', child: Text('Bicicleta')),
                DropdownMenuItem(value: 'motorina', child: Text('Motorina')),
                DropdownMenuItem(value: 'moto', child: Text('Moto')),
                DropdownMenuItem(value: 'triciclo', child: Text('Triciclo')),
                DropdownMenuItem(value: 'auto', child: Text('Auto')),
                DropdownMenuItem(value: 'camioneta', child: Text('Camioneta')),
                DropdownMenuItem(value: 'camion', child: Text('Camion')),
              ],
              onChanged: enabled
                  ? (value) {
                      if (value != null) onVehicleChanged(value);
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: plateController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Placa o identificacion',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: capacityController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Capacidad de carga',
                hintText: 'Ej: hasta 20 kg, caja pequena',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: baseFareController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Tarifa base',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: _validateOptionalNumber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: kmFareController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Por km',
                      prefixIcon: Icon(Icons.route_outlined),
                    ),
                    validator: _validateOptionalNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: radiusController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Radio de operacion (km)',
                prefixIcon: Icon(Icons.radar_outlined),
              ),
              validator: _validatePositiveNumber,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: acceptsTransfer,
              title: const Text('Acepto pagos por transferencia'),
              subtitle: const Text(
                'Los negocios y clientes podran verlo al solicitar entregas.',
              ),
              onChanged: enabled ? onAcceptsTransferChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({
    required this.formKey,
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Restablecer contrasena',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Usa el mismo email de tu cuenta cliente o negocio.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'correo@dominio.com',
                      ),
                      validator: _validateEmail,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: isLoading ? null : onSubmit,
                    child: const Text('Enviar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Escribe tu email';
  }
  if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
    return 'Email invalido';
  }
  return null;
}

String? _validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) {
    return 'Escribe tu contrasena';
  }
  if (password.length < 6) {
    return 'Minimo 6 caracteres';
  }
  return null;
}

String? _validateOptionalNumber(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (double.tryParse(text.replaceAll(',', '.')) == null) {
    return 'Numero invalido';
  }
  return null;
}

String? _validatePositiveNumber(String? value) {
  final text = (value ?? '').trim();
  final number = double.tryParse(text.replaceAll(',', '.'));
  if (number == null || number <= 0) {
    return 'Debe ser mayor que 0';
  }
  return null;
}

double _parseDouble(String value, {double fallback = 0}) {
  return double.tryParse(value.trim().replaceAll(',', '.')) ?? fallback;
}
