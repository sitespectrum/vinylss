using Vinylss.Api.Recommendations;

namespace Vinylss.Api.Tests;

public class TextNormalizerTests
{
    [Theory]
    [InlineData("Come Together - Remastered 2009", "come together")]
    [InlineData("Here Comes The Sun - 2019 Mix", "here comes the sun")]
    [InlineData("Rumours (Super Deluxe Edition)", "rumours")]
    [InlineData("Song Title (feat. Someone Else)", "song title")]
    [InlineData("Hurt [Live]", "hurt")]
    [InlineData("Song - Radio Edit", "song")]
    [InlineData("Sgt. Pepper's Lonely Hearts Club Band (Remastered) [Deluxe Edition]", "sgt peppers lonely hearts club band")]
    [InlineData("Beyoncé", "beyonce")]
    [InlineData("Rock & Roll", "rock and roll")]
    [InlineData("  Many   Spaces  ", "many spaces")]
    public void Normalize_strips_edition_qualifiers(string input, string expected) =>
        Assert.Equal(expected, TextNormalizer.Normalize(input));

    [Theory]
    [InlineData("Hey Jude")]
    [InlineData("Love Will Tear Us Apart")]
    [InlineData("Anti-Hero")]
    [InlineData("Song (Interlude)")]
    public void Normalize_keeps_real_titles(string input) =>
        Assert.Equal(input.ToLowerInvariant().Replace("-", "").Replace("(", "").Replace(")", ""),
            TextNormalizer.Normalize(input));

    [Fact]
    public void Remix_is_not_treated_as_the_original() =>
        Assert.NotEqual(TextNormalizer.Normalize("Song"), TextNormalizer.Normalize("Song (Skrillex Remix)"));

    [Fact]
    public void NormalizeArtist_drops_leading_the() =>
        Assert.Equal(TextNormalizer.NormalizeArtist("Beatles"), TextNormalizer.NormalizeArtist("The Beatles"));

    [Theory]
    [InlineData("Nirvana (2)", "Nirvana")]
    [InlineData("Prince*", "Prince")]
    [InlineData("Radiohead", "Radiohead")]
    public void CleanDiscogsArtist_removes_disambiguation(string input, string expected) =>
        Assert.Equal(expected, TextNormalizer.CleanDiscogsArtist(input));

    [Fact]
    public void AlbumKey_matches_across_editions() =>
        Assert.Equal(TextNormalizer.AlbumKey("The Beatles", "Abbey Road"),
            TextNormalizer.AlbumKey("Beatles", "Abbey Road (Remastered)"));

    [Theory]
    [InlineData("Abbey Road (Remastered)", true)]
    [InlineData("Abbey Road", false)]
    public void HasQualifier(string input, bool expected) =>
        Assert.Equal(expected, TextNormalizer.HasQualifier(input));
}
