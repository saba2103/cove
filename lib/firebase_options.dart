// File generated for Cove Firebase Cloud Messaging integration.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAH_fKPWgz1TG2uV6T-PM1bgGIkCznZRh8',
    appId: '1:633452066662:web:406f9a0fa75a2545307aa7',
    messagingSenderId: '633452066662',
    projectId: 'cove-home-app',
    authDomain: 'cove-home-app.firebaseapp.com',
    storageBucket: 'cove-home-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAH_fKPWgz1TG2uV6T-PM1bgGIkCznZRh8',
    appId: '1:633452066662:android:406f9a0fa75a2545307aa7',
    messagingSenderId: '633452066662',
    projectId: 'cove-home-app',
    storageBucket: 'cove-home-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAH_fKPWgz1TG2uV6T-PM1bgGIkCznZRh8',
    appId: '1:633452066662:ios:406f9a0fa75a2545307aa7',
    messagingSenderId: '633452066662',
    projectId: 'cove-home-app',
    storageBucket: 'cove-home-app.firebasestorage.app',
    iosBundleId: 'com.app.cove',
  );
}
