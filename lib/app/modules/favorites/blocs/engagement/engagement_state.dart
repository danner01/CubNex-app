import 'package:equatable/equatable.dart';

enum EngagementStatus { initial, loading, success, failure }

class EngagementState extends Equatable {
  const EngagementState({
    this.status = EngagementStatus.initial,
    this.message,
  });

  final EngagementStatus status;
  final String? message;

  EngagementState copyWith({
    EngagementStatus? status,
    String? message,
  }) {
    return EngagementState(
      status: status ?? this.status,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}
