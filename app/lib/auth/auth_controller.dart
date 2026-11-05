import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../config.dart';
import 'browser_login.dart';

class AuthState {
  const AuthState({this.loading = false, this.token, this.error});

  final bool loading;
  final String? token;
  final String? error;

  bool get isLoggedIn => token != null;
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

final apiProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(authProvider.select((s) => s.token));
  return ApiClient(
    baseUrl: apiBaseUrl,
    token: token,
    onUnauthorized: () => ref.read(authProvider.notifier).logout(
          reason: 'Your session expired, please log in again.',
        ),
  );
});

class AuthController extends Notifier<AuthState> {
  static const _tokenKey = 'vinylss_token';
  static const _storage = FlutterSecureStorage();

  @override
  AuthState build() {
    _restore();
    return const AuthState(loading: true);
  }

  Future<void> _restore() async {
    String? token;
    try {
      token = await _storage.read(key: _tokenKey);
    } catch (e) {
      // No keyring available (e.g. some Linux setups): fall back to logging in each launch.
      debugPrint('Secure storage unavailable: $e');
    }
    state = AuthState(token: token);
  }

  Future<void> login() async {
    state = const AuthState(loading: true);
    try {
      final url = Uri.parse('$apiBaseUrl/auth/login')
          .replace(queryParameters: {'returnUrl': authReturnUrl});
      final result = await runBrowserLogin(url);

      final params = result.queryParameters;
      if (params['error'] != null) throw _LoginError(_describeLoginError(params['error']!));
      final code = params['code'];
      if (code == null) throw const _LoginError('Login did not return a code.');

      final token = await ApiClient(baseUrl: apiBaseUrl).exchangeLoginCode(code);
      try {
        await _storage.write(key: _tokenKey, value: token);
      } catch (e) {
        debugPrint('Could not persist token: $e');
      }
      state = AuthState(token: token);
    } on _LoginError catch (e) {
      state = AuthState(error: e.message);
    } on TimeoutException {
      state = const AuthState(error: 'Login timed out. Please try again.');
    } catch (e) {
      state = AuthState(error: describeError(e));
    }
  }

  Future<void> logout({String? reason}) async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
    state = AuthState(error: reason);
  }

  static String _describeLoginError(String code) => switch (code) {
        'access_denied' => 'Spotify access was denied.',
        'spotify_forbidden' =>
          'Spotify refused access. While the Spotify app is in development mode, your account must be added to its user list.',
        'spotify_rate_limited' =>
          'Spotify is temporarily rate limiting this server. Please try again later.',
        _ => 'Spotify login failed ($code).',
      };
}

class _LoginError implements Exception {
  const _LoginError(this.message);

  final String message;
}
