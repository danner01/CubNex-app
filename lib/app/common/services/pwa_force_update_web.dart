import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> forcePwaUpdate() async {
  final registrations =
      (await web.window.navigator.serviceWorker.getRegistrations().toDart)
          .toDart;
  for (final registration in registrations) {
    await registration.unregister().toDart;
  }

  final cacheKeys = (await web.window.caches.keys().toDart).toDart;
  for (final key in cacheKeys) {
    await web.window.caches.delete(key.toDart).toDart;
  }

  final uri = Uri.parse(web.window.location.href);
  final params = Map<String, String>.from(uri.queryParameters);
  params['_pwa'] = DateTime.now().millisecondsSinceEpoch.toString();
  web.window.location.replace(uri.replace(queryParameters: params).toString());
}
