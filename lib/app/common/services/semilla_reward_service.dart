import 'dart:async';

/// Recompensa que dispara la animacion de la moneda girando.
class SemillaReward {
  const SemillaReward({
    required this.amount,
    this.label = 'Semillas ganadas',
    this.unit = 'semillas',
  });

  final int amount;
  final String? label;
  final String unit;

  bool get esSemilla => unit == 'semillas';
}

/// Emisor global de recompensas. La billetera y la gamificacion lo alimentan y
/// [SemillaRewardHost] lo escucha para mostrar el modal animado.
class SemillaRewardService {
  final _controller = _Broadcaster();
  final _ultimoValor = <String, int>{};
  DateTime _lastShown = DateTime.fromMillisecondsSinceEpoch(0);

  Stream<SemillaReward> get rewards => _controller.stream;

  /// Registra el valor actual del saldo (o de los puntos) y solo emite la
  /// recompensa cuando ese valor crece respecto al registrado. El historial vive
  /// aqui (y no en el cubit) porque algunos cubits son de tipo factory y se
  /// recrean en cada pantalla.
  void showIfIncreased(
    String key,
    int valor, {
    String? label,
    String unit = 'semillas',
  }) {
    final anterior = _ultimoValor[key];
    _ultimoValor[key] = valor;
    if (anterior == null || valor <= anterior) return;
    show(amount: valor - anterior, label: label, unit: unit);
  }

  void show({required int amount, String? label, String unit = 'semillas'}) {
    if (amount == 0) return;
    final now = DateTime.now();
    // Evita repetir la animacion si varias cargas devuelven el mismo incremento.
    if (now.difference(_lastShown) < const Duration(milliseconds: 1500)) return;
    _lastShown = now;
    _controller.add(
      SemillaReward(amount: amount.abs(), label: label, unit: unit),
    );
  }

  void dispose() => _controller.close();
}

/// Wrapper minimo para poder cerrar el broadcast controller.
class _Broadcaster {
  final _controller = StreamController<SemillaReward>.broadcast();
  Stream<SemillaReward> get stream => _controller.stream;
  void add(SemillaReward value) {
    if (!_controller.isClosed) _controller.add(value);
  }
  void close() => _controller.close();
}
