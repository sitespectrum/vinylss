// Data models mirroring the backend's JSON (camelCase).

class Me {
  Me({required this.id, required this.displayName, this.avatarUrl});

  final String id;
  final String displayName;
  final String? avatarUrl;

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        id: j['id'] as String,
        displayName: j['displayName'] as String? ?? '',
        avatarUrl: j['avatarUrl'] as String?,
      );
}

enum VinylMode { onlyVinyl, preferVinyl, ignore }

/// User preferences. Kept as a JSON map so new backend settings round-trip untouched.
class UserSettings {
  const UserSettings(this.json);

  final Map<String, dynamic> json;

  bool flag(String key) => json[key] as bool? ?? false;
  num number(String key) => json[key] as num? ?? 0;

  VinylMode get vinylMode => VinylMode.values.firstWhere(
        (m) => m.name == json['vinylMode'],
        orElse: () => VinylMode.preferVinyl,
      );

  UserSettings set(String key, Object value) =>
      UserSettings({...json, key: value is VinylMode ? value.name : value});
}

enum SnapshotStatus { idle, queued, running, ready, failed }

enum VinylStatus { unknown, available, notFound }

class VinylInfo {
  VinylInfo({
    required this.hasVinyl,
    this.url,
    this.marketplaceUrl,
    this.lowestPrice,
    this.currency,
    this.numForSale,
    this.year,
  });

  final bool hasVinyl;
  final String? url;
  final String? marketplaceUrl;
  final double? lowestPrice;
  final String? currency;
  final int? numForSale;
  final String? year;

  factory VinylInfo.fromJson(Map<String, dynamic> j) => VinylInfo(
        hasVinyl: j['hasVinyl'] as bool? ?? false,
        url: j['url'] as String?,
        marketplaceUrl: j['marketplaceUrl'] as String?,
        lowestPrice: (j['lowestPrice'] as num?)?.toDouble(),
        currency: j['currency'] as String?,
        numForSale: j['numForSale'] as int?,
        year: j['year'] as String?,
      );
}

class MatchedTrack {
  MatchedTrack(this.name, this.weight);

  final String name;
  final double weight;
}

class Recommendation {
  Recommendation({
    required this.spotifyAlbumId,
    required this.title,
    required this.artist,
    required this.primaryArtist,
    required this.strategy,
    required this.reason,
    required this.matchedTracks,
    required this.totalTracks,
    required this.vinylStatus,
    this.year,
    this.coverUrl,
    this.spotifyUrl,
    this.discogs,
  });

  final String spotifyAlbumId;
  final String title;
  final String artist;
  final String primaryArtist;
  final String strategy;
  final String reason;
  final List<MatchedTrack> matchedTracks;
  final int totalTracks;
  final VinylStatus vinylStatus;
  final String? year;
  final String? coverUrl;
  final String? spotifyUrl;
  final VinylInfo? discogs;

  factory Recommendation.fromJson(Map<String, dynamic> j) => Recommendation(
        spotifyAlbumId: j['spotifyAlbumId'] as String,
        title: j['title'] as String,
        artist: j['artist'] as String? ?? '',
        primaryArtist: j['primaryArtist'] as String? ?? '',
        strategy: j['strategy'] as String? ?? '',
        reason: j['reason'] as String? ?? '',
        matchedTracks: [
          for (final t in (j['matchedTracks'] as List? ?? const []))
            MatchedTrack(t['name'] as String, (t['weight'] as num).toDouble()),
        ],
        totalTracks: j['totalTracks'] as int? ?? 0,
        vinylStatus: VinylStatus.values.firstWhere(
          (s) => s.name == j['vinylStatus'],
          orElse: () => VinylStatus.unknown,
        ),
        year: j['year'] as String?,
        coverUrl: j['coverUrl'] as String?,
        spotifyUrl: j['spotifyUrl'] as String?,
        discogs: j['discogs'] == null
            ? null
            : VinylInfo.fromJson(j['discogs'] as Map<String, dynamic>),
      );
}

class RecommendationSection {
  RecommendationSection({
    required this.id,
    required this.title,
    required this.description,
    required this.items,
  });

  final String id;
  final String title;
  final String description;
  final List<Recommendation> items;

  factory RecommendationSection.fromJson(Map<String, dynamic> j) =>
      RecommendationSection(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String? ?? '',
        items: [
          for (final i in (j['items'] as List? ?? const []))
            Recommendation.fromJson(i as Map<String, dynamic>),
        ],
      );

  RecommendationSection without(String spotifyAlbumId) => RecommendationSection(
        id: id,
        title: title,
        description: description,
        items: items.where((i) => i.spotifyAlbumId != spotifyAlbumId).toList(),
      );
}

class RecommendationSnapshot {
  RecommendationSnapshot({
    required this.status,
    required this.sections,
    required this.warnings,
    this.generatedAt,
    this.error,
  });

  final SnapshotStatus status;
  final List<RecommendationSection> sections;
  final List<String> warnings;
  final DateTime? generatedAt;
  final String? error;

  bool get isWorking =>
      status == SnapshotStatus.queued || status == SnapshotStatus.running;

  factory RecommendationSnapshot.fromJson(Map<String, dynamic> j) {
    final result = j['result'] as Map<String, dynamic>?;
    return RecommendationSnapshot(
      status: SnapshotStatus.values.firstWhere(
        (s) => s.name == j['status'],
        orElse: () => SnapshotStatus.idle,
      ),
      sections: [
        for (final s in (result?['sections'] as List? ?? const []))
          RecommendationSection.fromJson(s as Map<String, dynamic>),
      ],
      warnings: [
        for (final w in (result?['warnings'] as List? ?? const [])) w as String,
      ],
      generatedAt: j['generatedAt'] == null
          ? null
          : DateTime.parse(j['generatedAt'] as String).toLocal(),
      error: j['error'] as String?,
    );
  }

  RecommendationSnapshot copyWith({
    SnapshotStatus? status,
    List<RecommendationSection>? sections,
  }) =>
      RecommendationSnapshot(
        status: status ?? this.status,
        sections: sections ?? this.sections,
        warnings: warnings,
        generatedAt: generatedAt,
        error: error,
      );
}

enum MarkKind { owned, notInterested }

class AlbumMark {
  AlbumMark({
    required this.spotifyAlbumId,
    required this.title,
    required this.artist,
    required this.kind,
    this.coverUrl,
  });

  final String spotifyAlbumId;
  final String title;
  final String artist;
  final MarkKind kind;
  final String? coverUrl;

  factory AlbumMark.fromJson(Map<String, dynamic> j) => AlbumMark(
        spotifyAlbumId: j['spotifyAlbumId'] as String,
        title: j['title'] as String,
        artist: j['artist'] as String? ?? '',
        kind: MarkKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => MarkKind.notInterested,
        ),
        coverUrl: j['coverUrl'] as String?,
      );
}

class DiscogsStatus {
  DiscogsStatus({
    required this.configured,
    required this.itemCount,
    this.username,
    this.lastSync,
  });

  final bool configured;
  final int itemCount;
  final String? username;
  final DateTime? lastSync;

  factory DiscogsStatus.fromJson(Map<String, dynamic> j) => DiscogsStatus(
        configured: j['configured'] as bool? ?? false,
        itemCount: j['itemCount'] as int? ?? 0,
        username: j['username'] as String?,
        lastSync: j['lastSync'] == null
            ? null
            : DateTime.parse(j['lastSync'] as String).toLocal(),
      );
}
