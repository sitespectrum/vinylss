using System.Text.Json;
using System.Threading.Channels;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Vinylss.Api.Data;
using Vinylss.Api.Discogs;
using Vinylss.Api.Infrastructure;
using Vinylss.Api.Spotify;

namespace Vinylss.Api.Recommendations;

/// <summary>Generates and stores a user's recommendations end to end.</summary>
public sealed class RecommendationService(
    AppDbContext db,
    SpotifyClient spotify,
    SpotifyTokenProvider tokens,
    DbCache cache,
    CandidateCollector collector,
    IVinylLookup vinyl,
    IEnumerable<IRecommendationStrategy> strategies,
    IOptions<RecommendationOptions> options,
    ILogger<RecommendationService> log)
{
    public const int MaxSavedTracks = 1000;

    public static readonly JsonSerializerOptions ResultJson = UserSettings.Json;

    public async Task RunAsync(Guid userId, CancellationToken ct)
    {
        var snapshot = await db.RecommendationSnapshots.FindAsync([userId], ct);
        if (snapshot is null) return;

        snapshot.Status = SnapshotStatus.Running;
        snapshot.StartedAt = DateTime.UtcNow;
        snapshot.Error = null;
        await db.SaveChangesAsync(ct);

        try
        {
            var result = await GenerateAsync(userId, ct);
            snapshot.ResultJson = JsonSerializer.Serialize(result, ResultJson);
            snapshot.GeneratedAt = result.GeneratedAt;
            snapshot.Status = SnapshotStatus.Ready;
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            log.LogError(ex, "Recommendation run failed for {UserId}", userId);
            snapshot.Status = SnapshotStatus.Failed;
            snapshot.Error = ex is SpotifyAuthExpiredException ? "spotify_auth_expired" : ex.Message;
        }

        await db.SaveChangesAsync(CancellationToken.None);
    }

    public async Task<RecommendationResult> GenerateAsync(Guid userId, CancellationToken ct)
    {
        var user = await db.Users.FirstAsync(u => u.Id == userId, ct);
        var settings = UserSettings.FromJson(user.SettingsJson);
        var token = await tokens.GetAccessTokenAsync(user, ct);
        var warnings = new List<string>();

        var data = await FetchListeningDataAsync(token, settings, ct);
        var profile = ListeningProfileBuilder.Build(data);
        if (profile.Tracks.Count == 0)
            warnings.Add("Not enough listening history yet. Try enabling more listening sources in settings.");

        var catalog = new CachedSpotifyCatalog(spotify, cache, token);
        var analyses = await collector.CollectAsync(profile, settings, catalog, options.Value.MaxAlbumLookups, ct);

        var exclusions = await LoadExclusionsAsync(userId, settings, ct);

        if (settings.VinylMode != VinylMode.Ignore && !vinyl.IsAvailable)
            warnings.Add("Discogs is not configured on the server, so vinyl availability was not checked.");

        var (sections, lookups) = await RecommendationPipeline.BuildSectionsAsync(
            analyses, settings, strategies, exclusions, vinyl, options.Value.MaxDiscogsLookups, ct);

        return new RecommendationResult
        {
            Sections = sections,
            Warnings = warnings,
            Stats = new RecommendationStats
            {
                TracksAnalyzed = profile.Tracks.Count,
                ArtistsAnalyzed = profile.ArtistAffinity.Count,
                AlbumsAnalyzed = analyses.Count,
                DiscogsLookups = lookups,
            },
        };
    }

    public async Task<Exclusions> LoadExclusionsAsync(Guid userId, UserSettings settings, CancellationToken ct)
    {
        var marks = await db.AlbumMarks.Where(m => m.UserId == userId)
            .Select(m => new { m.SpotifyAlbumId, m.AlbumKey }).ToListAsync(ct);
        var exclusions = new Exclusions
        {
            SpotifyAlbumIds = marks.Select(m => m.SpotifyAlbumId).ToHashSet(),
            AlbumKeys = marks.Select(m => m.AlbumKey).ToHashSet(),
        };

        if (settings.ExcludeDiscogsCollection)
        {
            var owned = await db.DiscogsCollectionItems.Where(i => i.UserId == userId)
                .Select(i => new { i.AlbumKey, i.MasterId }).ToListAsync(ct);
            exclusions.AlbumKeys.UnionWith(owned.Select(o => o.AlbumKey));
            exclusions.DiscogsMasterIds.UnionWith(owned.Where(o => o.MasterId is > 0).Select(o => o.MasterId!.Value));
        }

        return exclusions;
    }

    private async Task<ListeningData> FetchListeningDataAsync(string token, UserSettings s, CancellationToken ct)
    {
        var data = new ListeningData();
        var trackRanges = new Dictionary<string, bool>
        {
            [SpotifyTimeRange.LongTerm] = s.UseTopTracksLongTerm,
            [SpotifyTimeRange.MediumTerm] = s.UseTopTracksMediumTerm,
            [SpotifyTimeRange.ShortTerm] = s.UseTopTracksShortTerm,
        };

        foreach (var range in SpotifyTimeRange.All)
        {
            if (trackRanges[range])
                data.TopTracks[range] = await spotify.GetTopTracksAsync(token, range, ct);
            data.TopArtists[range] = await spotify.GetTopArtistsAsync(token, range, ct);
        }

        if (s.UseSavedTracks)
            data.SavedTracks = await spotify.GetSavedTracksAsync(token, MaxSavedTracks, ct);
        if (s.UseRecentlyPlayed)
            data.RecentlyPlayed = await spotify.GetRecentlyPlayedAsync(token, ct);

        return data;
    }
}

public sealed class RecommendationQueue
{
    private readonly Channel<Guid> _channel = Channel.CreateUnbounded<Guid>();

    public void Enqueue(Guid userId) => _channel.Writer.TryWrite(userId);

    public IAsyncEnumerable<Guid> ReadAllAsync(CancellationToken ct) => _channel.Reader.ReadAllAsync(ct);
}

/// <summary>Runs queued recommendation jobs one at a time (Discogs rate limits are global anyway).</summary>
public sealed class RecommendationWorker(
    RecommendationQueue queue,
    IServiceScopeFactory scopes,
    ILogger<RecommendationWorker> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await RecoverInterruptedRunsAsync(stoppingToken);

        await foreach (var userId in queue.ReadAllAsync(stoppingToken))
        {
            try
            {
                using var scope = scopes.CreateScope();
                await scope.ServiceProvider.GetRequiredService<RecommendationService>().RunAsync(userId, stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                log.LogError(ex, "Recommendation worker crashed for {UserId}", userId);
            }
        }
    }

    private async Task RecoverInterruptedRunsAsync(CancellationToken ct)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var stuck = await db.RecommendationSnapshots
            .Where(s => s.Status == SnapshotStatus.Queued || s.Status == SnapshotStatus.Running)
            .ToListAsync(ct);
        foreach (var s in stuck)
        {
            s.Status = SnapshotStatus.Failed;
            s.Error = "interrupted";
        }

        await db.SaveChangesAsync(ct);
    }
}
