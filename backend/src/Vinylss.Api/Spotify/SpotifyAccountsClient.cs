using System.Net;
using System.Net.Http.Headers;
using System.Text;
using Microsoft.Extensions.Options;
using Vinylss.Api.Infrastructure;

namespace Vinylss.Api.Spotify;

/// <summary>Thrown when the stored Spotify refresh token no longer works; the user must log in again.</summary>
public sealed class SpotifyAuthExpiredException(string message) : Exception(message);

/// <summary>Spotify accounts service: authorization-code exchange and token refresh.</summary>
public sealed class SpotifyAccountsClient(HttpClient http, IOptions<SpotifyOptions> options)
{
    public const string AuthorizeUrl = "https://accounts.spotify.com/authorize";

    public Task<SpotifyTokenResponse> ExchangeCodeAsync(string code, CancellationToken ct) =>
        PostAsync(new Dictionary<string, string>
        {
            ["grant_type"] = "authorization_code",
            ["code"] = code,
            ["redirect_uri"] = options.Value.RedirectUri,
        }, ct);

    public Task<SpotifyTokenResponse> RefreshAsync(string refreshToken, CancellationToken ct) =>
        PostAsync(new Dictionary<string, string>
        {
            ["grant_type"] = "refresh_token",
            ["refresh_token"] = refreshToken,
        }, ct);

    private async Task<SpotifyTokenResponse> PostAsync(Dictionary<string, string> form, CancellationToken ct)
    {
        var o = options.Value;
        using var req = new HttpRequestMessage(HttpMethod.Post, "api/token")
        {
            Content = new FormUrlEncodedContent(form),
        };
        req.Headers.Authorization = new AuthenticationHeaderValue("Basic",
            Convert.ToBase64String(Encoding.UTF8.GetBytes($"{o.ClientId}:{o.ClientSecret}")));

        using var res = await http.SendAsync(req, ct);
        if (res.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.Unauthorized)
            throw new SpotifyAuthExpiredException(await res.Content.ReadAsStringAsync(ct));
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<SpotifyTokenResponse>(SpotifyClient.Json, ct))!;
    }
}
