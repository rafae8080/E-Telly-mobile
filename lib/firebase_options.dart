import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDV25ZeP6G1cbfzUzxsCIBdQ2cTpPrjTr8',
    appId: '1:927012189317:android:b07432e2f57fcd2eb765ec',
    messagingSenderId: '927012189317',
    projectId: 'etelly-app',
    storageBucket: 'etelly-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDV25ZeP6G1cbfzUzxsCIBdQ2cTpPrjTr8',
    appId: '1:927012189317:ios:b07432e2f57fcd2eb765ec',
    messagingSenderId: '927012189317',
    projectId: 'etelly-app',
    storageBucket: 'etelly-app.firebasestorage.app',
    iosBundleId: 'com.example.eTellyApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDV25ZeP6G1cbfzUzxsCIBdQ2cTpPrjTr8',
    appId: '1:927012189317:ios:b07432e2f57fcd2eb765ec',
    messagingSenderId: '927012189317',
    projectId: 'etelly-app',
    storageBucket: 'etelly-app.firebasestorage.app',
    iosBundleId: 'com.example.eTellyApp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDV25ZeP6G1cbfzUzxsCIBdQ2cTpPrjTr8',
    appId: '1:927012189317:web:b07432e2f57fcd2eb765ec',
    messagingSenderId: '927012189317',
    projectId: 'etelly-app',
    storageBucket: 'etelly-app.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDV25ZeP6G1cbfzUzxsCIBdQ2cTpPrjTr8',
    appId: '1:927012189317:windows:b07432e2f57fcd2eb765ec',
    messagingSenderId: '927012189317',
    projectId: 'etelly-app',
    storageBucket: 'etelly-app.firebasestorage.app',
  );
}