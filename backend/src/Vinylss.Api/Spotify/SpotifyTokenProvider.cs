using Vinylss.Api.Data;

namespace Vinylss.Api.Spotify;

/// <summary>Returns a valid Spotify access token for a user, refreshing and persisting it when needed.</summary>
public sealed class SpotifyTokenProvider(SpotifyAccountsClient accounts, AppDbContext db)
{
    public async Task<string> GetAccessTokenAsync(User user, CancellationToken ct)
    {
        if (user.SpotifyTokenExpiresAt > DateTime.UtcNow.AddMinutes(1))
            return user.SpotifyAccessToken;

        var tokens = await accounts.RefreshAsync(user.SpotifyRefreshToken, ct);
        user.SpotifyAccessToken = tokens.AccessToken;
        if (!string.IsNullOrEmpty(tokens.RefreshToken))
            user.SpotifyRefreshToken = tokens.RefreshToken;
        user.SpotifyTokenExpiresAt = DateTime.UtcNow.AddSeconds(tokens.ExpiresIn);
        await db.SaveChangesAsync(ct);
        return user.SpotifyAccessToken;
    }
}
