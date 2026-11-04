using Vinylss.Api.Recommendations;
using Vinylss.Api.Spotify;
using static Vinylss.Api.Tests.TestData;

namespace Vinylss.Api.Tests;

public class ListeningProfileBuilderTests
{
    private static readonly SpotifyArtistRef A = Artist("a", "Artist A");
    private static readonly SpotifyAlbum Lp = Album("lp", "LP", A, "album", "One", "Two");
    private static readonly SpotifyAlbum Single = Album("single", "One", A, "single", "One");

    [Fact]
    public void Same_song_on_different_releases_merges_into_one_signal()
    {
        var data = new ListeningData { SavedTracks = [Track("One", A, Lp), Track("One - Remastered", A, Single)] };

        var profile = ListeningProfileBuilder.Build(data);

        var signal = Assert.Single(profile.Tracks.Values);
        Assert.Equal(2 * ListeningProfileBuilder.SavedWeight, signal.Weight);
        Assert.Equal(["lp", "single"], signal.Albums.Keys.Order());
    }

    [Fact]
    public void Top_tracks_weigh_more_than_saved_and_decay_with_rank()
    {
        var data = new ListeningData();
        data.TopTracks[SpotifyTimeRange.LongTerm] = [Track("One", A, Lp), Track("Two", A, Lp)];

        var profile = ListeningProfileBuilder.Build(data);

        var one = profile.Tracks.Values.Single(t => t.Name == "One");
        var two = profile.Tracks.Values.Single(t => t.Name == "Two");
        Assert.Equal(3.0, one.Weight, 3);
        Assert.True(two.Weight < one.Weight);
        Assert.True(two.Weight > ListeningProfileBuilder.SavedWeight);
    }

    [Fact]
    public void Recent_plays_are_capped_per_track()
    {
        var data = new ListeningData { RecentlyPlayed = Enumerable.Repeat(Track("One", A, Lp), 20).ToList() };

        var profile = ListeningProfileBuilder.Build(data);

        Assert.Equal(ListeningProfileBuilder.RecentPlayCap, profile.Tracks.Values.Single().Weight, 3);
    }

    [Fact]
    public void Artist_affinity_combines_top_artists_and_track_weight()
    {
        var b = Artist("b", "Artist B");
        var data = new ListeningData { SavedTracks = [Track("One", A, Lp)] };
        data.TopArtists[SpotifyTimeRange.LongTerm] = [TopArtist(b), TopArtist(A)];

        var profile = ListeningProfileBuilder.Build(data);

        Assert.True(profile.ArtistAffinity["a"] > profile.ArtistAffinity["b"] - 1);
        Assert.Equal(2, profile.RankedArtistIds.Count);
        Assert.Equal("Artist B", profile.ArtistNames["b"]);
    }

    [Fact]
    public void Local_tracks_are_ignored()
    {
        var data = new ListeningData
        {
            SavedTracks = [new SpotifyTrack { Id = null, Name = "Local", IsLocal = true, Artists = [A] }],
        };

        Assert.Empty(ListeningProfileBuilder.Build(data).Tracks);
    }
}
