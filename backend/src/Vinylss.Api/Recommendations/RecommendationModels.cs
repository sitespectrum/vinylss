using Vinylss.Api.Discogs;

namespace Vinylss.Api.Recommendations;

public enum VinylStatus
{
    /// <summary>Not checked (Discogs disabled, not configured, or lookup budget used up).</summary>
    Unknown,
    Available,
    NotFound,
}

public sealed record MatchedTrack(string Name, double Weight);

public sealed class RecommendationItem
{
    public required string SpotifyAlbumId { get; init; }
    public required string AlbumKey { get; init; }
    public required string Title { get; init; }
    public required string Artist { get; init; }
    public required string PrimaryArtist { get; init; }
    public string? Year { get; init; }
    public string? CoverUrl { get; init; }
    public string? SpotifyUrl { get; init; }
    public string AlbumType { get; init; } = "album";
    public required string Strategy { get; init; }
    public double Score { get; set; }
    public required string Reason { get; init; }
    public List<MatchedTrack> MatchedTracks { get; init; } = [];
    public int TotalTracks { get; init; }
    public double Coverage { get; init; }
    public VinylStatus VinylStatus { get; set; }
    public VinylInfo? Discogs { get; set; }

    public static RecommendationItem From(AlbumAnalysis a, string strategy, double score, string reason) => new()
    {
        SpotifyAlbumId = a.Album.Id,
        AlbumKey = a.AlbumKey,
        Title = a.Album.Name,
        Artist = string.Join(", ", a.Album.Artists.Select(x => x.Name)),
        PrimaryArtist = a.PrimaryArtistName,
        Year = a.Album.ReleaseDate is { Length: >= 4 } d ? d[..4] : null,
        CoverUrl = a.Album.Images.OrderByDescending(i => i.Width ?? 0).FirstOrDefault()?.Url,
        SpotifyUrl = a.Album.ExternalUrls.GetValueOrDefault("spotify"),
        AlbumType = a.Album.AlbumType,
        Strategy = strategy,
        Score = Math.Round(score, 3),
        Reason = reason,
        MatchedTracks = a.MatchedTracks.OrderByDescending(t => t.Weight)
            .Select(t => new MatchedTrack(t.Name, Math.Round(t.Weight, 2))).ToList(),
        TotalTracks = a.TotalTracks,
        Coverage = Math.Round(a.Coverage, 3),
    };
}

public sealed class RecommendationSection
{
    public required string Id { get; init; }
    public required string Title { get; init; }
    public required string Description { get; init; }
    public List<RecommendationItem> Items { get; set; } = [];
}

public sealed class RecommendationStats
{
    public int TracksAnalyzed { get; init; }
    public int ArtistsAnalyzed { get; init; }
    public int AlbumsAnalyzed { get; init; }
    public int DiscogsLookups { get; init; }
}

public sealed class RecommendationResult
{
    public DateTime GeneratedAt { get; init; } = DateTime.UtcNow;
    public List<RecommendationSection> Sections { get; init; } = [];
    public List<string> Warnings { get; init; } = [];
    public RecommendationStats Stats { get; init; } = new();
}
