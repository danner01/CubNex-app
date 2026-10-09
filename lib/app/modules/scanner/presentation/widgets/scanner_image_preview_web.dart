import 'package:flutter/material.dart';

class ScannerImagePreview extends StatelessWidget {
  const ScannerImagePreview({
    required this.path,
    required this.height,
    required this.fit,
    required this.errorBuilder,
    super.key,
  });

  final String path;
  final double? height;
  final BoxFit fit;
  final ImageErrorWidgetBuilder errorBuilder;

  @override
  Widget build(BuildContext context) => Image.network(
    path,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}
