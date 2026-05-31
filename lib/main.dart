import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'app/config/injection/injection.dart';
import 'app/common/services/push_notification_service.dart';
import 'firebase_options.dart';

Future<void>? _firebaseInitialization;

Future<void> _ensureFirebaseInitialized() async {
  if (_firebaseInitialization != null) {
    await _firebaseInitialization;
    return;
  }

  _firebaseInitialization = _initializeFirebase();

  try {
    await _firebaseInitialization;
  } catch (_) {
    _firebaseInitialization = null;
    rethrow;
  }
}

Future<void> _initializeFirebase() async {
  try {
    if (Firebase.apps.isNotEmpty) return;

    // Prefer native firebase config first (google-services/plist).
    await Firebase.initializeApp();
  } on FirebaseException catch (error) {
    // If native config is unavailable on this platform, use explicit options.
    if (error.code == 'no-app') {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return;
    }

    if (error.code != 'duplicate-app') rethrow;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _ensureFirebaseInitialized();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _ensureFirebaseInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await Hive.initFlutter();
  await configureDependencies();
  await sl<PushNotificationService>().init();

  runApp(const CubNexApp());
}
