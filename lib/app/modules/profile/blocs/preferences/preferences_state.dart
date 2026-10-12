import 'package:equatable/equatable.dart';

import '../../../wizard/data/models/business_type_model.dart';

enum PreferencesStatus { initial, loading, ready, saving, success, failure }

class PreferencesState extends Equatable {
  const PreferencesState({
    this.status = PreferencesStatus.initial,
    this.types = const [],
    this.selectedTypeIds = const {},
    this.opportunitiesLocationEnabled = false,
    this.nearbyOpportunityNotificationsEnabled = false,
    this.opportunityRadiusKm = 2,
    this.opportunityFrequencyMinutes = 180,
    this.message,
  });

  final PreferencesStatus status;
  final List<BusinessTypeModel> types;
  final Set<String> selectedTypeIds;
  final bool opportunitiesLocationEnabled;
  final bool nearbyOpportunityNotificationsEnabled;
  final int opportunityRadiusKm;
  final int opportunityFrequencyMinutes;
  final String? message;

  PreferencesState copyWith({
    PreferencesStatus? status,
    List<BusinessTypeModel>? types,
    Set<String>? selectedTypeIds,
    bool? opportunitiesLocationEnabled,
    bool? nearbyOpportunityNotificationsEnabled,
    int? opportunityRadiusKm,
    int? opportunityFrequencyMinutes,
    String? message,
  }) {
    return PreferencesState(
      status: status ?? this.status,
      types: types ?? this.types,
      selectedTypeIds: selectedTypeIds ?? this.selectedTypeIds,
      opportunitiesLocationEnabled:
          opportunitiesLocationEnabled ?? this.opportunitiesLocationEnabled,
      nearbyOpportunityNotificationsEnabled:
          nearbyOpportunityNotificationsEnabled ??
          this.nearbyOpportunityNotificationsEnabled,
      opportunityRadiusKm: opportunityRadiusKm ?? this.opportunityRadiusKm,
      opportunityFrequencyMinutes:
          opportunityFrequencyMinutes ?? this.opportunityFrequencyMinutes,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
    status,
    types,
    selectedTypeIds,
    opportunitiesLocationEnabled,
    nearbyOpportunityNotificationsEnabled,
    opportunityRadiusKm,
    opportunityFrequencyMinutes,
    message,
  ];
}
