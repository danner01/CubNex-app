import 'package:equatable/equatable.dart';

import '../data/models/credit_movement.dart';
import '../data/models/credit_summary.dart';
import '../data/models/verified_topup.dart';

enum CreditStatus { initial, loading, submitting, success, failure }

class CreditsState extends Equatable {
  const CreditsState({
    this.status = CreditStatus.initial,
    this.summary,
    this.movements = const [],
    this.topupRequests = const [],
    this.message,
    this.walletScope = 'unloaded',
  });

  final CreditStatus status;
  final CreditSummary? summary;
  final List<CreditMovement> movements;
  final List<VerifiedTopupRequest> topupRequests;
  final String? message;
  final String walletScope;

  @override
  List<Object?> get props => [
    status,
    summary,
    movements,
    topupRequests,
    message,
    walletScope,
  ];

  CreditsState copyWith({
    CreditStatus? status,
    CreditSummary? summary,
    List<CreditMovement>? movements,
    List<VerifiedTopupRequest>? topupRequests,
    String? message,
    String? walletScope,
    bool clearWalletData = false,
  }) {
    return CreditsState(
      status: status ?? this.status,
      summary: clearWalletData ? null : summary ?? this.summary,
      movements: clearWalletData ? const [] : movements ?? this.movements,
      topupRequests:
          clearWalletData ? const [] : topupRequests ?? this.topupRequests,
      message: message,
      walletScope: walletScope ?? this.walletScope,
    );
  }
}
