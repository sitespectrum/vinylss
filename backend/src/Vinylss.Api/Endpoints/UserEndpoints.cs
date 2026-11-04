using System.Security.Claims;
using Vinylss.Api.Auth;
using Vinylss.Api.Data;
using Vinylss.Api.Recommendations;

namespace Vinylss.Api.Endpoints;

public static class UserEndpoints
{
    public sealed record MeResponse(Guid Id, string DisplayName, string? AvatarUrl, string? DiscogsUsername);

    public static void MapUserEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("").RequireAuthorization();

        g.MapGet("/me", async (ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
            await db.Users.FindAsync([principal.UserId()], ct) is { } u
                ? Results.Ok(new MeResponse(u.Id, u.DisplayName, u.AvatarUrl, u.DiscogsUsername))
                : Results.Unauthorized());

        g.MapGet("/settings", async (ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
            await db.Users.FindAsync([principal.UserId()], ct) is { } u
                ? Results.Json(UserSettings.FromJson(u.SettingsJson), UserSettings.Json)
                : Results.Unauthorized());

        g.MapPut("/settings", async (HttpRequest req, ClaimsPrincipal principal, AppDbContext db,
            CancellationToken ct) =>
        {
            if (await db.Users.FindAsync([principal.UserId()], ct) is not { } u) return Results.Unauthorized();
            var settings = await req.ReadFromJsonAsync<UserSettings>(UserSettings.Json, ct);
            if (settings is null) return Results.BadRequest();
            u.SettingsJson = settings.Sanitized().ToJson();
            await db.SaveChangesAsync(ct);
            return Results.Json(settings, UserSettings.Json);
        });
    }
}
