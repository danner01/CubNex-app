import 'package:equatable/equatable.dart';

import '../../data/models/scan_history_item.dart';

enum ScanHistoryStatus { initial, loading, success, failure }

class ScanHistoryState extends Equatable {
  const ScanHistoryState({
    this.status = ScanHistoryStatus.initial,
    this.items = const [],
    this.message,
  });

  final ScanHistoryStatus status;
  final List<ScanHistoryItem> items;
  final String? message;

  ScanHistoryState copyWith({
    ScanHistoryStatus? status,
    List<ScanHistoryItem>? items,
    String? message,
  }) {
    return ScanHistoryState(
      status: status ?? this.status,
      items: items ?? this.items,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, items, message];
}
