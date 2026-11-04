using Vinylss.Api.Discogs;

namespace Vinylss.Api.Recommendations;

/// <summary>Albums to leave out: marked albums and the user's Discogs collection.</summary>
public sealed class Exclusions
{
    public HashSet<string> SpotifyAlbumIds { get; init; } = [];
    public HashSet<string> AlbumKeys { get; init; } = [];
    public HashSet<long> DiscogsMasterIds { get; init; } = [];

    public bool Excludes(RecommendationItem item) =>
        SpotifyAlbumIds.Contains(item.SpotifyAlbumId)
        || AlbumKeys.Contains(item.AlbumKey)
        || item.Discogs?.MasterId is { } m && DiscogsMasterIds.Contains(m);
}

/// <summary>Runs strategies, de-duplicates, applies exclusions and the vinyl filter.</summary>
public static class RecommendationPipeline
{
    /// <summary>Multiplier applied in PreferVinyl mode to albums with no vinyl pressing found.</summary>
    public const double NoVinylPenalty = 0.5;

    public static async Task<(List<RecommendationSection> Sections, int DiscogsLookups)> BuildSectionsAsync(
        IReadOnlyList<AlbumAnalysis> analyses,
        UserSettings settings,
        IEnumerable<IRecommendationStrategy> strategies,
        Exclusions exclusions,
        IVinylLookup? vinyl,
        int discogsBudget,
        CancellationToken ct)
    {
        var mode = vinyl is { IsAvailable: true } ? settings.VinylMode : VinylMode.Ignore;
        var used = new HashSet<string>();
        var sections = new List<RecommendationSection>();
        var lookups = 0;

        foreach (var strategy in strategies.OrderBy(s => s.Priority).Where(s => s.IsEnabled(settings)))
        {
            var candidates = strategy.Select(analyses, settings)
                .Where(i => !exclusions.Excludes(i))
                .OrderByDescending(i => i.Score)
                .ToList();

            var kept = new List<RecommendationItem>();
            foreach (var item in candidates)
            {
                if (kept.Count >= settings.MaxResultsPerSection) break;
                if (used.Contains(item.AlbumKey)) continue;

                if (mode != VinylMode.Ignore && lookups < discogsBudget)
                {
                    lookups++;
                    item.Discogs = await vinyl!.LookupAsync(item.PrimaryArtist, item.Title, ct);
                    item.VinylStatus = item.Discogs.HasVinyl ? VinylStatus.Available : VinylStatus.NotFound;
                    if (exclusions.Excludes(item)) continue;
                }

                if (mode == VinylMode.OnlyVinyl && item.VinylStatus != VinylStatus.Available) continue;

                kept.Add(item);
                used.Add(item.AlbumKey);
            }

            if (mode == VinylMode.PreferVinyl)
                kept = kept
                    .OrderByDescending(i => i.Score * (i.VinylStatus == VinylStatus.NotFound ? NoVinylPenalty : 1))
                    .ToList();

            sections.Add(new RecommendationSection
            {
                Id = strategy.Id,
                Title = strategy.Title,
                Description = strategy.Description,
                Items = kept,
            });
        }

        return (sections, lookups);
    }
}
