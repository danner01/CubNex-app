import 'package:cubnex_app/app/modules/delivery/data/stores/delivery_manual_route_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _primera = DeliveryManualRoute(
  name: 'Ruta 01/01 10:00',
  points: [
    [-82.3666, 23.1136],
    [-82.3667, 23.1137],
  ],
);

const _segunda = DeliveryManualRoute(
  name: 'Ruta 02/02 11:30',
  points: [
    [-82.36, 23.11],
    [-82.35, 23.12],
    [-82.34, 23.13],
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load devuelve una lista modificable aunque este vacia', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final routes = await DeliveryManualRouteStore.load();
    expect(routes, isEmpty);

    // Reproduce el fallo P7: _saveManualRoute hace routes.add(...) sobre load().
    routes.add(_primera);
    expect(routes.length, 1);
  });

  test('la primera ruta manual se guarda y se puede leer de vuelta', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final routes = await DeliveryManualRouteStore.load()..add(_primera);
    expect(await DeliveryManualRouteStore.save(routes), isTrue);

    final stored = await DeliveryManualRouteStore.load();
    expect(stored.length, 1);
    expect(stored.first.name, _primera.name);
    expect(stored.first.points.length, _primera.points.length);
  });

  test('acumula varias rutas y permite borrar una', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final routes = await DeliveryManualRouteStore.load()
      ..add(_primera)
      ..add(_segunda);
    expect(await DeliveryManualRouteStore.save(routes), isTrue);

    final stored = await DeliveryManualRouteStore.load();
    expect(stored.map((item) => item.name), containsAll(<String>[_primera.name, _segunda.name]));

    final sinSegunda = stored.where((item) => item.name != _segunda.name).toList();
    expect(await DeliveryManualRouteStore.save(sinSegunda), isTrue);
    expect((await DeliveryManualRouteStore.load()).single.name, _primera.name);
  });

  test('descarta puntos invalidos al leer y no rompe el guardado', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'delivery_rutas_manuales':
          '[{"nombre":"Rota rota","puntos":[[1]]},'
              '{"nombre":"Buena","puntos":[[-82.3,23.1],[-82.2,23.2]]},'
              '{"nombre":"Sin puntos","puntos":[]},'
              '{"sin_nombre":true}]',
    });

    final stored = await DeliveryManualRouteStore.load();
    expect(stored.length, 1);
    expect(stored.single.name, 'Buena');
    expect(await DeliveryManualRouteStore.save(stored), isTrue);
  });

  test('un documento corrupto no borra lo recien guardado', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'delivery_rutas_manuales': 'esto no es json',
    });

    final stored = await DeliveryManualRouteStore.load();
    expect(stored, isEmpty);

    final routes = stored..add(_primera);
    expect(await DeliveryManualRouteStore.save(routes), isTrue);
    expect((await DeliveryManualRouteStore.load()).single.name, _primera.name);
  });
}
