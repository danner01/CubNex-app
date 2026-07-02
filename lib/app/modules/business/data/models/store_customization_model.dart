class StoreCustomizationModel {
  const StoreCustomizationModel({
    this.id,
    required this.businessId,
    this.primaryColor = '#D4AF37',
    this.secondaryColor = '#111512',
    this.accentColor = '#3B82F6',
    this.textColor = '#FFFFFF',
    this.headingTextColor = '#FFFFFF',
    this.secondaryTextColor = '#9CA3AF',
    this.backgroundColor = '#0D0D0D',
    this.fontFamily = 'Inter',
    this.gradientEnabled = false,
    this.gradientStart = '#000000',
    this.gradientEnd = '#1A1A1A',
    this.gradientDirection = 'vertical',
    this.cardStyle = 'grande',
    this.cardRadius = 16,
    this.showDiscount = true,
    this.showRating = true,
    this.showStock = false,
    this.gridColumns = 2,
  });

  final String? id;
  final String businessId;
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String textColor;
  final String headingTextColor;
  final String secondaryTextColor;
  final String backgroundColor;
  final String fontFamily;
  final bool gradientEnabled;
  final String gradientStart;
  final String gradientEnd;
  final String gradientDirection;
  final String cardStyle;
  final int cardRadius;
  final bool showDiscount;
  final bool showRating;
  final bool showStock;
  final int gridColumns;

  StoreCustomizationModel copyWith({
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    String? textColor,
    String? headingTextColor,
    String? secondaryTextColor,
    String? backgroundColor,
    String? fontFamily,
    bool? gradientEnabled,
    String? gradientStart,
    String? gradientEnd,
    String? gradientDirection,
    String? cardStyle,
    int? cardRadius,
    bool? showDiscount,
    bool? showRating,
    bool? showStock,
    int? gridColumns,
  }) {
    return StoreCustomizationModel(
      id: id,
      businessId: businessId,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      textColor: textColor ?? this.textColor,
      headingTextColor: headingTextColor ?? this.headingTextColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontFamily: fontFamily ?? this.fontFamily,
      gradientEnabled: gradientEnabled ?? this.gradientEnabled,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      gradientDirection: gradientDirection ?? this.gradientDirection,
      cardStyle: cardStyle ?? this.cardStyle,
      cardRadius: cardRadius ?? this.cardRadius,
      showDiscount: showDiscount ?? this.showDiscount,
      showRating: showRating ?? this.showRating,
      showStock: showStock ?? this.showStock,
      gridColumns: gridColumns ?? this.gridColumns,
    );
  }

  factory StoreCustomizationModel.fromJson(Map<String, dynamic> json) {
    return StoreCustomizationModel(
      id: json['id']?.toString(),
      businessId: '${json['negocio_id'] ?? ''}',
      primaryColor: '${json['color_primario'] ?? '#D4AF37'}',
      secondaryColor: '${json['color_secundario'] ?? '#111512'}',
      accentColor: '${json['color_acento'] ?? '#3B82F6'}',
      textColor: '${json['color_texto'] ?? '#FFFFFF'}',
      headingTextColor:
          '${json['color_titulo'] ?? json['color_texto'] ?? '#FFFFFF'}',
      secondaryTextColor: '${json['color_texto_secundario'] ?? '#9CA3AF'}',
      backgroundColor: '${json['color_fondo'] ?? '#0D0D0D'}',
      fontFamily: '${json['fuente_tienda'] ?? 'Inter'}',
      gradientEnabled: json['gradiente_habilitado'] == true,
      gradientStart: '${json['gradiente_inicio'] ?? '#000000'}',
      gradientEnd: '${json['gradiente_fin'] ?? '#1A1A1A'}',
      gradientDirection: '${json['gradiente_direccion'] ?? 'vertical'}',
      cardStyle: '${json['tarjeta_estilo'] ?? 'grande'}',
      cardRadius: _int(json['tarjeta_bordes'], fallback: 16),
      showDiscount: json['tarjeta_mostrar_descuento'] != false,
      showRating: json['tarjeta_mostrar_calificacion'] != false,
      showStock: json['tarjeta_mostrar_stock'] == true,
      gridColumns: _int(json['grid_columnas'], fallback: 2),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'negocio_id': businessId,
      'color_primario': primaryColor,
      'color_secundario': secondaryColor,
      'color_acento': accentColor,
      'color_texto': textColor,
      'color_titulo': headingTextColor,
      'color_texto_secundario': secondaryTextColor,
      'color_fondo': backgroundColor,
      'fuente_tienda': fontFamily,
      'gradiente_habilitado': gradientEnabled,
      'gradiente_inicio': gradientStart,
      'gradiente_fin': gradientEnd,
      'gradiente_direccion': gradientDirection,
      'tarjeta_estilo': cardStyle,
      'tarjeta_bordes': cardRadius,
      'tarjeta_mostrar_descuento': showDiscount,
      'tarjeta_mostrar_calificacion': showRating,
      'tarjeta_mostrar_stock': showStock,
      'grid_columnas': gridColumns,
    };
  }

  factory StoreCustomizationModel.fromBusinessColors({
    required String businessId,
    required Map<String, String> colors,
  }) {
    return StoreCustomizationModel(
      businessId: businessId,
      primaryColor: colors['primario'] ?? colors['primary'] ?? '#D4AF37',
      secondaryColor: colors['secundario'] ?? colors['secondary'] ?? '#111512',
      accentColor: colors['acento'] ?? colors['accent'] ?? '#3B82F6',
      textColor: colors['texto'] ?? colors['text'] ?? '#FFFFFF',
      headingTextColor:
          colors['titulo'] ?? colors['heading'] ?? colors['texto'] ?? '#FFFFFF',
      secondaryTextColor:
          colors['texto_secundario'] ?? colors['textSecondary'] ?? '#9CA3AF',
      backgroundColor: colors['fondo'] ?? colors['background'] ?? '#0D0D0D',
      fontFamily: colors['fuente'] ?? colors['fontFamily'] ?? 'Inter',
    );
  }

  static int _int(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }
}
