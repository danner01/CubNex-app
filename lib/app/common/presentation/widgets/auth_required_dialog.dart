import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes/app_routes.dart';

bool isAuthRequiredMessage(String? message, {String? code, int? statusCode}) {
  final text = '${message ?? ''} ${code ?? ''}'.toLowerCase();
  return statusCode == 401 ||
      text.contains('auth_required') ||
      text.contains('sin_token') ||
      text.contains('token bearer') ||
      text.contains('bearer') ||
      text.contains('sesion requerida') ||
      text.contains('sesión requerida') ||
      text.contains('no hay sesion') ||
      text.contains('no hay sesión') ||
      text.contains('iniciar sesion') ||
      text.contains('iniciar sesión') ||
      text.contains('registrarte') ||
      text.contains('registrarse');
}

Future<void> showAuthRequiredDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Cuenta requerida'),
        content: const Text(
          'Debes registrarte o iniciar sesión para acceder a esta función.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            child: const Text('Registrarse'),
          ),
        ],
      );
    },
  );
}

bool isPlanRequiredMessage(String? message, {String? code, int? statusCode}) {
  final text = '${message ?? ''} ${code ?? ''}'.toLowerCase();
  return statusCode == 402 ||
      text.contains('plan_premium_requerido') ||
      text.contains('limite_imagenes_plan') ||
      text.contains('plan premium') ||
      text.contains('actualiza a premium') ||
      text.contains('tu plan permite');
}

Future<void> showPlanRequiredDialog(
  BuildContext context,
  String message,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.workspace_premium_outlined),
      title: const Text('Plan del negocio requerido'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            if (context.mounted) context.go(AppRoutes.businessPlans);
          },
          child: const Text('Ver planes'),
        ),
      ],
    ),
  );
}

void showSnackOrAuthDialog(
  BuildContext context,
  String? message, {
  String fallback = 'Accion completada.',
}) {
  final resolvedMessage = message?.isNotEmpty == true ? message! : fallback;
  if (isAuthRequiredMessage(resolvedMessage)) {
    showAuthRequiredDialog(context);
    return;
  }
  if (isPlanRequiredMessage(resolvedMessage)) {
    showPlanRequiredDialog(context, resolvedMessage);
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(resolvedMessage)));
}
