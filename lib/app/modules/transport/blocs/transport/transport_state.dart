import 'package:equatable/equatable.dart';

import '../../../search/data/models/search_results_model.dart';

enum TransportStatus { initial, loading, success, failure, saving }

class TransportState extends Equatable {
  const TransportState({
    this.status = TransportStatus.initial,
    this.items = const [],
    this.businessId,
    this.message,
  });

  final TransportStatus status;
  final List<SearchAssetModel> items;
  final String? businessId;
  final String? message;

  TransportState copyWith({
    TransportStatus? status,
    List<SearchAssetModel>? items,
    String? businessId,
    String? message,
  }) {
    return TransportState(
      status: status ?? this.status,
      items: items ?? this.items,
      businessId: businessId ?? this.businessId,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, items, businessId, message];
}
