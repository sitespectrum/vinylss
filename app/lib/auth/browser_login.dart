import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

const _loginTimeout = Duration(minutes: 10);

/// Opens [loginUrl] in the system browser and completes with the callback URL the backend
/// redirects to after Spotify login.
///
/// - Desktop: listens on a loopback port for the redirect.
/// - Android/iOS: waits for the `vinylss://callback` deep link.
Future<Uri> runBrowserLogin(Uri loginUrl) {
  final mobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  return mobile ? _viaDeepLink(loginUrl) : _viaLoopback(loginUrl);
}

Future<Uri> _viaDeepLink(Uri loginUrl) async {
  final expected = Uri.parse(authReturnUrl);
  final completer = Completer<Uri>();
  final sub = AppLinks().uriLinkStream.listen((uri) {
    if (uri.scheme == expected.scheme && !completer.isCompleted) completer.complete(uri);
  });
  try {
    await _launch(loginUrl);
    return await completer.future.timeout(_loginTimeout);
  } finally {
    await sub.cancel();
  }
}

Future<Uri> _viaLoopback(Uri loginUrl) async {
  final expected = Uri.parse(authReturnUrl);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, expected.port, shared: true);
  try {
    await _launch(loginUrl);
    await for (final req in server.timeout(_loginTimeout)) {
      if (req.uri.path != expected.path) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        continue;
      }
      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('<!doctype html><title>Vinylss</title>'
            '<body style="font-family:sans-serif;text-align:center;padding-top:20vh">'
            '<h2>You can close this tab and return to Vinylss.</h2></body>');
      await req.response.close();
      return req.uri;
    }
    throw TimeoutException('Login was not completed');
  } finally {
    await server.close(force: true);
  }
}

Future<void> _launch(Uri url) async {
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw StateError('Could not open the browser');
  }
}
