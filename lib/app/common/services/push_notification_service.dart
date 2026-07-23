import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/http/api_client.dart';

class PushNotificationService {
  PushNotificationService({
    required FirebaseMessaging firebaseMessaging,
    required ApiClient apiClient,
  }) : _firebaseMessaging = firebaseMessaging,
       _apiClient = apiClient;

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final StreamController<void> _notificationsChangedController =
      StreamController<void>.broadcast();

  final FirebaseMessaging _firebaseMessaging;
  final ApiClient _apiClient;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenSubscription;
  bool _initialized = false;

  Stream<void> get notificationsChanged =>
      _notificationsChangedController.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _syncCurrentToken();
    _tokenSubscription = _firebaseMessaging.onTokenRefresh.listen(
      (token) => _syncToken(token),
    );

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundMessage,
    );
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _tokenSubscription?.cancel();
    _initialized = false;
  }

  void notifyNotificationsChanged() {
    if (_notificationsChangedController.isClosed) return;
    _notificationsChangedController.add(null);
  }

  Future<void> _syncCurrentToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _syncToken(token);
      }
    } catch (_) {
      // Push registration is best-effort; auth and app startup must continue.
    }
  }

  Future<void> _syncToken(String token) async {
    try {
      await _apiClient
          .put('/auth/fcm-token', data: {'fcm_token': token})
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Token refresh can happen without an active API session.
    }
  }

  void _showForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['titulo'] ?? 'ConKkao';
    final body =
        notification?.body ??
        message.data['mensaje'] ??
        'Nueva notificacion recibida.';

    SystemSound.play(SystemSoundType.alert);
    notifyNotificationsChanged();
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('$title\n$body'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
