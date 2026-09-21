import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/tutorial_catalog.dart';
import '../domain/models/tutorial_definition.dart';

/// Guarda el progreso de las guias (cuales se vieron y cuales el usuario
/// decidio no ver) y detecta la guia que debe ofrecerse al entrar a una
/// vista mediante autoplay.
class TutorialProgressStore {
  TutorialProgressStore({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  static const _seenKey = 'tutorials.seen.v1';
  static const _dismissedKey = 'tutorials.dismissed.v1';

  final SharedPreferences _sharedPreferences;

  /// Guia lista para ofrecerse en la vista actual (autoplay).
  final ValueNotifier<TutorialDefinition?> pendingOffer =
      ValueNotifier<TutorialDefinition?>(null);

  /// Se incrementa cuando cambia el progreso (visto/descartado), util para
  /// refrescar pantallas que muestran el estado de las guias.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Set<String> _seen = <String>{};
  Set<String> _dismissed = <String>{};
  GoRouter? _router;
  bool _attached = false;
  bool _loaded = false;

  Future<void> load() async {
    _seen = (_sharedPreferences.getStringList(_seenKey) ?? const []).toSet();
    _dismissed = (_sharedPreferences.getStringList(_dismissedKey) ?? const [])
        .toSet();
    _loaded = true;
    revision.value++;
    _onRouteChanged();
  }

  /// Conecta el store al router para detectar entradas a vistas con guia.
  void attachRouter(GoRouter router) {
    if (_attached && identical(_router, router)) return;
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _router = router;
    router.routerDelegate.addListener(_onRouteChanged);
    _attached = true;
    _onRouteChanged();
  }

  void _onRouteChanged() {
    final router = _router;
    if (router == null) return;
    String? location;
    try {
      location = router.state.matchedLocation;
    } catch (_) {
      // El router aun no ha completado su primera navegacion (lista de
      // matches vacia); al navegar volvera a notificar con estado real.
      return;
    }
    if (location.isEmpty) return;
    registerLocation(location);
  }

  bool isSeen(String id) => _seen.contains(id);

  bool isSkipped(String id) => _dismissed.contains(id);

  /// Solo se ofrece la guia si aun no se vio ni se descarto.
  bool shouldOffer(String id) => !isSeen(id) && !isSkipped(id);

  Future<void> markSeen(String id) async {
    if (!_seen.add(id)) return;
    await _persist(_seenKey, _seen);
    revision.value++;
  }

  /// El usuario decidio no ver la guia en el autoplay.
  Future<void> markSkipped(String id) async {
    if (!_dismissed.add(id)) return;
    await _persist(_dismissedKey, _dismissed);
    revision.value++;
  }

  Future<void> clearPending() async {
    if (pendingOffer.value == null) return;
    pendingOffer.value = null;
  }

  /// Registra la vista actual. Si tiene una guia no vista aun y no hay una
  /// oferta vigente, la propone como oferta pendiente.
  void registerLocation(String location) {
    if (!_loaded) return;
    final matches = TutorialCatalog.forLocation(location);
    final visibleIds = matches.map((t) => t.id).toSet();
    final pending = pendingOffer.value;

    if (pending != null) {
      if (!visibleIds.contains(pending.id) || !shouldOffer(pending.id)) {
        clearPending();
      }
      return;
    }

    for (final candidate in matches) {
      if (shouldOffer(candidate.id)) {
        pendingOffer.value = candidate;
        return;
      }
    }
  }

  Future<void> _persist(String key, Set<String> values) async {
    await _sharedPreferences.setStringList(key, values.toList(growable: false));
  }
}
