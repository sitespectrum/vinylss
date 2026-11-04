namespace Vinylss.Api.Spotify;

// Minimal shapes of Spotify Web API objects (snake_case on the wire).

public sealed class SpotifyImage
{
    public string Url { get; init; } = "";
    public int? Width { get; init; }
    public int? Height { get; init; }
}

public sealed class SpotifyArtistRef
{
    public string Id { get; init; } = "";
    public string Name { get; init; } = "";
}

public sealed class SpotifyArtist
{
    public string Id { get; init; } = "";
    public string Name { get; init; } = "";
    public List<SpotifyImage> Images { get; init; } = [];
}

public sealed class SpotifyAlbum
{
    public string Id { get; init; } = "";
    public string Name { get; init; } = "";

    /// <summary>"album", "single" or "compilation".</summary>
    public string AlbumType { get; init; } = "album";

    /// <summary>Only set on artist album listings: "album", "single", "compilation", "appears_on".</summary>
    public string? AlbumGroup { get; init; }

    public int TotalTracks { get; init; }
    public string? ReleaseDate { get; init; }
    public List<SpotifyImage> Images { get; init; } = [];
    public List<SpotifyArtistRef> Artists { get; init; } = [];
    public Dictionary<string, string> ExternalUrls { get; init; } = [];
    public SpotifyPaging<SpotifyTrack>? Tracks { get; set; }
}

public sealed class SpotifyTrack
{
    public string? Id { get; init; }
    public string Name { get; init; } = "";
    public List<SpotifyArtistRef> Artists { get; init; } = [];
    public SpotifyAlbum? Album { get; init; }
    public bool IsLocal { get; init; }
}

public sealed class SpotifyPaging<T>
{
    public List<T> Items { get; init; } = [];
    public string? Next { get; init; }
    public int Total { get; init; }
}

public sealed class SpotifySavedTrack
{
    public SpotifyTrack? Track { get; init; }
}

public sealed class SpotifyPlayHistory
{
    public SpotifyTrack? Track { get; init; }
    public DateTime PlayedAt { get; init; }
}

public sealed class SpotifyUserProfile
{
    public string Id { get; init; } = "";
    public string? DisplayName { get; init; }
    public List<SpotifyImage> Images { get; init; } = [];
}

public sealed class SpotifyTokenResponse
{
    public string AccessToken { get; init; } = "";
    public string? RefreshToken { get; init; }
    public int ExpiresIn { get; init; }
    public string? Scope { get; init; }
}

public static class SpotifyTimeRange
{
    public const string LongTerm = "long_term";
    public const string MediumTerm = "medium_term";
    public const string ShortTerm = "short_term";
    public static readonly string[] All = [LongTerm, MediumTerm, ShortTerm];
}
