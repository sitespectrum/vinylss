using Vinylss.Api.Spotify;

namespace Vinylss.Api.Recommendations;

/// <summary>An album (one representative edition) compared against the user's listening profile.</summary>
public sealed class AlbumAnalysis
{
    public required SpotifyAlbum Album { get; init; }
    public required string AlbumKey { get; init; }
    public required string PrimaryArtistId { get; init; }
    public required string PrimaryArtistName { get; init; }
    public required List<TrackSignal> MatchedTracks { get; init; }
    public required int TotalTracks { get; init; }
    public double ArtistAffinity { get; init; }

    /// <summary>Position of the primary artist in the user's ranked artists (0 = favourite).</summary>
    public int ArtistRank { get; init; } = int.MaxValue;

    public double Coverage => TotalTracks == 0 ? 0 : (double)MatchedTracks.Count / TotalTracks;
    public double MatchedWeight => MatchedTracks.Sum(t => t.Weight);
}

/// <summary>
/// Gathers candidate albums (albums the user's tracks appear on plus the catalogues of their top
/// artists), collapses editions, fetches tracklists and matches them against the profile.
/// Tracks are matched by normalized title and artist, so plays of a single, remaster or deluxe
/// edition count toward the canonical album.
/// </summary>
public sealed class CandidateCollector
{
    public const int MaxAlbumsPerArtist = 25;
    private const int Concurrency = 4;

    public async Task<List<AlbumAnalysis>> CollectAsync(ListeningProfile profile, UserSettings settings,
        ISpotifyCatalog catalog, int maxAlbumLookups, CancellationToken ct)
    {
        var refs = new Dictionary<string, SpotifyAlbum>();
        var directWeight = new Dictionary<string, double>();

        foreach (var signal in profile.Tracks.Values)
        foreach (var album in signal.Albums.Values)
        {
            if (!IsAllowed(album, settings)) continue;
            refs.TryAdd(album.Id, album);
            directWeight[album.Id] = directWeight.GetValueOrDefault(album.Id) + signal.Weight;
        }

        foreach (var artistId in profile.RankedArtistIds.Take(settings.TopArtistsToExplore))
        {
            var albums = await catalog.GetArtistAlbumsAsync(artistId, ct);
            foreach (var album in albums.Where(a => IsAllowed(a, settings)).Take(MaxAlbumsPerArtist))
                refs.TryAdd(album.Id, album);
        }

        var artistRank = profile.RankedArtistIds.Select((id, i) => (id, i)).ToDictionary(x => x.id, x => x.i);

        var representatives = refs.Values
            .Where(a => a.Artists.Count > 0)
            .GroupBy(a => TextNormalizer.AlbumKey(a.Artists[0].Name, a.Name))
            .Select(g => (Key: g.Key, Album: PickEdition(g, directWeight),
                Direct: g.Sum(a => directWeight.GetValueOrDefault(a.Id))))
            .OrderByDescending(x => x.Direct)
            .ThenBy(x => artistRank.GetValueOrDefault(x.Album.Artists[0].Id, int.MaxValue))
            .Take(maxAlbumLookups)
            .ToList();

        using var gate = new SemaphoreSlim(Concurrency);
        var tasks = representatives.Select(async rep =>
        {
            await gate.WaitAsync(ct);
            try
            {
                var full = await catalog.GetAlbumAsync(rep.Album.Id, ct);
                return full is null || full.Artists.Count == 0 ? null : Analyze(full, rep.Key, profile, artistRank);
            }
            finally
            {
                gate.Release();
            }
        });

        return (await Task.WhenAll(tasks)).OfType<AlbumAnalysis>().ToList();
    }

    public static bool IsAllowed(SpotifyAlbum album, UserSettings s)
    {
        if (album.AlbumGroup == "appears_on") return false;
        return album.AlbumType switch
        {
            "album" => true,
            "single" => s.IncludeSinglesAndEps,
            "compilation" => s.IncludeCompilations,
            _ => false,
        };
    }

    /// <summary>Prefer the plain edition (no "Deluxe"/"Remastered" qualifier), then the one the user plays.</summary>
    public static SpotifyAlbum PickEdition(IEnumerable<SpotifyAlbum> editions, IReadOnlyDictionary<string, double> directWeight) =>
        editions
            .OrderBy(a => TextNormalizer.HasQualifier(a.Name))
            .ThenByDescending(a => directWeight.GetValueOrDefault(a.Id))
            .ThenBy(a => a.ReleaseDate ?? "9999")
            .First();

    public static AlbumAnalysis Analyze(SpotifyAlbum album, string albumKey, ListeningProfile profile,
        IReadOnlyDictionary<string, int> artistRank)
    {
        var tracks = album.Tracks?.Items ?? [];
        var matched = new List<TrackSignal>();
        var seen = new HashSet<string>();

        foreach (var t in tracks)
        {
            if (!profile.ByTitle.TryGetValue(TextNormalizer.Normalize(t.Name), out var candidates)) continue;
            var trackArtists = t.Artists.Select(a => a.Id).ToHashSet();
            foreach (var signal in candidates)
                if (signal.ArtistIds.Overlaps(trackArtists) && seen.Add(signal.Key))
                    matched.Add(signal);
        }

        var primary = album.Artists[0];
        return new AlbumAnalysis
        {
            Album = album,
            AlbumKey = albumKey,
            PrimaryArtistId = primary.Id,
            PrimaryArtistName = primary.Name,
            MatchedTracks = matched,
            TotalTracks = tracks.Count > 0 ? tracks.Count : album.TotalTracks,
            ArtistAffinity = profile.ArtistAffinity.GetValueOrDefault(primary.Id),
            ArtistRank = artistRank.GetValueOrDefault(primary.Id, int.MaxValue),
        };
    }
}
