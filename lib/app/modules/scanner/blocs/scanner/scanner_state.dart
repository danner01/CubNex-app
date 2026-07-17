import 'package:equatable/equatable.dart';

enum ScannerStatus { initial, scanning, resolving, success, failure }

class ScannerState extends Equatable {
  const ScannerState({
    this.status = ScannerStatus.scanning,
    this.code,
    this.message,
    this.orderQrValidated = false,
  });

  final ScannerStatus status;
  final String? code;
  final String? message;
  final bool orderQrValidated;

  ScannerState copyWith({
    ScannerStatus? status,
    String? code,
    String? message,
    bool? orderQrValidated,
  }) {
    return ScannerState(
      status: status ?? this.status,
      code: code ?? this.code,
      message: message,
      orderQrValidated: orderQrValidated ?? this.orderQrValidated,
    );
  }

  @override
  List<Object?> get props => [
    status,
    code,
    message,
    orderQrValidated,
  ];
}
