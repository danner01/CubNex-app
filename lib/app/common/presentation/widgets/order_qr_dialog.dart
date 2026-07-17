import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../config/http/api_client.dart';
import '../../../config/injection/injection.dart';
import '../../../modules/orders/data/models/order_model.dart';

Future<void> showOrderQrDialog(
  BuildContext context,
  String qrValue, {
  String title = 'QR del pedido',
  String subtitle =
      'Muestra este QR al negocio o delivery para avanzar el estado del pedido.',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: _OrderQrImage(qrValue: qrValue),
              ),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      );
    },
  );
}

Future<void> showOrderQrDialogForOrder(
  BuildContext context,
  OrderModel order, {
  String title = 'QR del pedido',
  String subtitle =
      'Muestra este QR al negocio o delivery para avanzar el estado del pedido.',
}) async {
  final immediateValue = order.qrValue;
  if (immediateValue != null) {
    return showOrderQrDialog(
      context,
      immediateValue,
      title: title,
      subtitle: subtitle,
    );
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return const AlertDialog(
        content: SizedBox(
          height: 96,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Cargando QR del pedido...'),
            ],
          ),
        ),
      );
    },
  );

  final resolvedQr = await _resolveOrderQrValue(order);
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  if (!context.mounted) return;

  if (resolvedQr == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo obtener el QR del pedido.')),
    );
    return;
  }

  return showOrderQrDialog(
    context,
    resolvedQr,
    title: title,
    subtitle: subtitle,
  );
}

Future<String?> _resolveOrderQrValue(OrderModel order) async {
  final apiClient = sl<ApiClient>();
  final detailResult = await apiClient.get<OrderModel>(
    '/ordenes/${order.id}',
    queryParameters: const {'include': 'full'},
    parser: (json) =>
        OrderModel.fromJson(Map<String, dynamic>.from(json as Map)),
  );
  final detailQr = detailResult.data?.qrValue;
  if (detailQr != null && detailQr.isNotEmpty) return detailQr;

  final generatedResult = await apiClient.post<OrderModel>(
    '/ordenes/${order.id}/generar-qr',
    data: const <String, dynamic>{},
    parser: (json) {
      if (json is List && json.isNotEmpty) {
        return OrderModel.fromJson(
          Map<String, dynamic>.from(json.first as Map),
        );
      }
      return OrderModel.fromJson(Map<String, dynamic>.from(json as Map));
    },
  );
  final generatedQr = generatedResult.data?.qrValue;
  if (generatedQr != null && generatedQr.isNotEmpty) return generatedQr;
  return null;
}

class _OrderQrImage extends StatelessWidget {
  const _OrderQrImage({required this.qrValue});

  final String qrValue;

  @override
  Widget build(BuildContext context) {
    final trimmed = qrValue.trim();
    if (trimmed.startsWith('data:image')) {
      final commaIndex = trimmed.indexOf(',');
      if (commaIndex > 0 && commaIndex < trimmed.length - 1) {
        try {
          final bytes = base64Decode(trimmed.substring(commaIndex + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const _OrderQrFallback(),
          );
        } catch (_) {
          return const _OrderQrFallback();
        }
      }
      return const _OrderQrFallback();
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _OrderQrFallback(),
      );
    }

    return _OrderQrCodeText(value: trimmed);
  }
}

class _OrderQrFallback extends StatelessWidget {
  const _OrderQrFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No se pudo cargar el QR.'));
  }
}

class _OrderQrCodeText extends StatelessWidget {
  const _OrderQrCodeText({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
