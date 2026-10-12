import 'package:equatable/equatable.dart';

import '../../../plans/data/models/plan_status.dart';
import '../../data/models/business_operational_references.dart';
import '../../data/models/business_dashboard_summary.dart';
import '../../data/models/business_opportunity.dart';

enum BusinessDashboardStatus { initial, loading, success, failure }

enum NearbyOpportunityStatus { unknown, loading, needsLocation, empty, ready }

class BusinessDashboardState extends Equatable {
  const BusinessDashboardState({
    this.status = BusinessDashboardStatus.initial,
    this.summary,
    this.operationalReferences,
    this.activePlan,
    this.nearbyOpportunities = const [],
    this.nearbyStatus = NearbyOpportunityStatus.unknown,
    this.nearbyMessage,
    this.metricTrends = const {},
    this.canViewReports = true,
    this.message,
    this.needsWizard = false,
  });

  final BusinessDashboardStatus status;
  final BusinessDashboardSummary? summary;
  final BusinessOperationalReferences? operationalReferences;
  final ActiveSubscription? activePlan;
  final List<BusinessOpportunity> nearbyOpportunities;
  final NearbyOpportunityStatus nearbyStatus;
  final String? nearbyMessage;
  final Map<String, int> metricTrends;
  final bool canViewReports;
  final String? message;
  final bool needsWizard;

  BusinessDashboardState copyWith({
    BusinessDashboardStatus? status,
    BusinessDashboardSummary? summary,
    BusinessOperationalReferences? operationalReferences,
    ActiveSubscription? activePlan,
    List<BusinessOpportunity>? nearbyOpportunities,
    NearbyOpportunityStatus? nearbyStatus,
    String? nearbyMessage,
    Map<String, int>? metricTrends,
    bool? canViewReports,
    String? message,
    bool? needsWizard,
  }) {
    return BusinessDashboardState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      operationalReferences: operationalReferences ?? this.operationalReferences,
      activePlan: activePlan ?? this.activePlan,
      nearbyOpportunities: nearbyOpportunities ?? this.nearbyOpportunities,
      nearbyStatus: nearbyStatus ?? this.nearbyStatus,
      nearbyMessage: nearbyMessage,
      metricTrends: metricTrends ?? this.metricTrends,
      canViewReports: canViewReports ?? this.canViewReports,
      message: message,
      needsWizard: needsWizard ?? this.needsWizard,
    );
  }

  @override
  List<Object?> get props => [
    status,
    summary,
    operationalReferences,
    activePlan,
    nearbyOpportunities,
    nearbyStatus,
    nearbyMessage,
    metricTrends,
    canViewReports,
    message,
    needsWizard,
  ];
}
