import 'package:equatable/equatable.dart';

import '../../../home/data/models/product_model.dart';

enum ScannerStatus { initial, scanning, resolving, success, failure }

class ScannerState extends Equatable {
  const ScannerState({
    this.status = ScannerStatus.scanning,
    this.code,
    this.products = const [],
    this.message,
  });

  final ScannerStatus status;
  final String? code;
  final List<ProductModel> products;
  final String? message;

  ScannerState copyWith({
    ScannerStatus? status,
    String? code,
    List<ProductModel>? products,
    String? message,
  }) {
    return ScannerState(
      status: status ?? this.status,
      code: code ?? this.code,
      products: products ?? this.products,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, code, products, message];
}
