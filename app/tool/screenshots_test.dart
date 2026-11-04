// Renders every screen with sample data and writes PNGs, for design review.
//
//   flutter test tool/screenshots_test.dart
//
// Output goes to build/screenshots (override with --dart-define=SCREENSHOT_DIR=...).
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart' as flutter_test;
import 'package:vinylss/api/models.dart';
import 'package:vinylss/auth/auth_controller.dart';
import 'package:vinylss/features/marks/marks_screen.dart';
import 'package:vinylss/features/recommendations/album_card.dart';
import 'package:vinylss/features/recommendations/recommendations_controller.dart';
import 'package:vinylss/features/settings/settings_screen.dart';
import 'package:vinylss/main.dart';
import 'package:vinylss/ui/vinyl.dart';

const outDir = String.fromEnvironment('SCREENSHOT_DIR', defaultValue: 'build/screenshots');

final _boundary = GlobalKey();

class Device {
  const Device(this.name, this.size, this.ratio, this.platform);

  final String name;
  final Size size;
  final double ratio;
  final TargetPlatform platform;
}

const devices = [
  Device('phone', Size(390, 844), 2, TargetPlatform.android),
  Device('desktop', Size(1280, 820), 1, TargetPlatform.linux),
];

// ---------------------------------------------------------------------------
// Sample data

const _albums = [
  ('In Rainbows', 'Radiohead', '2007', 10, 7),
  ('Currents', 'Tame Impala', '2015', 13, 9),
  ('Blonde', 'Frank Ocean', '2016', 17, 8),
  ('Random Access Memories', 'Daft Punk', '2013', 13, 6),
  ('Kid A', 'Radiohead', '2000', 10, 5),
  ('Rumours', 'Fleetwood Mac', '1977', 11, 5),
  ('Channel Orange', 'Frank Ocean', '2012', 17, 4),
  ('Lonerism', 'Tame Impala', '2012', 12, 4),
  ('Discovery', 'Daft Punk', '2001', 14, 3),
  ('Hounds of Love', 'Kate Bush', '1985', 12, 3),
];

const _deepCuts = [
  ('Amnesiac', 'Radiohead', '2001'),
  ('Innerspeaker', 'Tame Impala', '2010'),
  ('Homework', 'Daft Punk', '1997'),
  ('Tusk', 'Fleetwood Mac', '1979'),
  ('The Dreaming', 'Kate Bush', '1982'),
  ('Endless', 'Frank Ocean', '2016'),
  ('Hail to the Thief', 'Radiohead', '2003'),
];

const _tracks = [
  'Opening Night', 'Weird Fishes', 'Reckoner', 'House of Cards', 'Nude', 'Videotape',
  'Jigsaw Falling', 'All I Need', 'Faust Arp', 'Bodysnatchers',
];

Map<String, dynamic> _rec(int i, String title, String artist, String year,
    {required String strategy, int total = 12, int matched = 0}) {
  final status = i % 4 == 3 ? 'notFound' : 'available';
  return {
    'spotifyAlbumId': '$strategy-$i',
    'title': title,
    'artist': artist,
    'primaryArtist': artist,
    'year': year,
    'strategy': strategy,
    'reason': matched > 0
        ? 'You play $matched of its $total tracks, including singles and remasters that '
            'count toward this album.'
        : 'You listen to $artist a lot, but have barely played this album.',
    'matchedTracks': [
      for (var t = 0; t < matched; t++) {'name': _tracks[t % _tracks.length], 'weight': 1.0},
    ],
    'totalTracks': total,
    'vinylStatus': status,
    'coverUrl': 'cover://$title',
    'spotifyUrl': 'https://open.spotify.com/album/x',
    'discogs': status == 'available'
        ? {
            'hasVinyl': true,
            'lowestPrice': 14.0 + i * 3.25,
            'currency': 'USD',
            'numForSale': 40 - i * 3,
            'url': 'https://discogs.com',
          }
        : {'hasVinyl': false},
  };
}

