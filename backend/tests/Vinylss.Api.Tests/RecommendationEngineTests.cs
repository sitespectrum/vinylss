using Vinylss.Api.Recommendations;
using Vinylss.Api.Spotify;
using static Vinylss.Api.Tests.TestData;

namespace Vinylss.Api.Tests;

public class RecommendationEngineTests
{
    private static readonly SpotifyArtistRef A = Artist("a", "Artist A");
    private static readonly SpotifyArtistRef B = Artist("b", "Artist B");

    // Artist A: a 5-track studio album, its deluxe reissue, a single and a second album never played.
    private static readonly SpotifyAlbum Debut = Album("debut", "Debut", A, "album", "One", "Two", "Three", "Four", "Five");
    private static readonly SpotifyAlbum DebutDeluxe = Album("debut-dlx", "Debut (Deluxe Edition)", A, "album",
        "One", "Two", "Three", "Four", "Five", "Six (Demo)", "Seven (Demo)");
    private static readonly SpotifyAlbum Single = Album("single", "One", A, "single", "One");
    private static readonly SpotifyAlbum Second = Album("second", "Second", A, "album",
        "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta");
    private static readonly SpotifyAlbum BAlbum = Album("b-lp", "B Sides", B, "album", "X", "Y", "Z");

    private static FakeCatalog Catalog() =>
        new FakeCatalog().Add(Debut).Add(DebutDeluxe).Add(Single).Add(Second).Add(BAlbum);

    /// <summary>User plays 4 Debut songs, via the deluxe edition and the single, and one B track.</summary>
    private static ListeningProfile Profile()
    {
        var data = new ListeningData
        {
            SavedTracks =
            [
                Track("One", A, Single),
                Track("Two", A, DebutDeluxe),
                Track("Three - Remastered", A, DebutDeluxe),
                Track("Four", A, DebutDeluxe),
                Track("X", B, BAlbum),
            ],
        };
        data.TopArtists[SpotifyTimeRange.LongTerm] = [TopArtist(A)];
        return ListeningProfileBuilder.Build(data);
    }

    private static async Task<List<AlbumAnalysis>> Analyze(UserSettings? s = null, FakeCatalog? catalog = null) =>
        await new CandidateCollector().CollectAsync(Profile(), s ?? new UserSettings(), catalog ?? Catalog(), 100,
            CancellationToken.None);

    [Fact]
    public async Task Plays_of_deluxe_and_single_credit_the_standard_edition()
    {
        var analyses = await Analyze();

        var debut = analyses.Single(a => a.AlbumKey == "artist a|debut");
        Assert.Equal("debut", debut.Album.Id); // standard edition chosen over deluxe
        Assert.Equal(4, debut.MatchedTracks.Count);
        Assert.Equal(0.8, debut.Coverage, 3);
    }

    [Fact]
    public async Task Singles_are_excluded_unless_enabled()
    {
        var analyses = await Analyze();
        Assert.DoesNotContain(analyses, a => a.Album.AlbumType == "single");

        var withSingles = await Analyze(new UserSettings { IncludeSinglesAndEps = true });
        Assert.Contains(withSingles, a => a.Album.Id == "single");
    }

    [Fact]
    public async Task Album_lookups_are_capped()
    {
        var catalog = Catalog();
        await new CandidateCollector().CollectAsync(Profile(), new UserSettings(), catalog, 1, CancellationToken.None);
        Assert.Single(catalog.FetchedAlbumIds);
    }

    [Fact]
    public async Task MostListened_requires_min_matched_tracks()
    {
        var analyses = await Analyze();
        var strategy = new MostListenedAlbumsStrategy();

        var items = strategy.Select(analyses, new UserSettings { MinMatchedTracks = 3 }).ToList();

        var item = Assert.Single(items);
        Assert.Equal("Debut", item.Title);
        Assert.Equal("You play 4 of 5 tracks", item.Reason);
        Assert.Equal(4, item.MatchedTracks.Count);

        Assert.Equal(2, strategy.Select(analyses, new UserSettings { MinMatchedTracks = 1 }).Count());
    }

    [Fact]
    public async Task DeepCuts_picks_unexplored_albums_by_top_artists()
    {
        var analyses = await Analyze();

        var items = new DeepCutsStrategy().Select(analyses, new UserSettings()).ToList();

        // B isn't a top artist and Debut is well covered, so only Second qualifies.
        var item = Assert.Single(items);
        Assert.Equal("Second", item.Title);
        Assert.Contains("haven't played this one", item.Reason);
    }

    [Fact]
    public async Task DeepCuts_coverage_threshold_is_configurable()
    {
        var analyses = await Analyze();
        var items = new DeepCutsStrategy().Select(analyses, new UserSettings { DeepCutsMaxCoverage = 1 }).ToList();
        Assert.Contains(items, i => i.Title == "Debut");
    }

    private static readonly IRecommendationStrategy[] Strategies = [new DeepCutsStrategy(), new MostListenedAlbumsStrategy()];

    private static Task<(List<RecommendationSection> Sections, int DiscogsLookups)> Build(
        List<AlbumAnalysis> analyses, UserSettings s, Exclusions? ex = null, FakeVinylLookup? vinyl = null, int budget = 100) =>
        RecommendationPipeline.BuildSectionsAsync(analyses, s, Strategies, ex ?? new Exclusions(), vinyl, budget,
            CancellationToken.None);

