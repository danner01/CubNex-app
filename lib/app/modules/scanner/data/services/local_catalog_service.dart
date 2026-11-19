import 'package:hive_flutter/hive_flutter.dart';

import '../../../../config/http/api_client.dart';
import '../../../business/data/models/product_label_detection.dart';
import '../../../home/data/models/product_model.dart';

/// Producto del catalogo local (cache offline) con lo minimo para machear.
class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.name,
    this.brand,
    this.barcode,
    this.sku,
    this.imageUrl,
    this.price,
    this.currency,
    this.businessName,
  });

  final String id;
  final String name;
  final String? brand;
  final String? barcode;
  final String? sku;
  final String? imageUrl;
  final double? price;
  final String? currency;
  final String? businessName;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'brand': brand,
    'barcode': barcode,
    'sku': sku,
    'imageUrl': imageUrl,
    'price': price,
    'currency': currency,
    'businessName': businessName,
  };

  factory CatalogEntry.fromMap(Map<dynamic, dynamic> map) => CatalogEntry(
    id: map['id'].toString(),
    name: (map['name'] ?? '').toString(),
    brand: map['brand']?.toString(),
    barcode: map['barcode']?.toString(),
    sku: map['sku']?.toString(),
    imageUrl: map['imageUrl']?.toString(),
    price: (map['price'] as num?)?.toDouble(),
    currency: map['currency']?.toString(),
    businessName: map['businessName']?.toString(),
  );

  factory CatalogEntry.fromProduct(ProductModel p) => CatalogEntry(
    id: p.id,
    name: p.displayName,
    brand: p.brand,
    barcode: p.barcode,
    sku: p.sku,
    imageUrl: p.imageUrl,
    price: p.price,
    currency: p.currency,
    businessName: p.businessName,
  );
}

class CatalogMatch {
  const CatalogMatch({required this.entry, required this.score});

  final CatalogEntry entry;
  final double score;
}

/// Catalogo de productos guardado en el dispositivo. Permite identificar un
/// producto escaneado (texto OCR + codigo de barras) sin conexion.
class LocalCatalogService {
  LocalCatalogService();

  static const _boxName = 'product_catalog';
  static const _metaKey = '__meta_synced_at';
  static const _pageSize = 200;
  static const _maxProducts = 2000;
  static const _staleAfter = Duration(hours: 6);
  static const minScore = 0.45;

  List<CatalogEntry>? _memory;

  Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<dynamic>(_boxName);
    return Hive.openBox<dynamic>(_boxName);
  }

  Future<List<CatalogEntry>> _load() async {
    final cached = _memory;
    if (cached != null) return cached;
    final box = await _box();
    final entries = <CatalogEntry>[];
    for (final key in box.keys) {
      if (key == _metaKey) continue;
      final value = box.get(key);
      if (value is Map) entries.add(CatalogEntry.fromMap(value));
    }
    return _memory = entries;
  }

  /// Descarga el catalogo si esta vencido. Nunca lanza: sin red conserva la cache.
  Future<void> syncIfStale(ApiClient api, {bool force = false}) async {
    try {
      final box = await _box();
      final last = DateTime.tryParse(box.get(_metaKey)?.toString() ?? '');
      final fresh =
          last != null && DateTime.now().difference(last) < _staleAfter;
      if (fresh && !force && box.length > 1) return;

      final all = <CatalogEntry>[];
      for (var offset = 0; offset < _maxProducts; offset += _pageSize) {
        final result = await api.get<List<ProductModel>>(
          '/productos',
          queryParameters: {'limit': _pageSize, 'offset': offset},
          parser: (json) => json is List
              ? json
                    .whereType<Map>()
                    .map(
                      (e) =>
                          ProductModel.fromJson(Map<String, dynamic>.from(e)),
                    )
                    .toList()
              : <ProductModel>[],
          timeout: const Duration(seconds: 15),
        );
        if (!result.isSuccess) break;
        final page = result.data ?? const <ProductModel>[];
        all.addAll(page.map(CatalogEntry.fromProduct));
        if (page.length < _pageSize) break;
      }
      if (all.isEmpty) return;

      await box.clear();
      await box.putAll({for (final e in all) e.id: e.toMap()});
      await box.put(_metaKey, DateTime.now().toIso8601String());
      _memory = all;
    } catch (_) {}
  }

  /// Macheo local: codigo de barras/SKU exacto, o solapamiento de palabras
  /// entre el texto reconocido y el nombre/marca del producto.
  Future<List<CatalogMatch>> match(
    ProductLabelDetection detection, {
    int limit = 5,
  }) async {
    final catalog = await _load();
    if (catalog.isEmpty) return const [];

    final barcode = _digits(detection.barcode);
    final ocrText = (detection.properties['texto_detectado'] ?? '').toString();
    final haystack = _tokens(
      [
        detection.name,
        detection.brand,
        detection.category,
        detection.size,
        ocrText,
      ].whereType<String>().join(' '),
    ).toSet();
    final digitsInText = RegExp(r'\d{6,14}')
        .allMatches(ocrText)
        .map((m) => m.group(0)!)
        .toSet();

    final matches = <CatalogMatch>[];
    for (final entry in catalog) {
      final code = _digits(entry.barcode);
      final sku = _digits(entry.sku);
      if (code.length >= 8 &&
          (code == barcode || digitsInText.contains(code))) {
        matches.add(CatalogMatch(entry: entry, score: 1));
        continue;
      }
      if (sku.length >= 6 && digitsInText.contains(sku)) {
        matches.add(CatalogMatch(entry: entry, score: 0.95));
        continue;
      }
      final nameTokens = _tokens(entry.name);
      if (nameTokens.isEmpty || haystack.isEmpty) continue;
      var total = 0.0;
      var matched = 0.0;
      for (final t in nameTokens) {
        final weight = t.length >= 5 ? 1.5 : 1.0;
        total += weight;
        if (_present(t, haystack)) matched += weight;
      }
      if (matched == 0) continue;
      var score = matched / total;
      final brandTokens = _tokens(entry.brand ?? '');
      if (brandTokens.isNotEmpty &&
          brandTokens.every((t) => _present(t, haystack))) {
        score = (score + 0.2).clamp(0, 0.94).toDouble();
      }
      if (score >= minScore) {
        matches.add(CatalogMatch(entry: entry, score: score));
      }
    }
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(limit).toList();
  }

  static bool _present(String token, Set<String> haystack) {
    if (haystack.contains(token)) return true;
    if (token.length < 5) return false;
    // tolera errores tipicos de OCR (una letra de diferencia)
    for (final h in haystack) {
      if ((h.length - token.length).abs() <= 1 &&
          _editDistanceAtMost1(h, token)) {
        return true;
      }
    }
    return false;
  }

  static bool _editDistanceAtMost1(String a, String b) {
    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length > b.length) {
        i++;
      } else if (a.length < b.length) {
        j++;
      } else {
        i++;
        j++;
      }
    }
    return edits + (a.length - i) + (b.length - j) <= 1;
  }

  static String _digits(String? value) =>
      (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');

  static const _stop = {
    'de', 'del', 'la', 'el', 'los', 'las', 'con', 'sin', 'para', 'por',
    'en', 'y', 'a', 'un', 'una', 'the', 'and', 'of',
  };

  static List<String> _tokens(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return normalized
        .split(' ')
        .where((t) => t.length >= 2 && !_stop.contains(t))
        .toList();
  }
}
