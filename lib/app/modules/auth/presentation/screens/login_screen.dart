import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

enum _RegisterRole { client, business }

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
  _AuthMode _mode = _AuthMode.login;
  _RegisterRole _role = _RegisterRole.client;
  bool _showPassword = false;
  bool _navigatingAfterAuth = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _recoveryEmailController.dispose();
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
          await context
              .read<AppSessionCubit>()
              .setSession(state.session!)
              .timeout(const Duration(seconds: 5), onTimeout: () {});
          if (!context.mounted) return;
          context.go(
            state.session!.role.name == 'businessAdmin'
                ? AppRoutes.businessDashboard
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
                  showPassword: _showPassword,
                  isLoading: isLoading,
                  onModeChanged: (mode) => setState(() => _mode = mode),
                  onRoleChanged: (role) => setState(() => _role = role),
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
      role: _role == _RegisterRole.business ? 'admin_negocio' : 'cliente',
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
    required this.showPassword,
    required this.isLoading,
    required this.onModeChanged,
    required this.onRoleChanged,
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
  final bool showPassword;
  final bool isLoading;
  final ValueChanged<_AuthMode> onModeChanged;
  final ValueChanged<_RegisterRole> onRoleChanged;
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
                SegmentedButton<_RegisterRole>(
                  segments: const [
                    ButtonSegment(
                      value: _RegisterRole.client,
                      icon: Icon(Icons.person_outline),
                      label: Text('Cliente'),
                    ),
                    ButtonSegment(
                      value: _RegisterRole.business,
                      icon: Icon(Icons.storefront_outlined),
                      label: Text('Negocio'),
                    ),
                  ],
                  selected: {role},
                  onSelectionChanged: isLoading
                      ? null
                      : (value) => onRoleChanged(value.first),
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
