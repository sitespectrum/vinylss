import 'package:flutter/foundation.dart';

/// Backend base URL. Override with `--dart-define=API_BASE_URL=...`.
/// The Android emulator reaches the host's loopback via 10.0.2.2.
String get apiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:5080';
  }
  return 'http://127.0.0.1:5080';
}

/// Where the backend sends the browser after Spotify login. Must be listed in the
/// backend's `App:AllowedReturnUrls`.
String get authReturnUrl {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    return 'vinylss://callback';
  }
  // Desktop: the app listens on this loopback port during login.
  return 'http://127.0.0.1:43823/callback';
}
