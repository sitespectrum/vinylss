namespace Vinylss.Api.Recommendations;

/// <summary>A kind of recommendation. Each strategy becomes one section in the app and can be toggled.</summary>
public interface IRecommendationStrategy
{
    string Id { get; }
    string Title { get; }
    string Description { get; }

    /// <summary>Lower runs first; when an album qualifies for several strategies the first one keeps it.</summary>
    int Priority { get; }

    bool IsEnabled(UserSettings settings);
    IEnumerable<RecommendationItem> Select(IReadOnlyList<AlbumAnalysis> analyses, UserSettings settings);
}

/// <summary>Albums that contain many of the tracks the user already listens to.</summary>
public sealed class MostListenedAlbumsStrategy : IRecommendationStrategy
{
    public string Id => "mostListened";
    public string Title => "Albums you already love";
    public string Description => "Records packed with the songs you play the most.";
    public int Priority => 0;

    public bool IsEnabled(UserSettings s) => s.MostListenedEnabled;

    public IEnumerable<RecommendationItem> Select(IReadOnlyList<AlbumAnalysis> analyses, UserSettings s) =>
        analyses
            .Where(a => a.MatchedTracks.Count >= s.MinMatchedTracks)
            .Select(a => RecommendationItem.From(a, Id,
                score: a.MatchedWeight * (0.5 + a.Coverage),
                reason: $"You play {a.MatchedTracks.Count} of {a.TotalTracks} tracks"));
}

/// <summary>Albums by the user's favourite artists that they have barely listened to.</summary>
public sealed class DeepCutsStrategy : IRecommendationStrategy
{
    public string Id => "deepCuts";
    public string Title => "More from your favourite artists";
    public string Description => "Albums by artists you love that you haven't really explored yet.";
    public int Priority => 1;

    public bool IsEnabled(UserSettings s) => s.DeepCutsEnabled;

    public IEnumerable<RecommendationItem> Select(IReadOnlyList<AlbumAnalysis> analyses, UserSettings s) =>
        analyses
            .Where(a => a.ArtistRank < s.TopArtistsToExplore
                        && a.Album.AlbumType == "album"
                        && a.TotalTracks > 0
                        && a.Coverage <= s.DeepCutsMaxCoverage)
            .Select(a => RecommendationItem.From(a, Id,
                score: a.ArtistAffinity * (1 - a.Coverage),
                reason: a.MatchedTracks.Count == 0
                    ? $"You listen to {a.PrimaryArtistName} a lot, but haven't played this one"
                    : $"You listen to {a.PrimaryArtistName} a lot, but only {a.MatchedTracks.Count} of {a.TotalTracks} tracks here"));
}
