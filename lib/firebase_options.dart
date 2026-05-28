import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'CubNex only supports Android and iOS for now.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBcyLlU6iSXsORdCYKDrfJ2xJPzELrN7pA',
    appId: '1:182405994803:web:889e8d1ba69064b581c646',
    messagingSenderId: '182405994803',
    projectId: 'supermarkercuba',
    storageBucket: 'supermarkercuba.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBcyLlU6iSXsORdCYKDrfJ2xJPzELrN7pA',
    appId: '1:182405994803:web:889e8d1ba69064b581c646',
    messagingSenderId: '182405994803',
    projectId: 'supermarkercuba',
    storageBucket: 'supermarkercuba.firebasestorage.app',
    iosBundleId: 'com.cubnex.app',
  );
}
