import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinylss/api/models.dart';
import 'package:vinylss/features/recommendations/album_card.dart';
import 'package:vinylss/features/recommendations/album_details_sheet.dart';
import 'package:vinylss/features/recommendations/recommendations_controller.dart';
import 'package:vinylss/features/recommendations/recommendations_screen.dart';
import 'package:vinylss/features/recommendations/section_screen.dart';
import 'package:vinylss/features/settings/settings_screen.dart';
import 'package:vinylss/ui/theme.dart';
import 'package:vinylss/ui/vinyl.dart';

Recommendation rec({VinylStatus status = VinylStatus.available}) => Recommendation.fromJson(recJson(status));

Map<String, dynamic> recJson(VinylStatus status) => {
      'spotifyAlbumId': 'abc',
      'title': 'Abbey Road',
      'artist': 'The Beatles',
      'primaryArtist': 'The Beatles',
      'year': '1969',
      'strategy': 'mostListened',
      'reason': 'You play 3 of 17 tracks',
      'matchedTracks': [
        {'name': 'Come Together', 'weight': 3.0},
        {'name': 'Something', 'weight': 2.0},
        {'name': 'Here Comes the Sun', 'weight': 1.0},
      ],
      'totalTracks': 17,
      'vinylStatus': status.name,
      'discogs': status == VinylStatus.available
          ? {'hasVinyl': true, 'lowestPrice': 18.5, 'currency': 'USD', 'url': 'https://discogs.com'}
          : null,
    };

class _FakeRecommendations extends RecommendationsController {
  _FakeRecommendations(this.snapshot);

  final RecommendationSnapshot snapshot;

  @override
  Future<RecommendationSnapshot> build() async => snapshot;
}

void main() {
  testWidgets('album card shows tracks you play and vinyl price', (tester) async {
    MarkKind? marked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 220,
          height: 320,
          child: AlbumCard(item: rec(), onTap: () {}, onMark: (_, k) => marked = k),
        ),
      ),
    ));

    expect(find.text('Abbey Road'), findsOneWidget);
    expect(find.text('The Beatles · 1969'), findsOneWidget);
    expect(find.text('3 of 17 tracks you play'), findsOneWidget);
    expect(find.text('\$18.50'), findsOneWidget, reason: 'price sticker on the sleeve');
    expect(find.byIcon(Icons.more_vert), findsNothing, reason: 'touch uses long-press instead');

    await tester.longPress(find.text('Abbey Road'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I own this'));
    await tester.pumpAndSettle();
    expect(marked, MarkKind.owned);
  });

  testWidgets('album card flags missing vinyl', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 220,
          height: 320,
          child: AlbumCard(item: rec(status: VinylStatus.notFound), onTap: () {}, onMark: (_, _) {}),
        ),
      ),
    ));
    expect(find.text('NO'), findsOneWidget, reason: 'grey "no vinyl" sticker');
  });

  testWidgets('album card shows the actions button on hover devices', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 220,
          height: 320,
          child: AlbumCard(item: rec(), onTap: () {}, onMark: (_, _) {}),
        ),
      ),
    ));
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('settings toggles enable save and update the draft', (tester) async {
    final settings = UserSettings({
      'mostListenedEnabled': true,
      'deepCutsEnabled': true,
      'minMatchedTracks': 3,
      'deepCutsMaxCoverage': 0.2,
      'topArtistsToExplore': 15,
      'useTopTracksLongTerm': true,
      'useTopTracksMediumTerm': true,
      'useTopTracksShortTerm': true,
      'useSavedTracks': true,
      'useRecentlyPlayed': true,
      'includeSinglesAndEps': false,
      'includeCompilations': false,
      'vinylMode': 'preferVinyl',
      'excludeDiscogsCollection': true,
      'maxResultsPerSection': 30,
    });

    await tester.binding.setSurfaceSize(const Size(800, 2400));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsProvider.overrideWith((_) async => settings),
        discogsStatusProvider.overrideWith((_) async => DiscogsStatus(configured: true, itemCount: 0)),
        meProvider.overrideWith((_) async => Me(id: '1', displayName: 'Test')),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Save & refresh');
    expect(save, findsNothing, reason: 'save bar only appears with unsaved changes');

    final deepCuts = find.widgetWithText(SwitchListTile, 'Deep cuts from favourite artists');
    expect(tester.widget<SwitchListTile>(deepCuts).value, isTrue);
    await tester.tap(deepCuts);
    await tester.pump();

    expect(tester.widget<SwitchListTile>(deepCuts).value, isFalse);
    await tester.pumpAndSettle();
    expect(save, findsOneWidget);

    await tester.tap(find.text('Any album'));
    await tester.pump();
    expect(find.text('Skip Discogs and just recommend albums.'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(save, findsNothing);
    expect(tester.widget<SwitchListTile>(deepCuts).value, isTrue);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('album details number tracks by record side', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildVinylssTheme(),
      home: Scaffold(body: AlbumDetails(item: rec(), onMark: (_, _) {})),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Vinyl from \$18.50'), findsOneWidget);
    expect(find.text('SIDE A'), findsOneWidget);
    expect(find.text('SIDE B'), findsOneWidget);
    expect(find.text('A2'), findsOneWidget);
    expect(find.text('B1'), findsOneWidget);
    expect(find.text('Here Comes the Sun'), findsOneWidget);
  });

  testWidgets('spinning record holds still when animations are disabled', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Center(child: SpinningRecord()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(VinylDisc), findsOneWidget);
  });

  testWidgets('home shows a shelf per section and "Show all" opens the section', (tester) async {
    final snapshot = RecommendationSnapshot.fromJson({
      'status': 'ready',
      'generatedAt': '2026-11-04T10:00:00Z',
      'result': {
        'sections': [
          {
            'id': 'mostListened',
            'title': 'Albums you already love',
            'description': 'Records full of tracks you play',
            'items': [recJson(VinylStatus.available)],
          },
        ],
      },
    });
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const RecommendationsScreen(),
        routes: [
          GoRoute(
            path: 'section/:id',
            builder: (_, state) => SectionScreen(sectionId: state.pathParameters['id']!),
          ),
        ],
      ),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        recommendationsProvider.overrideWith(() => _FakeRecommendations(snapshot)),
        meProvider.overrideWith((_) async => Me(id: '1', displayName: 'Test')),
      ],
      child: MaterialApp.router(theme: buildVinylssTheme(), routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Albums you already love'), findsOneWidget);
    expect(find.text('Abbey Road'), findsOneWidget);

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('Records full of tracks you play · 1 album'), findsOneWidget);
    expect(find.text('Abbey Road'), findsOneWidget);
  });

  test('settings set() keeps unknown keys and encodes enums', () {
    final s = const UserSettings({'future': 1}).set('vinylMode', VinylMode.onlyVinyl);
    expect(s.json, {'future': 1, 'vinylMode': 'onlyVinyl'});
    expect(s.vinylMode, VinylMode.onlyVinyl);
  });

  test('snapshot parsing', () {
    final s = RecommendationSnapshot.fromJson({
      'status': 'ready',
      'generatedAt': '2026-11-04T10:00:00Z',
      'result': {
        'sections': [
          {'id': 'deepCuts', 'title': 'T', 'description': 'D', 'items': []},
        ],
        'warnings': ['w'],
      },
    });
    expect(s.status, SnapshotStatus.ready);
    expect(s.sections.single.id, 'deepCuts');
    expect(s.warnings, ['w']);
    expect(s.isWorking, isFalse);
  });
}
