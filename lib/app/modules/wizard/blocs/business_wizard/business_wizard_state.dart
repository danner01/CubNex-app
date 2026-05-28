import 'package:equatable/equatable.dart';

import '../../data/models/business_type_model.dart';

enum BusinessWizardStatus { initial, loading, ready, saving, success, failure }

class BusinessWizardState extends Equatable {
  const BusinessWizardState({
    this.status = BusinessWizardStatus.initial,
    this.types = const [],
    this.createdBusinessId,
    this.message,
  });

  final BusinessWizardStatus status;
  final List<BusinessTypeModel> types;
  final String? createdBusinessId;
  final String? message;

  BusinessWizardState copyWith({
    BusinessWizardStatus? status,
    List<BusinessTypeModel>? types,
    String? createdBusinessId,
    String? message,
  }) {
    return BusinessWizardState(
      status: status ?? this.status,
      types: types ?? this.types,
      createdBusinessId: createdBusinessId ?? this.createdBusinessId,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, types, createdBusinessId, message];
}
