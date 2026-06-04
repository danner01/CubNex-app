import 'dart:async';

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

  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() {
      _error = null;
    });

    try {
      await _ensureFirebaseInitialized().timeout(const Duration(seconds: 12));
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await Hive.initFlutter().timeout(const Duration(seconds: 8));
      await configureDependencies().timeout(const Duration(seconds: 12));

      if (!mounted) return;
      setState(() {
        _ready = true;
      });
      unawaited(_initializeForegroundServices());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const CubNexApp();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _error == null ? 'Iniciando aplicacion...' : 'No se pudo iniciar la app',
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () => unawaited(_bootstrap()),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


Future<void> _initializeForegroundServices() async {
  try {
    await sl<PushNotificationService>().init();
  } catch (_) {
    // Startup must not be blocked by optional services.
  }
}
