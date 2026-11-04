using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace Vinylss.Api.Recommendations;

/// <summary>
/// Normalizes track/album/artist names so different editions of the same thing compare equal,
/// e.g. "Come Together - Remastered 2009" == "Come Together" and
/// "Rumours (Super Deluxe Edition)" == "Rumours".
/// </summary>
public static partial class TextNormalizer
{
    private const string Qualifiers =
        @"remaster\w*|deluxe|edition|version|feat\.?|ft\.|featuring|with|live|mono|stereo|bonus|anniversary|" +
        @"expanded|mix|edit|explicit|clean|single|radio|acoustic|demo|reissue|unplugged|session|recorded|from";

    // "(Remastered 2011)", "[Live]", "(feat. Someone)", "(Super Deluxe Edition)"
    [GeneratedRegex(@"\s*[\(\[][^\)\]]*\b(?:" + Qualifiers + @")\b[^\)\]]*[\)\]]", RegexOptions.IgnoreCase)]
    private static partial Regex BracketQualifier();

    // " - Remastered 2009", " - Live at Wembley", " - Radio Edit"
    [GeneratedRegex(@"\s+[-–—]\s+(?=[^-–—]*\b(?:" + Qualifiers + @")\b)[^-–—]*$", RegexOptions.IgnoreCase)]
    private static partial Regex DashQualifier();

    [GeneratedRegex(@"[^\p{L}\p{N}\s]")]
    private static partial Regex Punctuation();

    [GeneratedRegex(@"\s+")]
    private static partial Regex Whitespace();

    // Discogs disambiguates artists like "Nirvana (2)" and marks name variations with "*".
    [GeneratedRegex(@"\s*\(\d+\)\s*$|\*+$")]
    private static partial Regex DiscogsArtistSuffix();

    /// <summary>Removes edition/version qualifiers but keeps original casing and punctuation.</summary>
    public static string StripQualifiers(string name)
    {
        var current = name.Trim();
        while (true)
        {
            var next = DashQualifier().Replace(BracketQualifier().Replace(current, ""), "").Trim();
            if (next == current || next.Length == 0) return next.Length == 0 ? current : next;
            current = next;
        }
    }

    public static bool HasQualifier(string name) => StripQualifiers(name) != name.Trim();

    /// <summary>Comparison key for a track or album title.</summary>
    public static string Normalize(string name)
    {
        var s = RemoveDiacritics(StripQualifiers(name)).ToLowerInvariant().Replace("&", " and ");
        s = Punctuation().Replace(s, "");
        return Whitespace().Replace(s, " ").Trim();
    }

    /// <summary>Comparison key for an artist name ("The Beatles" == "Beatles").</summary>
    public static string NormalizeArtist(string name)
    {
        var s = Normalize(name);
        return s.StartsWith("the ", StringComparison.Ordinal) ? s[4..] : s;
    }

    public static string CleanDiscogsArtist(string name) => DiscogsArtistSuffix().Replace(name, "").Trim();

    /// <summary>Edition-independent identity of an album: "artist|title".</summary>
    public static string AlbumKey(string artist, string title) => $"{NormalizeArtist(artist)}|{Normalize(title)}";

    private static string RemoveDiacritics(string s)
    {
        var decomposed = s.Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(decomposed.Length);
        foreach (var c in decomposed)
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
                sb.Append(c);
        return sb.ToString().Normalize(NormalizationForm.FormC);
    }
}
