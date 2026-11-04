using Vinylss.Api.Spotify;

namespace Vinylss.Api.Tests;

public class SpotifyClientTests
{
    [Theory]
    [InlineData("artists/x/albums?include_groups=album&limit=50", "artists/x/albums?include_groups=album&limit=10")]
    [InlineData("me/tracks?limit=50&offset=100", "me/tracks?limit=10&offset=100")]
    [InlineData("https://api.spotify.com/v1/me/tracks?offset=0&limit=50", "https://api.spotify.com/v1/me/tracks?offset=0&limit=10")]
    public void WithSmallerLimit_rewrites_limit(string url, string expected) =>
        Assert.Equal(expected, SpotifyClient.WithSmallerLimit(url));

    [Theory]
    [InlineData("artists/x/albums?limit=10")]
    [InlineData("me")]
    public void WithSmallerLimit_returns_null_when_it_cannot_shrink(string url) =>
        Assert.Null(SpotifyClient.WithSmallerLimit(url));
}