RecommendationSnapshot snapshot({String status = 'ready', bool empty = false}) =>
    RecommendationSnapshot.fromJson({
      'status': status,
      'generatedAt': empty ? null : '2026-11-04T10:00:00Z',
      'result': empty
          ? null
          : {
              'sections': [
                {
                  'id': 'mostListened',
                  'title': 'Albums you already love',
                  'description': 'Records full of the tracks you play most',
                  'items': [
                    for (final (i, a) in _albums.indexed)
                      _rec(i, a.$1, a.$2, a.$3, strategy: 'mostListened', total: a.$4, matched: a.$5),
                  ],
                },
                {
                  'id': 'deepCuts',
                  'title': 'Deep cuts',
                  'description': 'Albums by your favourite artists that you have barely heard',
                  'items': [
                    for (final (i, a) in _deepCuts.indexed)
                      _rec(i, a.$1, a.$2, a.$3, strategy: 'deepCuts'),
                  ],
                },
              ],
              'warnings': <String>[],
            },
    });

final settings = UserSettings({
  'mostListenedEnabled': true,
  'deepCutsEnabled': true,
  'minMatchedTracks': 3,
  'deepCutsMaxCoverage': 0.2,
  'topArtistsToExplore': 20,
  'useTopTracksLongTerm': true,
  'useTopTracksMediumTerm': true,
  'useTopTracksShortTerm': false,
  'useSavedTracks': true,
  'useRecentlyPlayed': true,
  'includeSinglesAndEps': false,
  'includeCompilations': false,
  'vinylMode': 'preferVinyl',
  'excludeDiscogsCollection': true,
  'maxResultsPerSection': 30,
});

final marks = [
  for (final (i, a) in _albums.take(6).indexed)
    AlbumMark(
      spotifyAlbumId: 'm$i',
      title: a.$1,
      artist: a.$2,
      kind: i < 4 ? MarkKind.owned : MarkKind.notInterested,
      coverUrl: 'cover://${a.$1}',
    ),
];

// ---------------------------------------------------------------------------
// Fakes

class _FakeAuth extends AuthController {
  _FakeAuth(this.loggedIn);

  final bool loggedIn;

  @override
  AuthState build() => AuthState(token: loggedIn ? 'token' : null);
}

class _FakeRecommendations extends RecommendationsController {
  _FakeRecommendations(this.value);

  final RecommendationSnapshot value;

  @override
  Future<RecommendationSnapshot> build() async => value;
}

/// Generated abstract album art, so screenshots look like real use.
class _Cover extends StatelessWidget {
  const _Cover(this.title);

  final String title;

  static const _palettes = [
    [Color(0xFF1B3A4B), Color(0xFFE76F51), Color(0xFFF4A261)],
    [Color(0xFF3D1E6D), Color(0xFFFF6B9A), Color(0xFFFFC2D1)],
    [Color(0xFFF1E9DA), Color(0xFF2E294E), Color(0xFFD90368)],
    [Color(0xFF0B3D2E), Color(0xFF9BC53D), Color(0xFFE8F1C0)],
    [Color(0xFF111111), Color(0xFFC0C0C0), Color(0xFFFF3B30)],
    [Color(0xFFE9C46A), Color(0xFF264653), Color(0xFF2A9D8F)],
    [Color(0xFF6A040F), Color(0xFFFFBA08), Color(0xFFF48C06)],
    [Color(0xFF14213D), Color(0xFF8ECAE6), Color(0xFFFFB703)],
  ];

