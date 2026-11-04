using Vinylss.Api.Infrastructure;

namespace Vinylss.Api.Spotify;

/// <summary>Catalog lookups needed by the recommendation engine (abstracted for testing).</summary>
public interface ISpotifyCatalog
{
    Task<IReadOnlyList<SpotifyAlbum>> GetArtistAlbumsAsync(string artistId, CancellationToken ct);

    /// <summary>Album with its full tracklist, or null if it no longer exists.</summary>
    Task<SpotifyAlbum?> GetAlbumAsync(string albumId, CancellationToken ct);
}

/// <summary>Spotify-backed catalog bound to one user's access token, with persistent caching.</summary>
public sealed class CachedSpotifyCatalog(SpotifyClient spotify, DbCache cache, string accessToken) : ISpotifyCatalog
{
    private const int MaxArtistAlbums = 40;

    public async Task<IReadOnlyList<SpotifyAlbum>> GetArtistAlbumsAsync(string artistId, CancellationToken ct) =>
        await cache.GetOrCreateAsync($"sp:artist-albums:{artistId}", TimeSpan.FromDays(2),
            c => spotify.GetArtistAlbumsAsync(accessToken, artistId, MaxArtistAlbums, c), ct);

    public Task<SpotifyAlbum?> GetAlbumAsync(string albumId, CancellationToken ct) =>
        cache.GetOrCreateAsync($"sp:album:{albumId}", TimeSpan.FromDays(7),
            c => spotify.GetAlbumAsync(accessToken, albumId, c), ct);
}
