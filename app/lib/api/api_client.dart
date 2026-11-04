import 'package:dio/dio.dart';

import 'models.dart';

/// Typed wrapper around the Vinylss backend.
class ApiClient {
  ApiClient({
    required String baseUrl,
    String? token,
    void Function()? onUnauthorized,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 60),
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401 && token != null) onUnauthorized?.call();
        handler.next(e);
      },
    ));
  }

  final Dio _dio;

  Future<String> exchangeLoginCode(String code) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/token', data: {'code': code});
    return res.data!['token'] as String;
  }

  Future<Me> me() async =>
      Me.fromJson((await _dio.get<Map<String, dynamic>>('/me')).data!);

  Future<UserSettings> settings() async =>
      UserSettings((await _dio.get<Map<String, dynamic>>('/settings')).data!);

  Future<UserSettings> saveSettings(UserSettings s) async =>
      UserSettings((await _dio.put<Map<String, dynamic>>('/settings', data: s.json)).data!);

  Future<RecommendationSnapshot> recommendations() async => RecommendationSnapshot.fromJson(
      (await _dio.get<Map<String, dynamic>>('/recommendations')).data!);

  Future<void> refreshRecommendations() => _dio.post<void>('/recommendations/refresh');

  Future<void> mark(Recommendation r, MarkKind kind) => _dio.post<void>(
        '/albums/${Uri.encodeComponent(r.spotifyAlbumId)}/mark',
        data: {
          'kind': kind.name,
          'title': r.title,
          'artist': r.artist,
          'primaryArtist': r.primaryArtist,
          'coverUrl': r.coverUrl,
        },
      );

  Future<void> unmark(String spotifyAlbumId) =>
      _dio.delete<void>('/albums/${Uri.encodeComponent(spotifyAlbumId)}/mark');

  Future<List<AlbumMark>> marks() async => [
        for (final m in (await _dio.get<List<dynamic>>('/marks')).data!)
          AlbumMark.fromJson(m as Map<String, dynamic>),
      ];

  Future<DiscogsStatus> discogs() async =>
      DiscogsStatus.fromJson((await _dio.get<Map<String, dynamic>>('/discogs')).data!);

  Future<DiscogsStatus> setDiscogsUsername(String? username) async => DiscogsStatus.fromJson(
      (await _dio.put<Map<String, dynamic>>('/discogs/username', data: {'username': username}))
          .data!);

  Future<DiscogsStatus> syncDiscogs() async => DiscogsStatus.fromJson(
      (await _dio.post<Map<String, dynamic>>('/discogs/sync',
              options: Options(receiveTimeout: const Duration(minutes: 3))))
          .data!);
}

/// Human-readable message for an API error.
String describeError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return "Can't reach the Vinylss server.";
    }
    return error.message ?? 'Request failed';
  }
  return error.toString();
}
