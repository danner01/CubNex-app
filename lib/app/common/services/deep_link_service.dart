import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

import '../../config/routes/app_routes.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  Uri? _pendingPostUri;
  StreamSubscription<Uri>? _subscription;
  bool _initialized = false;

  void initialize(GoRouter router) {
    if (_initialized) return;
    _initialized = true;
    final appLinks = AppLinks();
    _subscription = appLinks.uriLinkStream.listen((uri) {
      _handle(uri, router);
    });
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handle(uri, router);
    });
  }

  void _handle(Uri uri, GoRouter router) {
    if (!_isPostDeepLink(uri)) return;
    _pendingPostUri = uri;
    router.go(AppRoutes.posts);
  }

  bool _isPostDeepLink(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'cubnex' && uri.host.toLowerCase() == 'publicacion') {
      return true;
    }
    if (scheme == 'https' &&
        uri.host.toLowerCase() == 'supermarket-superadmin.vercel.app') {
      final segments = uri.pathSegments;
      if (segments.length >= 3 && segments[0] == 'apk' && segments[1] == 'p') {
        return true;
      }
    }
    return false;
  }

  bool consumePendingPost() {
    if (_pendingPostUri == null) return false;
    _pendingPostUri = null;
    return true;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _pendingPostUri = null;
  }
}