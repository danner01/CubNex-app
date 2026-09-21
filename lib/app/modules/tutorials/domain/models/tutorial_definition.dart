import 'package:flutter/material.dart';

import '../../../../common/blocs/role_mode/role_mode_cubit.dart';

class TutorialStep {
  const TutorialStep({
    required this.titulo,
    required this.descripcion,
    this.icono = Icons.tips_and_updates_outlined,
  });

  final String titulo;
  final String descripcion;
  final IconData icono;
}

class TutorialDefinition {
  const TutorialDefinition({
    required this.id,
    required this.titulo,
    required this.descripcion,
    this.icono = Icons.school_outlined,
    this.modo,
    this.pasos = const [],
    this.rutas = const [],
  });

  final String id;
  final String titulo;
  final String descripcion;
  final IconData icono;

  /// Modo/rol al que pertenece la guia. `null` significa transversal
  /// (disponible para todos los roles).
  final RoleMode? modo;

  final List<TutorialStep> pasos;

  /// Patrones de ruta (ej: `/buscar`, `/product/:id`) que disparan el
  /// autoplay de esta guia al entrar a la vista.
  final List<String> rutas;

  bool get esTransversal => modo == null;

  bool matchesLocation(String location) {
    if (rutas.isEmpty) return false;
    final path = location.split('?').first;
    for (final ruta in rutas) {
      if (ruta == path) return true;
      if (ruta.contains(':')) {
        final pattern = ruta
            .split('/')
            .map(
              (segment) =>
                  segment.startsWith(':') ? r'[^/]+' : RegExp.escape(segment),
            )
            .join('/');
        if (RegExp('^$pattern\$').hasMatch(path)) return true;
      }
    }
    return false;
  }
}
