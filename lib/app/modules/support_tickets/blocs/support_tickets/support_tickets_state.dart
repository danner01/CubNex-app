import 'package:equatable/equatable.dart';

import '../../data/models/soporte_ticket_model.dart';

enum SupportTicketsStatus { initial, loading, success, failure, creating }

class SupportTicketsState extends Equatable {
  const SupportTicketsState({
    this.status = SupportTicketsStatus.initial,
    this.tickets = const [],
    this.message,
  });

  final SupportTicketsStatus status;
  final List<SoporteTicketModel> tickets;
  final String? message;

  SupportTicketsState copyWith({
    SupportTicketsStatus? status,
    List<SoporteTicketModel>? tickets,
    String? message,
  }) {
    return SupportTicketsState(
      status: status ?? this.status,
      tickets: tickets ?? this.tickets,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, tickets, message];
}