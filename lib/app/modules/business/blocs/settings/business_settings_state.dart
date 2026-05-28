import 'package:equatable/equatable.dart';

import '../../../home/data/models/business_model.dart';
import '../../data/models/store_customization_model.dart';

enum BusinessSettingsStatus { initial, loading, ready, saving, success, failure }

class BusinessSettingsState extends Equatable {
  const BusinessSettingsState({
    this.status = BusinessSettingsStatus.initial,
    this.business,
    this.customization,
    this.message,
  });

  final BusinessSettingsStatus status;
  final BusinessModel? business;
  final StoreCustomizationModel? customization;
  final String? message;

  BusinessSettingsState copyWith({
    BusinessSettingsStatus? status,
    BusinessModel? business,
    StoreCustomizationModel? customization,
    String? message,
  }) {
    return BusinessSettingsState(
      status: status ?? this.status,
      business: business ?? this.business,
      customization: customization ?? this.customization,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, business, customization, message];
}
