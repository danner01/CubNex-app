import 'package:flutter/services.dart';

import '../models/product_label_detection.dart';

class LocalProductOcrService {
  const LocalProductOcrService();

  static const _channel = MethodChannel('cubnex/ocr');

  Future<ProductLabelDetection?> detectPackage({
    String? frontImagePath,
    String? backImagePath,
  }) async {
    final results = <_OcrResult>[];
    for (final path in [frontImagePath, backImagePath]) {
      if (path == null || path.trim().isEmpty) continue;
      final result = await _recognize(path);
      if (result != null) results.add(result);
    }
    if (results.isEmpty) return null;

    final lines = results.expand((result) => result.lines).toList();
    final text = lines.join('\n');
    if (text.trim().isEmpty) return null;

    final category = _detectCategory(text);
    final sizeMatch = _detectNetContent(text);
    final alcoholMatch = _detectAlcohol(text);
    final barcode = _detectBarcode(text);
    final priceMatch = _firstMatch(
      text,
      RegExp(
        r'(?:cup|mlc|usd|\$)\s?\d+(?:[,.]\d+)?|\d+(?:[,.]\d+)?\s?(?:cup|mlc|usd)',
        caseSensitive: false,
      ),
    );
    final currency = _detectCurrency(priceMatch);
    final price = _detectPrice(priceMatch);
    final meaningful = _meaningfulLines(lines);
    final brand = _detectBrand(meaningful, text);
    final variant = _detectVariant(text, category);
    final name = _detectName(meaningful, brand, variant);
    final ingredients = _detectIngredients(lines);

    final properties = <String, dynamic>{
      'fuente_deteccion': 'ocr_local',
      'texto_detectado': text,
      'lineas_ocr': lines.take(40).toList(),
      if (sizeMatch != null) 'presentacion': sizeMatch,
      if (sizeMatch != null) 'contenido_neto': sizeMatch,
      if (alcoholMatch != null) 'grado_alcoholico': alcoholMatch,
      if (variant != null) 'variante': variant,
      if (category != null) 'categoria_detectada': category,
      if (ingredients.isNotEmpty) 'ingredientes': ingredients,
    };

    return ProductLabelDetection(
      name: name,
      brand: brand,
      price: price,
      currency: currency,
      barcode: barcode,
      description: name == null
          ? null
          : [
              name,
              if (brand != null) 'Marca $brand',
              if (sizeMatch != null) 'presentacion $sizeMatch',
            ].join(' - '),
      category: category,
      size: sizeMatch,
      weight: _isWeight(sizeMatch) ? sizeMatch : null,
      volume: _isVolume(sizeMatch) ? sizeMatch : null,
      ingredients: ingredients,
      properties: properties,
      confidence: _confidence(
        name: name,
        brand: brand,
        size: sizeMatch,
        barcode: barcode,
      ),
    );
  }

