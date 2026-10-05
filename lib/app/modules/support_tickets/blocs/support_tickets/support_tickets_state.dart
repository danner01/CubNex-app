import 'package:equatable/equatable.dart';

import '../../data/models/soporte_ticket_model.dart';

enum SupportTicketsStatus { initial, loading, success, failure, creating }

class SupportTicketsState extends Equatable {
  const SupportTicketsState({
    this.status = SupportTicketsStatus.initial,
    this.tickets = const [],
    this.message,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final SupportTicketsStatus status;
  final List<SoporteTicketModel> tickets;
  final String? message;
  final bool hasMore;
  final bool isLoadingMore;

  SupportTicketsState copyWith({
    SupportTicketsStatus? status,
    List<SoporteTicketModel>? tickets,
    String? message,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return SupportTicketsState(
      status: status ?? this.status,
      tickets: tickets ?? this.tickets,
      message: message,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [status, tickets, message, hasMore, isLoadingMore];
}
