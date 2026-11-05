using System.Security.Cryptography;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using Vinylss.Api.Data;
using Vinylss.Api.Infrastructure;
using Vinylss.Api.Spotify;

namespace Vinylss.Api.Auth;

/// <summary>
/// Spotify Authorization Code flow run on the server:
/// app opens /auth/login → Spotify → /auth/callback → redirect to the app with a one-time code →
/// app POSTs /auth/token to swap it for a JWT.
/// </summary>
public static class AuthEndpoints
{
    private const string Scopes = "user-top-read user-read-recently-played user-library-read";
    private static readonly TimeSpan StateLifetime = TimeSpan.FromMinutes(10);
    private static readonly TimeSpan CodeLifetime = TimeSpan.FromMinutes(2);

    public sealed record TokenRequest(string Code);

    public sealed record TokenResponse(string Token);

    public static void MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/auth");

        g.MapGet("/login", (string returnUrl, IOptions<SpotifyOptions> spotify, IOptions<AppOptions> appOptions,
            IMemoryCache cache) =>
        {
            if (!appOptions.Value.AllowedReturnUrls.Contains(returnUrl))
                return Results.BadRequest(new { error = "returnUrl is not allowed" });

            var state = RandomToken();
            cache.Set($"auth-state:{state}", returnUrl, StateLifetime);

            return Results.Redirect(QueryHelpers.AddQueryString(SpotifyAccountsClient.AuthorizeUrl,
                new Dictionary<string, string?>
                {
                    ["client_id"] = spotify.Value.ClientId,
                    ["response_type"] = "code",
                    ["redirect_uri"] = spotify.Value.RedirectUri,
                    ["scope"] = Scopes,
                    ["state"] = state,
                }));
        });

        g.MapGet("/callback", async (string? code, string? state, string? error, IMemoryCache cache,
            SpotifyAccountsClient accounts, SpotifyClient spotifyClient, AppDbContext db, ILogger<Program> log,
            CancellationToken ct) =>
        {
            if (state is null || !cache.TryGetValue($"auth-state:{state}", out string? returnUrl) || returnUrl is null)
                return Results.BadRequest(new { error = "Login session expired, please try again." });
            cache.Remove($"auth-state:{state}");

            if (error is not null || code is null)
                return Results.Redirect(QueryHelpers.AddQueryString(returnUrl, "error", error ?? "missing_code"));

            User user;
            try
            {
                var tokens = await accounts.ExchangeCodeAsync(code, ct);
                var profile = await spotifyClient.GetMeAsync(tokens.AccessToken, ct);

                user = await db.Users.FirstOrDefaultAsync(u => u.SpotifyUserId == profile.Id, ct)
                       ?? db.Users.Add(new User { SpotifyUserId = profile.Id }).Entity;
                user.DisplayName = profile.DisplayName ?? profile.Id;
                user.AvatarUrl = profile.Images.FirstOrDefault()?.Url;
                user.SpotifyAccessToken = tokens.AccessToken;
                if (!string.IsNullOrEmpty(tokens.RefreshToken)) user.SpotifyRefreshToken = tokens.RefreshToken;
                user.SpotifyTokenExpiresAt = DateTime.UtcNow.AddSeconds(tokens.ExpiresIn);
                await db.SaveChangesAsync(ct);
            }
            catch (Exception ex) when (ex is SpotifyApiException or SpotifyAuthExpiredException or SpotifyRateLimitedException)
            {
                log.LogWarning(ex, "Spotify login failed");
                var reason = ex switch
                {
                    SpotifyApiException { Status: System.Net.HttpStatusCode.Forbidden } => "spotify_forbidden",
                    SpotifyRateLimitedException => "spotify_rate_limited",
                    _ => "spotify_login_failed",
                };
                return Results.Redirect(QueryHelpers.AddQueryString(returnUrl, "error", reason));
            }

            var oneTimeCode = RandomToken();
            cache.Set($"auth-code:{oneTimeCode}", user.Id, CodeLifetime);
            return Results.Redirect(QueryHelpers.AddQueryString(returnUrl, "code", oneTimeCode));
        });

        g.MapPost("/token", (TokenRequest req, IMemoryCache cache, JwtIssuer jwt) =>
        {
            var key = $"auth-code:{req.Code}";
            if (!cache.TryGetValue(key, out Guid userId)) return Results.Unauthorized();
            cache.Remove(key);
            return Results.Ok(new TokenResponse(jwt.Issue(userId)));
        });
    }

    private static string RandomToken() => WebEncoders.Base64UrlEncode(RandomNumberGenerator.GetBytes(32));
}
