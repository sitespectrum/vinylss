using Vinylss.Api.Discogs;
using Vinylss.Api.Recommendations;
using Vinylss.Api.Spotify;

namespace Vinylss.Api.Tests;

internal static class TestData
{
    public static SpotifyArtistRef Artist(string id, string? name = null) => new() { Id = id, Name = name ?? id };

    public static SpotifyAlbum Album(string id, string name, SpotifyArtistRef artist, string type = "album",
        params string[] trackNames) => new()
    {
        Id = id,
        Name = name,
        AlbumType = type,
        Artists = [artist],
        TotalTracks = trackNames.Length,
        ReleaseDate = "2000-01-01",
        Tracks = new SpotifyPaging<SpotifyTrack>
        {
            Items = trackNames.Select((t, i) => new SpotifyTrack { Id = $"{id}-t{i}", Name = t, Artists = [artist] })
                .ToList(),
        },
    };

    /// <summary>A track as returned by user endpoints (with an album reference, no album tracks).</summary>
    public static SpotifyTrack Track(string name, SpotifyArtistRef artist, SpotifyAlbum album) => new()
    {
        Id = $"{album.Id}:{name}",
        Name = name,
        Artists = [artist],
        Album = new SpotifyAlbum
        {
            Id = album.Id, Name = album.Name, AlbumType = album.AlbumType, Artists = album.Artists,
            TotalTracks = album.TotalTracks,
        },
    };

    public static SpotifyArtist TopArtist(SpotifyArtistRef a) => new() { Id = a.Id, Name = a.Name };
}

internal sealed class FakeCatalog : ISpotifyCatalog
{
    public Dictionary<string, SpotifyAlbum> Albums { get; } = [];
    public Dictionary<string, List<SpotifyAlbum>> ArtistAlbums { get; } = [];
    public List<string> FetchedAlbumIds { get; } = [];

    public FakeCatalog Add(SpotifyAlbum album, bool listUnderArtist = true)
    {
        Albums[album.Id] = album;
        if (listUnderArtist)
        {
            var artistId = album.Artists[0].Id;
            if (!ArtistAlbums.TryGetValue(artistId, out var list)) ArtistAlbums[artistId] = list = [];
            list.Add(album);
        }

        return this;
    }

    public Task<IReadOnlyList<SpotifyAlbum>> GetArtistAlbumsAsync(string artistId, CancellationToken ct) =>
        Task.FromResult<IReadOnlyList<SpotifyAlbum>>(ArtistAlbums.GetValueOrDefault(artistId) ?? []);

    public Task<SpotifyAlbum?> GetAlbumAsync(string albumId, CancellationToken ct)
    {
        lock (FetchedAlbumIds) FetchedAlbumIds.Add(albumId);
        return Task.FromResult(Albums.GetValueOrDefault(albumId));
    }
}

internal sealed class FakeVinylLookup(params string[] vinylTitles) : IVinylLookup
{
    public bool IsAvailable { get; init; } = true;
    public List<string> Lookups { get; } = [];
    public Dictionary<string, long> MasterIds { get; } = [];

    public Task<VinylInfo> LookupAsync(string artist, string albumTitle, CancellationToken ct)
    {
        Lookups.Add(albumTitle);
        var has = vinylTitles.Contains(albumTitle);
        return Task.FromResult(new VinylInfo
        {
            HasVinyl = has,
            MasterId = has && MasterIds.TryGetValue(albumTitle, out var m) ? m : null,
        });
    }
}
