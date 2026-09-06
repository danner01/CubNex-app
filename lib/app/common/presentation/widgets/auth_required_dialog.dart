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
        title: const Text('Acceso requerido'),
        content: const Text(
          'Esta función requiere una cuenta y un plan activo para el negocio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (context.mounted) {
                context.go(AppRoutes.businessWizard);
              }
            },
            child: const Text('Ver planes'),
          ),
        ],
      );
    },
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
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(resolvedMessage)));
}
