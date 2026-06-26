import 'package:equatable/equatable.dart';

import '../../data/models/business_dashboard_summary.dart';

enum BusinessDashboardStatus { initial, loading, success, failure }

class BusinessDashboardState extends Equatable {
  const BusinessDashboardState({
    this.status = BusinessDashboardStatus.initial,
    this.summary,
    this.message,
    this.needsWizard = false,
  });

  final BusinessDashboardStatus status;
  final BusinessDashboardSummary? summary;
  final String? message;
  final bool needsWizard;

  BusinessDashboardState copyWith({
    BusinessDashboardStatus? status,
    BusinessDashboardSummary? summary,
    String? message,
    bool? needsWizard,
  }) {
    return BusinessDashboardState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      message: message,
      needsWizard: needsWizard ?? this.needsWizard,
    );
  }

  @override
  List<Object?> get props => [status, summary, message, needsWizard];
}
