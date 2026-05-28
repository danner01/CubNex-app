import 'package:equatable/equatable.dart';

import '../../../search/data/models/search_results_model.dart';

enum PropertiesStatus { initial, loading, success, failure, saving }

class PropertiesState extends Equatable {
  const PropertiesState({
    this.status = PropertiesStatus.initial,
    this.items = const [],
    this.businessId,
    this.message,
  });

  final PropertiesStatus status;
  final List<SearchAssetModel> items;
  final String? businessId;
  final String? message;

  PropertiesState copyWith({
    PropertiesStatus? status,
    List<SearchAssetModel>? items,
    String? businessId,
    String? message,
  }) {
    return PropertiesState(
      status: status ?? this.status,
      items: items ?? this.items,
      businessId: businessId ?? this.businessId,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, items, businessId, message];
}
