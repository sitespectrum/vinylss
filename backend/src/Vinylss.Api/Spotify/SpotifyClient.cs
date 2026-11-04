using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

namespace Vinylss.Api.Spotify;

public sealed class SpotifyApiException(HttpStatusCode status, string message) : Exception(message)
{
    public HttpStatusCode Status { get; } = status;
}

/// <summary>Thin client for the Spotify Web API. Every call takes the user's access token.</summary>
public sealed partial class SpotifyClient(HttpClient http, ILogger<SpotifyClient> log)
{
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };

    public Task<SpotifyUserProfile> GetMeAsync(string token, CancellationToken ct) =>
        GetAsync<SpotifyUserProfile>(token, "me", ct);

    public async Task<List<SpotifyTrack>> GetTopTracksAsync(string token, string timeRange, CancellationToken ct) =>
        (await GetAsync<SpotifyPaging<SpotifyTrack>>(token, $"me/top/tracks?time_range={timeRange}&limit=50", ct)).Items;

    public async Task<List<SpotifyArtist>> GetTopArtistsAsync(string token, string timeRange, CancellationToken ct) =>
        (await GetAsync<SpotifyPaging<SpotifyArtist>>(token, $"me/top/artists?time_range={timeRange}&limit=50", ct)).Items;

    public async Task<List<SpotifyTrack>> GetSavedTracksAsync(string token, int max, CancellationToken ct)
    {
        var saved = await GetPagesAsync<SpotifySavedTrack>(token, "me/tracks?limit=50", max, ct);
        return saved.Where(s => s.Track is not null).Select(s => s.Track!).ToList();
    }

    public async Task<List<SpotifyTrack>> GetRecentlyPlayedAsync(string token, CancellationToken ct)
    {
        var page = await GetAsync<SpotifyPaging<SpotifyPlayHistory>>(token, "me/player/recently-played?limit=50", ct);
        return page.Items.Where(p => p.Track is not null).Select(p => p.Track!).ToList();
    }

    public Task<List<SpotifyAlbum>> GetArtistAlbumsAsync(string token, string artistId, int max, CancellationToken ct) =>
        GetPagesAsync<SpotifyAlbum>(token,
            $"artists/{Uri.EscapeDataString(artistId)}/albums?include_groups=album,single,compilation&limit=50", max, ct);

    /// <summary>Gets an album including its full tracklist (following track pagination).</summary>
    public async Task<SpotifyAlbum?> GetAlbumAsync(string token, string albumId, CancellationToken ct)
    {
        SpotifyAlbum album;
        try
        {
            album = await GetAsync<SpotifyAlbum>(token, $"albums/{Uri.EscapeDataString(albumId)}", ct);
        }
        catch (SpotifyApiException ex) when (ex.Status is HttpStatusCode.NotFound or HttpStatusCode.BadRequest)
        {
            return null;
        }

        if (album.Tracks is { Next: not null } tracks)
        {
            var all = new List<SpotifyTrack>(tracks.Items);
            all.AddRange(await GetPagesAsync<SpotifyTrack>(token, tracks.Next, 500, ct));
            album.Tracks = new SpotifyPaging<SpotifyTrack> { Items = all, Total = all.Count };
        }

        return album;
    }

    private async Task<List<T>> GetPagesAsync<T>(string token, string url, int max, CancellationToken ct)
    {
        var items = new List<T>();
        string? next = url;
        while (next is not null && items.Count < max)
        {
            var page = await GetAsync<SpotifyPaging<T>>(token, next, ct);
            items.AddRange(page.Items);
            next = page.Next;
        }

        return items.Count > max ? items[..max] : items;
    }

    private async Task<T> GetAsync<T>(string token, string url, CancellationToken ct)
    {
        for (var attempt = 0; ; attempt++)
        {
            using var req = new HttpRequestMessage(HttpMethod.Get, url);
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            using var res = await http.SendAsync(req, ct);

            if (res.StatusCode == HttpStatusCode.TooManyRequests && attempt < 5)
            {
                var wait = res.Headers.RetryAfter?.Delta ?? TimeSpan.FromSeconds(2 << attempt);
                if (wait > TimeSpan.FromMinutes(2))
                    throw new SpotifyApiException(res.StatusCode, $"Spotify rate limit: retry after {wait}");
                log.LogInformation("Spotify rate limited, waiting {Wait}", wait);
                await Task.Delay(wait, ct);
                continue;
            }

            if ((int)res.StatusCode >= 500 && attempt < 2)
            {
                await Task.Delay(TimeSpan.FromSeconds(1 + attempt), ct);
                continue;
            }

            if (!res.IsSuccessStatusCode)
            {
                var body = await res.Content.ReadAsStringAsync(ct);

                // Spotify caps page size lower on some endpoints (e.g. artist albums) and answers
                // "Invalid limit" instead of clamping. Retry with the smallest commonly allowed size;
                // pagination via `next` keeps working with the smaller pages.
                if (res.StatusCode == HttpStatusCode.BadRequest
                    && body.Contains("Invalid limit", StringComparison.OrdinalIgnoreCase)
                    && WithSmallerLimit(url) is { } smaller)
                {
                    log.LogInformation("Spotify rejected page size for {Url}, retrying with limit={Limit}", url, FallbackLimit);
                    url = smaller;
                    continue;
                }

                throw new SpotifyApiException(res.StatusCode, $"Spotify GET {url} failed ({(int)res.StatusCode}): {body}");
            }

            return (await res.Content.ReadFromJsonAsync<T>(Json, ct))!;
        }
    }

    public const int FallbackLimit = 10;

    /// <summary>Rewrites a `limit=N` query parameter (N &gt; FallbackLimit) to FallbackLimit, or null if not applicable.</summary>
    public static string? WithSmallerLimit(string url)
    {
        var match = LimitParam().Match(url);
        if (!match.Success || int.Parse(match.Groups[2].Value) <= FallbackLimit) return null;
        return url[..match.Groups[2].Index] + FallbackLimit + url[(match.Groups[2].Index + match.Groups[2].Length)..];
    }

    [System.Text.RegularExpressions.GeneratedRegex(@"([?&]limit=)(\d+)")]
    private static partial System.Text.RegularExpressions.Regex LimitParam();
}
