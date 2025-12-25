import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDjdFWDZUlUrkXqKKmVuIiqVV15twlZd50',
    appId: '1:797950825270:android:fbeb406ecf44b3455d5997',
    messagingSenderId: '797950825270',
    projectId: 'sprprjdb',
    storageBucket: 'sprprjdb.firebasestorage.app',
  );

}