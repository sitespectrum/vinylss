using System.Text.Json;
using System.Text.Json.Serialization;

namespace Vinylss.Api.Recommendations;

public enum VinylMode
{
    /// <summary>Only show albums with a vinyl pressing on Discogs.</summary>
    OnlyVinyl,

    /// <summary>Show everything, but rank albums without a known vinyl pressing lower.</summary>
    PreferVinyl,

    /// <summary>Skip Discogs entirely and just recommend albums.</summary>
    Ignore,
}

/// <summary>Per-user recommendation preferences. Every strategy and filter can be toggled.</summary>
public sealed class UserSettings
{
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    // Strategies
    public bool MostListenedEnabled { get; set; } = true;
    public bool DeepCutsEnabled { get; set; } = true;

    // Strategy tuning
    public int MinMatchedTracks { get; set; } = 3;
    public double DeepCutsMaxCoverage { get; set; } = 0.2;
    public int TopArtistsToExplore { get; set; } = 15;

    // Listening sources
    public bool UseTopTracksLongTerm { get; set; } = true;
    public bool UseTopTracksMediumTerm { get; set; } = true;
    public bool UseTopTracksShortTerm { get; set; } = true;
    public bool UseSavedTracks { get; set; } = true;
    public bool UseRecentlyPlayed { get; set; } = true;

    // Album types
    public bool IncludeSinglesAndEps { get; set; }
    public bool IncludeCompilations { get; set; }

    // Vinyl / ownership
    public VinylMode VinylMode { get; set; } = VinylMode.PreferVinyl;
    public bool ExcludeDiscogsCollection { get; set; } = true;

    public int MaxResultsPerSection { get; set; } = 30;

    public UserSettings Sanitized()
    {
        MinMatchedTracks = Math.Clamp(MinMatchedTracks, 1, 30);
        DeepCutsMaxCoverage = Math.Clamp(DeepCutsMaxCoverage, 0, 1);
        TopArtistsToExplore = Math.Clamp(TopArtistsToExplore, 0, 50);
        MaxResultsPerSection = Math.Clamp(MaxResultsPerSection, 1, 100);
        if (!Enum.IsDefined(VinylMode)) VinylMode = VinylMode.PreferVinyl;
        return this;
    }

    public static UserSettings FromJson(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return new UserSettings();
        try
        {
            return (JsonSerializer.Deserialize<UserSettings>(json, Json) ?? new UserSettings()).Sanitized();
        }
        catch (JsonException)
        {
            return new UserSettings();
        }
    }

    public string ToJson() => JsonSerializer.Serialize(this, Json);
}
