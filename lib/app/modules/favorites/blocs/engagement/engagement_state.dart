import 'package:equatable/equatable.dart';

enum EngagementStatus { initial, loading, success, failure }

class EngagementState extends Equatable {
  const EngagementState({
    this.status = EngagementStatus.initial,
    this.message,
    this.isFollowing = false,
    this.isFavorite = false,
  });

  final EngagementStatus status;
  final String? message;
  final bool isFollowing;
  final bool isFavorite;

  EngagementState copyWith({
    EngagementStatus? status,
    String? message,
    bool? isFollowing,
    bool? isFavorite,
  }) {
    return EngagementState(
      status: status ?? this.status,
      message: message,
      isFollowing: isFollowing ?? this.isFollowing,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  List<Object?> get props => [status, message, isFollowing, isFavorite];
}
