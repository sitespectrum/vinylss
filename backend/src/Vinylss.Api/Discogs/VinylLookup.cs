using Vinylss.Api.Infrastructure;
using Vinylss.Api.Recommendations;

namespace Vinylss.Api.Discogs;

public interface IVinylLookup
{
    bool IsAvailable { get; }

    Task<VinylInfo> LookupAsync(string artist, string albumTitle, CancellationToken ct);
}

/// <summary>Finds a vinyl pressing of an album on Discogs. Results (including misses) are cached.</summary>
public sealed class DiscogsVinylLookup(DiscogsClient discogs, DbCache cache, ILogger<DiscogsVinylLookup> log)
    : IVinylLookup
{
    public bool IsAvailable => discogs.IsConfigured;

    public Task<VinylInfo> LookupAsync(string artist, string albumTitle, CancellationToken ct) =>
        cache.GetOrCreateAsync($"dg:vinyl:{TextNormalizer.AlbumKey(artist, albumTitle)}", TimeSpan.FromDays(3),
            c => FetchAsync(artist, albumTitle, c), ct);

    private async Task<VinylInfo> FetchAsync(string artist, string albumTitle, CancellationToken ct)
    {
        var search = await discogs.SearchVinylReleasesAsync(artist, TextNormalizer.StripQualifiers(albumTitle), ct);
        var best = PickBestMatch(search?.Results ?? [], artist, albumTitle);
        if (best is null) return new VinylInfo { HasVinyl = false };

        DiscogsMarketplaceStats? stats = null;
        try
        {
            stats = await discogs.GetMarketplaceStatsAsync(best.Id, ct);
        }
        catch (DiscogsApiException ex)
        {
            log.LogWarning(ex, "Discogs marketplace stats failed for release {Id}", best.Id);
        }

        var hasMaster = best.MasterId is > 0;
        return new VinylInfo
        {
            HasVinyl = true,
            ReleaseId = best.Id,
            MasterId = hasMaster ? best.MasterId : null,
            Url = hasMaster
                ? $"https://www.discogs.com/master/{best.MasterId}"
                : $"https://www.discogs.com/release/{best.Id}",
            MarketplaceUrl = hasMaster
                ? $"https://www.discogs.com/sell/list?master_id={best.MasterId}&format=Vinyl"
                : $"https://www.discogs.com/sell/release/{best.Id}",
            CoverUrl = best.CoverImage,
            Year = best.Year,
            LowestPrice = stats?.LowestPrice?.Value,
            Currency = stats?.LowestPrice?.Currency,
            NumForSale = stats?.NumForSale,
        };
    }

    /// <summary>
    /// Picks the most collected vinyl release whose title matches the album (and artist when it
    /// matches). Discogs search is fuzzy, so loose matches are rejected to avoid false positives.
    /// </summary>
    public static DiscogsSearchResult? PickBestMatch(IEnumerable<DiscogsSearchResult> results, string artist,
        string albumTitle)
    {
        var wantTitle = TextNormalizer.Normalize(albumTitle);
        var wantArtist = TextNormalizer.NormalizeArtist(artist);

        var matches = results
            .Select(r => (Result: r, Parts: SplitTitle(r.Title)))
            .Where(x => TextNormalizer.Normalize(x.Parts.Title) == wantTitle)
            .ToList();

        var artistMatches = matches
            .Where(x => TextNormalizer.NormalizeArtist(TextNormalizer.CleanDiscogsArtist(x.Parts.Artist)) == wantArtist)
            .ToList();
        if (artistMatches.Count > 0) matches = artistMatches;

        return matches
            .OrderByDescending(x => x.Result.MasterId is > 0)
            .ThenByDescending(x => x.Result.Community?.Have ?? 0)
            .Select(x => x.Result)
            .FirstOrDefault();
    }

    private static (string Artist, string Title) SplitTitle(string discogsTitle)
    {
        var i = discogsTitle.IndexOf(" - ", StringComparison.Ordinal);
        return i < 0 ? ("", discogsTitle) : (discogsTitle[..i], discogsTitle[(i + 3)..]);
    }
}
