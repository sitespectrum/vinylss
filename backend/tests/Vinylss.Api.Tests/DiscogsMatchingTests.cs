using Vinylss.Api.Discogs;
using Vinylss.Api.Recommendations;

namespace Vinylss.Api.Tests;

public class DiscogsMatchingTests
{
    private static DiscogsSearchResult R(long id, string title, long? master = null, int have = 0) =>
        new() { Id = id, Title = title, MasterId = master, Community = new DiscogsCommunity { Have = have } };

    [Fact]
    public void Picks_most_collected_exact_match()
    {
        var best = DiscogsVinylLookup.PickBestMatch(
            [R(1, "Radiohead - OK Computer", 10, 50), R(2, "Radiohead - OK Computer", 10, 900), R(3, "Radiohead - OK Computer OKNOTOK 1997 2017", 11, 5000)],
            "Radiohead", "OK Computer");

        Assert.Equal(2, best?.Id);
    }

    [Fact]
    public void Ignores_edition_qualifiers_and_discogs_artist_suffixes()
    {
        var best = DiscogsVinylLookup.PickBestMatch([R(1, "Nirvana (2) - Nevermind", 5)], "Nirvana",
            "Nevermind (Remastered)");

        Assert.Equal(1, best?.Id);
    }

    [Fact]
    public void Prefers_artist_match_over_title_only_match()
    {
        var best = DiscogsVinylLookup.PickBestMatch(
            [R(1, "Someone Else - Greatest Hits", 1, 9999), R(2, "Queen - Greatest Hits", 2, 10)],
            "Queen", "Greatest Hits");

        Assert.Equal(2, best?.Id);
    }

    [Fact]
    public void Rejects_loose_matches()
    {
        Assert.Null(DiscogsVinylLookup.PickBestMatch([R(1, "Radiohead - Kid A Mnesia")], "Radiohead", "Kid A"));
    }

    [Fact]
    public void Settings_roundtrip_and_sanitize()
    {
        var s = new UserSettings { MinMatchedTracks = 999, VinylMode = VinylMode.OnlyVinyl, DeepCutsEnabled = false };

        var back = UserSettings.FromJson(s.ToJson());

        Assert.Equal(30, back.MinMatchedTracks);
        Assert.Equal(VinylMode.OnlyVinyl, back.VinylMode);
        Assert.False(back.DeepCutsEnabled);
        Assert.Contains("\"onlyVinyl\"", s.ToJson());
        Assert.True(UserSettings.FromJson("not json").MostListenedEnabled);
    }
}
