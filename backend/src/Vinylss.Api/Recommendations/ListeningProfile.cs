using Vinylss.Api.Spotify;

namespace Vinylss.Api.Recommendations;

/// <summary>Raw listening history pulled from Spotify.</summary>
public sealed class ListeningData
{
    public Dictionary<string, List<SpotifyTrack>> TopTracks { get; } = [];
    public Dictionary<string, List<SpotifyArtist>> TopArtists { get; } = [];
    public List<SpotifyTrack> SavedTracks { get; set; } = [];
    public List<SpotifyTrack> RecentlyPlayed { get; set; } = [];
}

/// <summary>One song the user listens to, merged across all versions/albums it appears on.</summary>
public sealed class TrackSignal
{
    /// <summary>primaryArtistId|normalizedTitle</summary>
    public required string Key { get; init; }

    public required string Name { get; init; }
    public required string NormalizedTitle { get; init; }
    public required HashSet<string> ArtistIds { get; init; }
    public required string PrimaryArtistId { get; init; }
    public double Weight { get; set; }
    public HashSet<string> Sources { get; } = [];

    /// <summary>Albums the user heard this song on (by album id).</summary>
    public Dictionary<string, SpotifyAlbum> Albums { get; } = [];
}

public sealed class ListeningProfile
{
    public Dictionary<string, TrackSignal> Tracks { get; } = [];
    public Dictionary<string, double> ArtistAffinity { get; } = [];
    public Dictionary<string, string> ArtistNames { get; } = [];

    /// <summary>Artist ids ordered by affinity, highest first.</summary>
    public List<string> RankedArtistIds { get; set; } = [];

    private Dictionary<string, List<TrackSignal>>? _byTitle;

    public IReadOnlyDictionary<string, List<TrackSignal>> ByTitle =>
        _byTitle ??= Tracks.Values.GroupBy(t => t.NormalizedTitle).ToDictionary(g => g.Key, g => g.ToList());
}
