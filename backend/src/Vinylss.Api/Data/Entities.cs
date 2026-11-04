namespace Vinylss.Api.Data;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string SpotifyUserId { get; set; }
    public string DisplayName { get; set; } = "";
    public string? AvatarUrl { get; set; }
    public string SpotifyAccessToken { get; set; } = "";
    public string SpotifyRefreshToken { get; set; } = "";
    public DateTime SpotifyTokenExpiresAt { get; set; }
    public string? DiscogsUsername { get; set; }
    public DateTime? LastDiscogsSync { get; set; }
    public string SettingsJson { get; set; } = "{}";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public enum MarkKind
{
    Owned,
    NotInterested,
}

/// <summary>An album the user has flagged as owned or not interesting; excluded from recommendations.</summary>
public class AlbumMark
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public required string SpotifyAlbumId { get; set; }
    public required string AlbumKey { get; set; }
    public string Title { get; set; } = "";
    public string Artist { get; set; } = "";
    public string? CoverUrl { get; set; }
    public MarkKind Kind { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>A release from the user's Discogs collection.</summary>
public class DiscogsCollectionItem
{
    public long Id { get; set; }
    public Guid UserId { get; set; }
    public long ReleaseId { get; set; }
    public long? MasterId { get; set; }
    public string Artist { get; set; } = "";
    public string Title { get; set; } = "";
    public required string AlbumKey { get; set; }
}

/// <summary>Generic JSON cache for third-party API responses.</summary>
public class CacheEntry
{
    public required string Key { get; set; }
    public required string Json { get; set; }
    public DateTime ExpiresAt { get; set; }
}

public enum SnapshotStatus
{
    Idle,
    Queued,
    Running,
    Ready,
    Failed,
}

/// <summary>Latest recommendation run for a user. ResultJson holds the last successful result.</summary>
public class RecommendationSnapshot
{
    public Guid UserId { get; set; }
    public SnapshotStatus Status { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? GeneratedAt { get; set; }
    public string? ResultJson { get; set; }
    public string? Error { get; set; }
}