    [Fact]
    public async Task Disabled_strategies_produce_no_section()
    {
        var analyses = await Analyze();

        var (sections, _) = await Build(analyses, new UserSettings { DeepCutsEnabled = false, VinylMode = VinylMode.Ignore });

        Assert.Equal(["mostListened"], sections.Select(s => s.Id));
    }

    [Fact]
    public async Task Album_only_appears_in_highest_priority_section()
    {
        var analyses = await Analyze();
        var s = new UserSettings { DeepCutsMaxCoverage = 1, VinylMode = VinylMode.Ignore };

        var (sections, _) = await Build(analyses, s);

        Assert.Equal("mostListened", sections[0].Id); // ordered by priority, not registration
        Assert.Contains(sections[0].Items, i => i.Title == "Debut");
        Assert.DoesNotContain(sections[1].Items, i => i.Title == "Debut");
    }

    [Fact]
    public async Task Marked_and_owned_albums_are_excluded()
    {
        var analyses = await Analyze();
        var s = new UserSettings { VinylMode = VinylMode.Ignore };

        var (byId, _) = await Build(analyses, s, new Exclusions { SpotifyAlbumIds = ["debut"] });
        Assert.Empty(byId[0].Items);

        // A Discogs collection entry for any edition excludes the album.
        var (byKey, _) = await Build(analyses, s,
            new Exclusions { AlbumKeys = [TextNormalizer.AlbumKey("Artist A", "Debut (Remastered)")] });
        Assert.Empty(byKey[0].Items);
    }

    [Fact]
    public async Task Owned_discogs_master_is_excluded_after_lookup()
    {
        var analyses = await Analyze();
        var vinyl = new FakeVinylLookup("Debut") { MasterIds = { ["Debut"] = 42 } };

        var (sections, _) = await Build(analyses, new UserSettings(), new Exclusions { DiscogsMasterIds = [42] }, vinyl);

        Assert.Empty(sections.Single(x => x.Id == "mostListened").Items);
    }

    [Fact]
    public async Task OnlyVinyl_drops_albums_without_a_pressing()
    {
        var analyses = await Analyze();
        var vinyl = new FakeVinylLookup("Debut");
        var s = new UserSettings { VinylMode = VinylMode.OnlyVinyl, DeepCutsMaxCoverage = 1, MinMatchedTracks = 1 };

        var (sections, lookups) = await Build(analyses, s, vinyl: vinyl);

        var all = sections.SelectMany(x => x.Items).ToList();
        var item = Assert.Single(all);
        Assert.Equal("Debut", item.Title);
        Assert.Equal(VinylStatus.Available, item.VinylStatus);
        Assert.Equal(vinyl.Lookups.Count, lookups);
    }

    [Fact]
    public async Task PreferVinyl_keeps_albums_without_a_pressing_but_ranks_them_lower()
    {
        var analyses = await Analyze();
        var vinyl = new FakeVinylLookup("B Sides");
        var s = new UserSettings { MinMatchedTracks = 1 };

        var (sections, _) = await Build(analyses, s, vinyl: vinyl);

        var items = sections.Single(x => x.Id == "mostListened").Items;
        Assert.Equal(2, items.Count);
        Assert.Equal(VinylStatus.NotFound, items.Single(i => i.Title == "Debut").VinylStatus);
        Assert.Equal(VinylStatus.Available, items.Single(i => i.Title == "B Sides").VinylStatus);
    }

    [Fact]
    public async Task Ignore_mode_skips_discogs_entirely()
    {
        var analyses = await Analyze();
        var vinyl = new FakeVinylLookup();

        var (sections, lookups) = await Build(analyses, new UserSettings { VinylMode = VinylMode.Ignore }, vinyl: vinyl);

        Assert.Equal(0, lookups);
        Assert.Empty(vinyl.Lookups);
        Assert.All(sections.SelectMany(x => x.Items), i => Assert.Equal(VinylStatus.Unknown, i.VinylStatus));
    }

    [Fact]
    public async Task Unavailable_discogs_falls_back_to_ignore()
    {
        var analyses = await Analyze();
        var vinyl = new FakeVinylLookup { IsAvailable = false };

        var (sections, _) = await Build(analyses, new UserSettings { VinylMode = VinylMode.OnlyVinyl }, vinyl: vinyl);

        Assert.NotEmpty(sections.SelectMany(x => x.Items));
        Assert.Empty(vinyl.Lookups);
    }

    [Fact]
    public async Task Discogs_budget_is_respected()
    {
        var analyses = await Analyze();
        var vinyl = new FakeVinylLookup();
        var s = new UserSettings { MinMatchedTracks = 1, DeepCutsMaxCoverage = 1 };

        var (_, lookups) = await Build(analyses, s, vinyl: vinyl, budget: 1);

        Assert.Equal(1, lookups);
        Assert.Single(vinyl.Lookups);
    }

    [Fact]
    public async Task Max_results_per_section_is_applied()
    {
        var analyses = await Analyze();
        var s = new UserSettings { MinMatchedTracks = 1, MaxResultsPerSection = 1, VinylMode = VinylMode.Ignore };

        var (sections, _) = await Build(analyses, s);

        Assert.All(sections, x => Assert.True(x.Items.Count <= 1));
    }
}
