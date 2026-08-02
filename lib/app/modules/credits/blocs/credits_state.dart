import 'package:equatable/equatable.dart';

import '../data/models/credit_movement.dart';
import '../data/models/credit_summary.dart';

enum CreditStatus { initial, loading, submitting, success, failure }

class CreditsState extends Equatable {
  const CreditsState({
    this.status = CreditStatus.initial,
    this.summary,
    this.movements = const [],
    this.message,
  });

  final CreditStatus status;
  final CreditSummary? summary;
  final List<CreditMovement> movements;
  final String? message;

  @override
  List<Object?> get props => [status, summary, movements, message];

  CreditsState copyWith({
    CreditStatus? status,
    CreditSummary? summary,
    List<CreditMovement>? movements,
    String? message,
  }) {
    return CreditsState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      movements: movements ?? this.movements,
      message: message,
    );
  }
}
