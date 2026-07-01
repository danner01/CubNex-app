import 'package:equatable/equatable.dart';

import '../../data/models/promotion_model.dart';

enum PromotionsStatus { initial, loading, success, failure, saving }

class PromotionRedemption extends Equatable {
  const PromotionRedemption({
    required this.id,
    required this.token,
    this.qrUrl,
    this.title,
    this.expiresAt,
  });

  final String id;
  final String token;
  final String? qrUrl;
  final String? title;
  final DateTime? expiresAt;

  factory PromotionRedemption.fromJson(Map<String, dynamic> json) {
    final promotion = json['promociones'];
    final data = json['datos_promocion'];
    final promotionMap = promotion is Map ? promotion : data is Map ? data : null;
    return PromotionRedemption(
      id: '${json['id'] ?? ''}',
      token: '${json['token'] ?? ''}',
      qrUrl: json['qr_url']?.toString(),
      title: promotionMap is Map ? promotionMap['titulo']?.toString() : null,
      expiresAt: DateTime.tryParse('${json['expires_at'] ?? ''}'),
    );
  }

  @override
  List<Object?> get props => [id, token, qrUrl, title, expiresAt];
}

class PromotionsState extends Equatable {
  const PromotionsState({
    this.status = PromotionsStatus.initial,
    this.items = const [],
    this.businessId,
    this.message,
    this.redemption,
  });

  final PromotionsStatus status;
  final List<PromotionModel> items;
  final String? businessId;
  final String? message;
  final PromotionRedemption? redemption;

  PromotionsState copyWith({
    PromotionsStatus? status,
    List<PromotionModel>? items,
    String? businessId,
    String? message,
    PromotionRedemption? redemption,
    bool clearRedemption = false,
  }) {
    return PromotionsState(
      status: status ?? this.status,
      items: items ?? this.items,
      businessId: businessId ?? this.businessId,
      message: message,
      redemption: clearRedemption ? null : redemption ?? this.redemption,
    );
  }

  @override
  List<Object?> get props => [status, items, businessId, message, redemption];
}
