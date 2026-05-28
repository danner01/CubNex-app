import 'package:equatable/equatable.dart';

import '../../data/models/asset_detail_model.dart';

enum AssetDetailStatus { initial, loading, success, failure, saving }

class AssetDetailState extends Equatable {
  const AssetDetailState({
    this.status = AssetDetailStatus.initial,
    this.asset,
    this.message,
  });

  final AssetDetailStatus status;
  final AssetDetailModel? asset;
  final String? message;

  AssetDetailState copyWith({
    AssetDetailStatus? status,
    AssetDetailModel? asset,
    String? message,
  }) {
    return AssetDetailState(
      status: status ?? this.status,
      asset: asset ?? this.asset,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, asset, message];
}