  @override
  Widget build(BuildContext context) {
    final h = title.codeUnits.fold(7, (a, c) => (a * 31 + c) & 0x7fffffff);
    final p = _palettes[h % _palettes.length];
    return LayoutBuilder(builder: (context, c) {
      final s = c.biggest.shortestSide;
      return ClipRect(
        child: CustomPaint(
          painter: _CoverPainter(p, h % 3),
          child: Padding(
            padding: EdgeInsets.all(s * 0.07),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                title.toUpperCase(),
                maxLines: 2,
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontWeight: FontWeight.w800,
                  fontSize: s * 0.09,
                  height: 1,
                  letterSpacing: s * 0.004,
                  color: p[2],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.p, this.kind);

  final List<Color> p;
  final int kind;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = p[0]);
    final w = size.width;
    switch (kind) {
      case 0:
        canvas.drawCircle(Offset(w * 0.62, w * 0.4), w * 0.3, Paint()..color = p[1]);
        canvas.drawCircle(Offset(w * 0.62, w * 0.4), w * 0.12, Paint()..color = p[0]);
      case 1:
        for (var i = 0; i < 6; i++) {
          canvas.drawRect(Rect.fromLTWH(0, w * (0.12 + i * 0.09), w, w * 0.045),
              Paint()..color = Color.lerp(p[1], p[2], i / 6)!);
        }
      default:
        final path = Path()
          ..moveTo(0, w * 0.75)
          ..lineTo(w * 0.55, w * 0.1)
          ..lineTo(w, w * 0.6)
          ..lineTo(w, w)
          ..lineTo(0, w)
          ..close();
        canvas.drawPath(path, Paint()..color = p[1]);
        canvas.drawCircle(Offset(w * 0.25, w * 0.25), w * 0.09, Paint()..color = p[2]);
    }
    // Faint print grain.
    final rnd = math.Random(kind);
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.04);
    for (var i = 0; i < 200; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * size.height), 0.6, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Harness

Future<void> _loadFonts() async {
  final family = FontLoader('Figtree');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    family.addFont(_bytes('assets/fonts/Figtree-$w.ttf'));
  }
  await family.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  final icons = FontLoader('MaterialIcons')
    ..addFont(_bytes('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<ByteData> _bytes(String path) async =>
    ByteData.sublistView(Uint8List.fromList(File(path).readAsBytesSync()));

Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  Device device, {
  bool loggedIn = true,
  RecommendationSnapshot? recs,
  String location = '/',
}) async {
  tester.view.physicalSize = device.size * device.ratio;
  tester.view.devicePixelRatio = device.ratio;
  debugDefaultTargetPlatformOverride = device.platform;

  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authProvider.overrideWith(() => _FakeAuth(loggedIn)),
      recommendationsProvider.overrideWith(() => _FakeRecommendations(recs ?? snapshot())),
      meProvider.overrideWith((_) async => Me(id: '1', displayName: 'Robin')),
      settingsProvider.overrideWith((_) async => settings),
      discogsStatusProvider.overrideWith((_) async => DiscogsStatus(
            configured: true,
            username: 'robin_spins',
            itemCount: 214,
            lastSync: DateTime.now().subtract(const Duration(hours: 3)),
          )),
      marksProvider.overrideWith((_) async => marks),
    ],
    child: RepaintBoundary(key: _boundary, child: const VinylssApp()),
  ));
  final container = ProviderScope.containerOf(tester.element(find.byType(VinylssApp)));
  if (location != '/') container.read(routerProvider).go(location);
  await settle(tester);
  return container;
}

/// Lets futures resolve and animations play out; spinning records never settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> shot(WidgetTester tester, Device device, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundary));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: device.ratio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$outDir/${device.name}-$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    debugArtworkBuilder = (url) => _Cover(url.replaceFirst('cover://', ''));
    await _loadFonts();
  });

  for (final d in devices) {
    group(d.name, () {
      // The platform override must be cleared before the test ends.
      void testWidgets(String name, WidgetTesterCallback body) =>
          flutter_test.testWidgets(name, (tester) async {
            try {
              await body(tester);
            } finally {
              debugDefaultTargetPlatformOverride = null;
            }
          });

      testWidgets('login', (tester) async {
        await pumpApp(tester, d, loggedIn: false);
        await shot(tester, d, '01-login');
      });

      testWidgets('home', (tester) async {
        await pumpApp(tester, d);
        await shot(tester, d, '02-home');
      });

      testWidgets('home while working', (tester) async {
        await pumpApp(tester, d, recs: snapshot(status: 'running'));
        await shot(tester, d, '03-home-working');
      });

      testWidgets('first run', (tester) async {
        await pumpApp(tester, d, recs: snapshot(status: 'running', empty: true));
        await shot(tester, d, '04-home-first-run');
      });

      testWidgets('section', (tester) async {
        await pumpApp(tester, d, location: '/section/mostListened');
        await shot(tester, d, '05-section');
      });

      testWidgets('album details', (tester) async {
        await pumpApp(tester, d);
        await tester.tap(find.byType(AlbumCard).first);
        await settle(tester);
        await shot(tester, d, '06-details');
      });

      testWidgets('library', (tester) async {
        await pumpApp(tester, d, location: '/library');
        await shot(tester, d, '07-library');
      });

      testWidgets('settings', (tester) async {
        await pumpApp(tester, d, location: '/settings');
        await shot(tester, d, '08-settings');
        await tester.tap(find.text('Top tracks: last 4 weeks'));
        await settle(tester);
        await shot(tester, d, '08b-settings-unsaved');
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -1400));
        await settle(tester);
        await shot(tester, d, '09-settings-bottom');
      });
    });
  }
}
