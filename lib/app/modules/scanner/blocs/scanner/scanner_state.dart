import 'package:equatable/equatable.dart';

enum ScannerStatus { initial, scanning, resolving, success, failure }

class ScannerState extends Equatable {
  const ScannerState({
    this.status = ScannerStatus.scanning,
    this.code,
    this.message,
    this.orderQrValidated = false,
    this.walletQrDetected = false,
    this.walletUserId,
    this.walletAlias,
    this.walletQrPayload,
    this.rawCodeFallback,
    this.orderId,
    this.previousStatus,
    this.nextStatus,
  });

  final ScannerStatus status;
  final String? code;
  final String? message;
  final bool orderQrValidated;
  final bool walletQrDetected;
  final String? walletUserId;
  final String? walletAlias;
  final String? walletQrPayload;
  final String? rawCodeFallback;
  final String? orderId;
  final String? previousStatus;
  final String? nextStatus;

  ScannerState copyWith({
    ScannerStatus? status,
    String? code,
    String? message,
    bool? orderQrValidated,
    bool? walletQrDetected,
    String? walletUserId,
    String? walletAlias,
    String? walletQrPayload,
    String? rawCodeFallback,
    String? orderId,
    String? previousStatus,
    String? nextStatus,
    bool clearRawCodeFallback = false,
    bool clearOrderResult = false,
  }) {
    return ScannerState(
      status: status ?? this.status,
      code: code ?? this.code,
      message: message,
      orderQrValidated: orderQrValidated ?? this.orderQrValidated,
      walletQrDetected: walletQrDetected ?? this.walletQrDetected,
      walletUserId: walletUserId ?? this.walletUserId,
      walletAlias: walletAlias ?? this.walletAlias,
      walletQrPayload: walletQrPayload ?? this.walletQrPayload,
      rawCodeFallback:
          clearRawCodeFallback ? null : (rawCodeFallback ?? this.rawCodeFallback),
      orderId: clearOrderResult ? null : (orderId ?? this.orderId),
      previousStatus: clearOrderResult
          ? null
          : (previousStatus ?? this.previousStatus),
      nextStatus: clearOrderResult ? null : (nextStatus ?? this.nextStatus),
    );
  }

  @override
  List<Object?> get props => [
    status,
    code,
    message,
    orderQrValidated,
    walletQrDetected,
    walletUserId,
    walletAlias,
    walletQrPayload,
    rawCodeFallback,
    orderId,
    previousStatus,
    nextStatus,
  ];
}
