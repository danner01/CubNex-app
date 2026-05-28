import 'package:equatable/equatable.dart';

import '../../data/models/gamification_level.dart';
import '../../data/models/gamification_summary.dart';

enum GamificationStatus { initial, loading, success, failure }

class GamificationState extends Equatable {
  const GamificationState({
    this.status = GamificationStatus.initial,
    this.summary,
    this.levels = const [],
    this.message,
  });

  final GamificationStatus status;
  final GamificationSummary? summary;
  final List<GamificationLevel> levels;
  final String? message;

  GamificationState copyWith({
    GamificationStatus? status,
    GamificationSummary? summary,
    List<GamificationLevel>? levels,
    String? message,
  }) {
    return GamificationState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      levels: levels ?? this.levels,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, summary, levels, message];
}
