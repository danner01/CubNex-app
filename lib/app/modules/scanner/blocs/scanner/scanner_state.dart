import 'package:equatable/equatable.dart';

import '../../../business/data/models/product_label_detection.dart';

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
    this.productDetection,
    this.productDetectedLocally = false,
    this.productQuery,
    this.productImagePath,
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

  /// Deteccion del producto escaneado (IA + OCR local).
  final ProductLabelDetection? productDetection;
  final bool productDetectedLocally;
  final String? productQuery;
  final String? productImagePath;

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
    ProductLabelDetection? productDetection,
    bool? productDetectedLocally,
    String? productQuery,
    String? productImagePath,
    bool clearRawCodeFallback = false,
    bool clearOrderResult = false,
    bool clearProductResult = false,
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
      productDetection: clearProductResult
          ? null
          : (productDetection ?? this.productDetection),
      productDetectedLocally:
          (clearProductResult ? false : productDetectedLocally) ??
              this.productDetectedLocally,
      productQuery: clearProductResult
          ? null
          : (productQuery ?? this.productQuery),
      productImagePath: clearProductResult
          ? null
          : (productImagePath ?? this.productImagePath),
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
    productDetection,
    productDetectedLocally,
    productQuery,
    productImagePath,
  ];
}
