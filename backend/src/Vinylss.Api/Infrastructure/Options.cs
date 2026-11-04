namespace Vinylss.Api.Infrastructure;

public sealed class SpotifyOptions
{
    public string ClientId { get; set; } = "";
    public string ClientSecret { get; set; } = "";
    public string RedirectUri { get; set; } = "";
}

public sealed class DiscogsOptions
{
    public string Token { get; set; } = "";
    public string UserAgent { get; set; } = "Vinylss/0.1";
    public string Currency { get; set; } = "USD";
}

public sealed class JwtOptions
{
    public string SigningKey { get; set; } = "";
    public string Issuer { get; set; } = "vinylss";
    public int LifetimeDays { get; set; } = 30;
}

public sealed class AppOptions
{
    public List<string> AllowedReturnUrls { get; set; } = [];
}

public sealed class RecommendationOptions
{
    /// <summary>Maximum number of full album tracklists fetched from Spotify per run.</summary>
    public int MaxAlbumLookups { get; set; } = 150;

    /// <summary>Maximum number of Discogs vinyl lookups per run (Discogs allows ~60 requests/minute).</summary>
    public int MaxDiscogsLookups { get; set; } = 60;
}
