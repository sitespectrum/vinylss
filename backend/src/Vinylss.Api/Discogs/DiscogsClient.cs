using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.RateLimiting;
using Microsoft.Extensions.Options;
using Vinylss.Api.Infrastructure;

namespace Vinylss.Api.Discogs;

public sealed class DiscogsApiException(HttpStatusCode status, string message) : Exception(message)
{
    public HttpStatusCode Status { get; } = status;
}

/// <summary>Discogs API client. Authenticated requests are limited to 60/minute, shared process-wide.</summary>
public sealed class DiscogsClient(HttpClient http, IOptions<DiscogsOptions> options, ILogger<DiscogsClient> log)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };

    private static readonly SlidingWindowRateLimiter Limiter = new(new SlidingWindowRateLimiterOptions
    {
        PermitLimit = 55,
        Window = TimeSpan.FromMinutes(1),
        SegmentsPerWindow = 6,
        QueueLimit = 10_000,
        QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
    });

    public bool IsConfigured => !string.IsNullOrWhiteSpace(options.Value.Token);

    public Task<DiscogsSearchResponse?> SearchVinylReleasesAsync(string artist, string title, CancellationToken ct) =>
        GetAsync<DiscogsSearchResponse>(
            $"database/search?type=release&format=Vinyl&per_page=25&artist={Uri.EscapeDataString(artist)}&release_title={Uri.EscapeDataString(title)}",
            ct);

    public Task<DiscogsMarketplaceStats?> GetMarketplaceStatsAsync(long releaseId, CancellationToken ct) =>
        GetAsync<DiscogsMarketplaceStats>(
            $"marketplace/stats/{releaseId}?curr_abbr={Uri.EscapeDataString(options.Value.Currency)}", ct);

    public Task<DiscogsCollectionPage?> GetCollectionPageAsync(string username, int page, CancellationToken ct) =>
        GetAsync<DiscogsCollectionPage>(
            $"users/{Uri.EscapeDataString(username)}/collection/folders/0/releases?per_page=100&page={page}", ct);

    /// <summary>GET a Discogs resource; returns null on 404.</summary>
    private async Task<T?> GetAsync<T>(string url, CancellationToken ct) where T : class
    {
        for (var attempt = 0; ; attempt++)
        {
            using (var lease = await Limiter.AcquireAsync(1, ct))
            {
                if (!lease.IsAcquired) throw new DiscogsApiException(HttpStatusCode.TooManyRequests, "Discogs queue full");
            }

            using var req = new HttpRequestMessage(HttpMethod.Get, url);
            req.Headers.UserAgent.ParseAdd(options.Value.UserAgent);
            if (IsConfigured)
                req.Headers.Authorization = new AuthenticationHeaderValue("Discogs", $"token={options.Value.Token}");

            using var res = await http.SendAsync(req, ct);

            if (res.StatusCode == HttpStatusCode.TooManyRequests && attempt < 3)
            {
                log.LogInformation("Discogs rate limited, backing off");
                await Task.Delay(TimeSpan.FromSeconds(15 * (attempt + 1)), ct);
                continue;
            }

            if ((int)res.StatusCode >= 500 && attempt < 2)
            {
                await Task.Delay(TimeSpan.FromSeconds(2), ct);
                continue;
            }

            if (res.StatusCode == HttpStatusCode.NotFound) return null;

            if (!res.IsSuccessStatusCode)
            {
                var body = await res.Content.ReadAsStringAsync(ct);
                throw new DiscogsApiException(res.StatusCode, $"Discogs GET {url} failed ({(int)res.StatusCode}): {body}");
            }

            return await res.Content.ReadFromJsonAsync<T>(Json, ct);
        }
    }
}
