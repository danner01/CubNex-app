import 'package:equatable/equatable.dart';

import '../../../wizard/data/models/business_type_model.dart';

enum PreferencesStatus { initial, loading, ready, saving, success, failure }

class PreferencesState extends Equatable {
  const PreferencesState({
    this.status = PreferencesStatus.initial,
    this.types = const [],
    this.selectedTypeIds = const {},
    this.message,
  });

  final PreferencesStatus status;
  final List<BusinessTypeModel> types;
  final Set<String> selectedTypeIds;
  final String? message;

  PreferencesState copyWith({
    PreferencesStatus? status,
    List<BusinessTypeModel>? types,
    Set<String>? selectedTypeIds,
    String? message,
  }) {
    return PreferencesState(
      status: status ?? this.status,
      types: types ?? this.types,
      selectedTypeIds: selectedTypeIds ?? this.selectedTypeIds,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, types, selectedTypeIds, message];
}
