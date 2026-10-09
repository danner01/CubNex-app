import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Permite que los widgets Flutter (botones, paneles, FABs) sigan siendo
/// interactivos cuando se superponen a un mapa web (HtmlElementView/iframe),
/// que de lo contrario intercepta los toques en la web.
class WebMapOverlay extends StatelessWidget {
  const WebMapOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => PointerInterceptor(child: child);
}