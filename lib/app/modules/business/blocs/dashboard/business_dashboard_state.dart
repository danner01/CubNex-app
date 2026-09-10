import 'package:equatable/equatable.dart';

import '../../../plans/data/models/plan_status.dart';
import '../../data/models/business_operational_references.dart';
import '../../data/models/business_dashboard_summary.dart';

enum BusinessDashboardStatus { initial, loading, success, failure }

class BusinessDashboardState extends Equatable {
  const BusinessDashboardState({
    this.status = BusinessDashboardStatus.initial,
    this.summary,
    this.operationalReferences,
    this.activePlan,
    this.message,
    this.needsWizard = false,
  });

  final BusinessDashboardStatus status;
  final BusinessDashboardSummary? summary;
  final BusinessOperationalReferences? operationalReferences;
  final ActiveSubscription? activePlan;
  final String? message;
  final bool needsWizard;

  BusinessDashboardState copyWith({
    BusinessDashboardStatus? status,
    BusinessDashboardSummary? summary,
    BusinessOperationalReferences? operationalReferences,
    ActiveSubscription? activePlan,
    String? message,
    bool? needsWizard,
  }) {
    return BusinessDashboardState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      operationalReferences: operationalReferences ?? this.operationalReferences,
      activePlan: activePlan ?? this.activePlan,
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
    message,
    needsWizard,
  ];
}