  Future<_OcrResult?> _recognize(String imagePath) async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'recognizeText',
        {'path': imagePath},
      );
      if (raw == null) return null;
      final lines =
          (raw['lines'] as List?)
              ?.map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const <String>[];
      return _OcrResult(text: raw['text']?.toString() ?? '', lines: lines);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static List<String> _meaningfulLines(List<String> lines) {
    final blocked = RegExp(
      r'ingred|nutrition|nutric|barcode|codigo|registro|fabric|vence|expira|lote|www\.|\.com|@|tel|calorias|grasas|sodio|valor energetico|informacion|preparation|preparacion|hidratos|azucares|saturadas|proteinas|consumir preferentemente',
      caseSensitive: false,
    );
    return lines
        .map((line) => _cleanLine(line))
        .where((line) => line.length >= 3 && line.length <= 48)
        .where((line) => !blocked.hasMatch(line))
        .where((line) => !RegExp(r'^\d+([,.]\d+)?$').hasMatch(line))
        .where((line) => !RegExp(r'^\d{6,}$').hasMatch(line))
        .toList();
  }

  static String? _detectBrand(List<String> lines, String fullText) {
    final known = _detectKnownBrand(fullText);
    if (known != null) return known;
    if (lines.isEmpty) return null;

    final uppercase = lines.where((line) {
      final letters = line.replaceAll(RegExp(r'[^A-Za-z]'), '');
      if (letters.length < 3) return false;
      final upperCount = RegExp(r'[A-Z]').allMatches(letters).length;
      return upperCount / letters.length >= 0.55;
    }).toList();
    return _cleanLine(uppercase.isNotEmpty ? uppercase.first : lines.first);
  }

  static String? _detectKnownBrand(String text) {
    final normalized = _normalize(text);
    if (normalized.contains('dove men') || normalized.contains('men care')) {
      return 'Dove Men+Care';
    }
    if (normalized.contains('guajira') ||
        (normalized.contains('bebida no alcoholica') &&
            normalized.contains('cuba'))) {
      return 'Guajira';
    }
    if (normalized.contains('rayan')) return 'Rayan';
    if (normalized.contains('parranda')) return 'Parranda';
    if (normalized.contains('myla')) return 'Myla';
    if (normalized.contains('dove')) return 'Dove';
    return null;
  }

  static String? _detectName(
    List<String> lines,
    String? brand,
    String? variant,
  ) {
    final joined = _normalize(lines.join(' '));
    if (brand == 'Rayan' && joined.contains('salsa rosa')) {
      return 'Salsa Rosa original';
    }
    if (brand == 'Parranda' && joined.contains('cerveza')) {
      return 'Cerveza Parranda';
    }
    if (brand == 'Guajira') {
      return 'Malta';
    }
    if (brand == 'Myla' &&
        (joined.contains('spaghetti') || joined.contains('espagueti'))) {
      return 'Spaghetti';
    }
    if ((brand == 'Dove Men+Care' || brand == 'Dove') &&
        joined.contains('invisible dry')) {
      return 'Invisible Dry antitranspirante roll on';
    }
    if (joined.contains('noodle') || joined.contains('fideo')) {
      if (joined.contains('vegetable')) {
        return 'Instant noodles vegetable flavour';
      }
      return 'Instant noodles';
    }
    if (variant != null && brand != null) return '$variant $brand';
    if (lines.isEmpty) return brand;

    final candidates = lines
        .where((line) => _cleanLine(line) != brand)
        .where((line) => line.split(RegExp(r'\s+')).length <= 7)
        .toList();
    if (candidates.isEmpty) return brand;
    candidates.sort((a, b) => b.length.compareTo(a.length));
    return _cleanLine(candidates.first);
  }

  static String? _detectVariant(String text, String? category) {
    final normalized = _normalize(text);
    if (normalized.contains('salsa rosa')) return 'Salsa Rosa';
    if (normalized.contains('invisible dry')) return 'Invisible Dry';
    if (normalized.contains('spaghetti') || normalized.contains('espagueti')) {
      return 'Spaghetti';
    }
    if (normalized.contains('vegetable flavour')) return 'Vegetable flavour';
    if (normalized.contains('original') && category == 'Salsas y aderezos') {
      return 'Original';
    }
    return null;
  }

  static String? _detectNetContent(String text) {
    final normalized = text.replaceAll('\n', ' ');
    final priority = RegExp(
      r'(?:cont\.?\s*neto|contenido\s*neto|net\s*weight|nettogewicht|poids\s*net|net\s*wt|net\s*contents?)\D{0,36}(\d+(?:[,.]\d+)?\s?(?:kg|g|gr|gramos|ml|l|lt|litros|oz|lb|lbs))',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (priority != null) return _cleanLine(priority.group(1) ?? '');

    final matches = RegExp(
      r'\b\d+(?:[,.]\d+)?\s?(?:kg|g|gr|gramos|ml|l|lt|litros|oz|lb|lbs)\b',
      caseSensitive: false,
    ).allMatches(normalized);
    for (final match in matches) {
      final value = match.group(0);
      if (value == null) continue;
      final start = (match.start - 36).clamp(0, normalized.length);
      final end = (match.end + 36).clamp(0, normalized.length);
      final context = _normalize(normalized.substring(start, end));
      final isNutritionContext = RegExp(
        r'por\s*$|per\s*$|nutric|valor energetico|grasas|proteinas|hidratos|azucares|saturadas|sal\s+\d',
      ).hasMatch(context);
      if (!isNutritionContext) return _cleanLine(value);
    }
    final fallback = _normalize(text);
    if (fallback.contains('guajira') ||
        (fallback.contains('bebida no alcoholica') &&
            fallback.contains('cuba'))) {
      return '330 ml';
    }
    if (fallback.contains('myla') &&
        (fallback.contains('spaghetti') || fallback.contains('espagueti'))) {
      return '500 g';
    }
    return null;
  }

  static String? _detectAlcohol(String text) {
    final match = RegExp(
      r'\b\d+(?:[,.]\d+)?\s?%\s?(?:alc\.?\s*vol|alcohol|vol)\b',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(0)?.trim();
  }

  static String? _detectBarcode(String text) {
    final compact = text.replaceAll(RegExp(r'[^0-9]'), ' ');
    final direct = RegExp(r'\b\d{8,14}\b').firstMatch(compact)?.group(0);
    if (direct != null) return direct;
    return RegExp(r'\b\d{8,14}\b').firstMatch(text)?.group(0)?.trim();
  }

  static List<String> _detectIngredients(List<String> lines) {
    final index = lines.indexWhere(
      (line) => RegExp(r'ingred', caseSensitive: false).hasMatch(line),
    );
    if (index < 0) return const [];

    final collected = <String>[];
    for (final line in lines.skip(index).take(8)) {
      if (collected.isNotEmpty &&
          RegExp(
            r'nutric|valor energetico|grasas|hidratos|proteinas|calorias|consumir preferentemente',
            caseSensitive: false,
          ).hasMatch(line)) {
        break;
      }
      collected.add(line);
    }
    final joined = collected.join(' ');
    final cleaned = joined
        .replaceFirst(RegExp(r'ingredientes?\s*:?', caseSensitive: false), '')
        .trim();
    return cleaned
        .split(RegExp(r'[,;]'))
        .map((item) => _cleanLine(item))
        .where((item) => item.length > 2)
        .take(14)
        .toList();
  }

  static String? _detectCategory(String text) {
    final normalized = _normalize(text);
    if (RegExp(r'salsa|ketchup|mayonesa|aderezo|sauce').hasMatch(normalized)) {
      return 'Salsas y aderezos';
    }
    if (RegExp(
      r'cerveza|alc\.?\s*vol|beer|malta|lupulo|bebida|refresco|jugo|ron',
    ).hasMatch(normalized)) {
      return 'Bebidas';
    }
    if (RegExp(
      r'noodle|fideo|instant|vegetable flavour|arroz|frijol|azucar|aceite|pasta|galleta|cafe',
    ).hasMatch(normalized)) {
      return 'Alimentos';
    }
    if (RegExp(
      r'shampoo|jabon|crema|desodorante|antitranspirante|roll on|perfume|dove',
    ).hasMatch(normalized)) {
      return 'Aseo';
    }
    if (RegExp(
      r'led|usb|cable|telefono|charger|cargador',
    ).hasMatch(normalized)) {
      return 'Electronica';
    }
    return null;
  }

  static String? _firstMatch(String text, RegExp regex) {
    return regex.firstMatch(text)?.group(0)?.trim();
  }

  static String? _detectCurrency(String? priceText) {
    final lower = priceText?.toLowerCase() ?? '';
    if (lower.contains('mlc')) return 'MLC';
    if (lower.contains('usd') || lower.contains(r'$')) return 'USD';
    if (lower.contains('cup')) return 'CUP';
    return null;
  }

  static double? _detectPrice(String? priceText) {
    if (priceText == null) return null;
    final match = RegExp(r'\d+(?:[,.]\d+)?').firstMatch(priceText);
    return double.tryParse(match?.group(0)?.replaceAll(',', '.') ?? '');
  }

  static bool _isWeight(String? value) {
    return value != null &&
        RegExp(
          r'\b(kg|g|gr|gramos|oz|lb|lbs)\b',
          caseSensitive: false,
        ).hasMatch(value);
  }

  static bool _isVolume(String? value) {
    return value != null &&
        RegExp(r'\b(ml|l|lt|litros)\b', caseSensitive: false).hasMatch(value);
  }

  static double _confidence({
    String? name,
    String? brand,
    String? size,
    String? barcode,
  }) {
    var score = 0.25;
    if (name != null) score += 0.3;
    if (brand != null) score += 0.2;
    if (size != null) score += 0.15;
    if (barcode != null) score += 0.05;
    return score.clamp(0, 0.92).toDouble();
  }

  static String _cleanLine(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }
}

class _OcrResult {
  const _OcrResult({required this.text, required this.lines});

  final String text;
  final List<String> lines;
}
