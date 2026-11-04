using Vinylss.Api.Spotify;

namespace Vinylss.Api.Recommendations;

/// <summary>Turns raw listening history into weighted track and artist signals.</summary>
public static class ListeningProfileBuilder
{
    public static readonly IReadOnlyDictionary<string, double> RangeWeights = new Dictionary<string, double>
    {
        [SpotifyTimeRange.LongTerm] = 3.0,
        [SpotifyTimeRange.MediumTerm] = 2.0,
        [SpotifyTimeRange.ShortTerm] = 1.5,
    };

    public const double SavedWeight = 1.0;
    public const double RecentPlayWeight = 0.5;
    public const double RecentPlayCap = 2.0;

    /// <summary>Share of a track's weight that also counts toward its primary artist's affinity.</summary>
    public const double TrackToArtistFactor = 0.2;

    /// <summary>1.0 for rank 0, decaying linearly to 0.2 at rank 50.</summary>
    public static double RankFactor(int rank) => 1.0 - 0.8 * Math.Min(rank, 50) / 50.0;

    public static ListeningProfile Build(ListeningData data)
    {
        var p = new ListeningProfile();

        foreach (var (range, tracks) in data.TopTracks)
        {
            var w = RangeWeights.GetValueOrDefault(range, 1.0);
            for (var i = 0; i < tracks.Count; i++)
                AddTrack(p, tracks[i], w * RankFactor(i), $"top_{range}");
        }

        foreach (var t in data.SavedTracks)
            AddTrack(p, t, SavedWeight, "saved");

        var recentByKey = new Dictionary<string, double>();
        foreach (var t in data.RecentlyPlayed)
        {
            var key = KeyOf(t);
            if (key is null) continue;
            var already = recentByKey.GetValueOrDefault(key);
            var add = Math.Min(RecentPlayWeight, RecentPlayCap - already);
            if (add <= 0) continue;
            recentByKey[key] = already + add;
            AddTrack(p, t, add, "recent");
        }

        foreach (var (range, artists) in data.TopArtists)
        {
            var w = RangeWeights.GetValueOrDefault(range, 1.0);
            for (var i = 0; i < artists.Count; i++)
            {
                var a = artists[i];
                p.ArtistNames[a.Id] = a.Name;
                p.ArtistAffinity[a.Id] = p.ArtistAffinity.GetValueOrDefault(a.Id) + w * RankFactor(i);
            }
        }

        foreach (var s in p.Tracks.Values)
            p.ArtistAffinity[s.PrimaryArtistId] =
                p.ArtistAffinity.GetValueOrDefault(s.PrimaryArtistId) + s.Weight * TrackToArtistFactor;

        p.RankedArtistIds = p.ArtistAffinity.OrderByDescending(kv => kv.Value).Select(kv => kv.Key).ToList();
        return p;
    }

    private static string? KeyOf(SpotifyTrack t) =>
        t.Id is null || t.IsLocal || t.Artists.Count == 0 || string.IsNullOrEmpty(t.Artists[0].Id)
            ? null
            : $"{t.Artists[0].Id}|{TextNormalizer.Normalize(t.Name)}";

    private static void AddTrack(ListeningProfile p, SpotifyTrack t, double weight, string source)
    {
        var key = KeyOf(t);
        if (key is null) return;

        if (!p.Tracks.TryGetValue(key, out var signal))
        {
            signal = new TrackSignal
            {
                Key = key,
                Name = TextNormalizer.StripQualifiers(t.Name),
                NormalizedTitle = TextNormalizer.Normalize(t.Name),
                ArtistIds = t.Artists.Select(a => a.Id).Where(id => !string.IsNullOrEmpty(id)).ToHashSet(),
                PrimaryArtistId = t.Artists[0].Id,
            };
            p.Tracks[key] = signal;
        }

        signal.Weight += weight;
        signal.Sources.Add(source);
        foreach (var a in t.Artists)
            if (!string.IsNullOrEmpty(a.Id))
                p.ArtistNames.TryAdd(a.Id, a.Name);
        if (t.Album is { Id.Length: > 0 } album)
            signal.Albums.TryAdd(album.Id, album);
    }
}
