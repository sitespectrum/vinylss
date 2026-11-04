using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using Vinylss.Api.Auth;
using Vinylss.Api.Data;
using Vinylss.Api.Discogs;
using Vinylss.Api.Recommendations;

namespace Vinylss.Api.Endpoints;

/// <summary>Link a Discogs account and sync its collection so owned records are excluded.</summary>
public static class DiscogsEndpoints
{
    private const int MaxCollectionPages = 50;

    public sealed record DiscogsStatus(bool Configured, string? Username, DateTime? LastSync, int ItemCount);

    public sealed record UsernameRequest(string? Username);

    public static void MapDiscogsEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/discogs").RequireAuthorization();

        g.MapGet("", async (ClaimsPrincipal principal, AppDbContext db, DiscogsClient discogs, CancellationToken ct) =>
            await db.Users.FindAsync([principal.UserId()], ct) is { } u
                ? Results.Ok(await StatusAsync(u, db, discogs, ct))
                : Results.Unauthorized());

        g.MapPut("/username", async (UsernameRequest req, ClaimsPrincipal principal, AppDbContext db,
            DiscogsClient discogs, CancellationToken ct) =>
        {
            if (await db.Users.FindAsync([principal.UserId()], ct) is not { } u) return Results.Unauthorized();

            var username = string.IsNullOrWhiteSpace(req.Username) ? null : req.Username.Trim();
            if (username != u.DiscogsUsername)
            {
                await db.DiscogsCollectionItems.Where(i => i.UserId == u.Id).ExecuteDeleteAsync(ct);
                u.DiscogsUsername = username;
                u.LastDiscogsSync = null;
                await db.SaveChangesAsync(ct);
            }

            return Results.Ok(await StatusAsync(u, db, discogs, ct));
        });

        g.MapPost("/sync", async (ClaimsPrincipal principal, AppDbContext db, DiscogsClient discogs,
            CancellationToken ct) =>
        {
            if (await db.Users.FindAsync([principal.UserId()], ct) is not { } u) return Results.Unauthorized();
            if (u.DiscogsUsername is null) return Results.BadRequest(new { error = "Set a Discogs username first." });

            var items = new List<DiscogsCollectionItem>();
            try
            {
                for (var page = 1; page <= MaxCollectionPages; page++)
                {
                    var res = await discogs.GetCollectionPageAsync(u.DiscogsUsername, page, ct);
                    if (res is null)
                        return Results.NotFound(new { error = "Discogs user not found or collection is private." });

                    items.AddRange(res.Releases.Select(r => ToItem(u.Id, r)));
                    if (page >= res.Pagination.Pages) break;
                }
            }
            catch (DiscogsApiException ex) when (ex.Status == System.Net.HttpStatusCode.Forbidden)
            {
                return Results.BadRequest(new { error = "This Discogs collection is private." });
            }

            await db.DiscogsCollectionItems.Where(i => i.UserId == u.Id).ExecuteDeleteAsync(ct);
            db.DiscogsCollectionItems.AddRange(items);
            u.LastDiscogsSync = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);

            return Results.Ok(await StatusAsync(u, db, discogs, ct));
        });
    }

    private static DiscogsCollectionItem ToItem(Guid userId, DiscogsCollectionRelease r)
    {
        var info = r.BasicInformation;
        var artist = TextNormalizer.CleanDiscogsArtist(info.Artists.FirstOrDefault()?.Name ?? "");
        return new DiscogsCollectionItem
        {
            UserId = userId,
            ReleaseId = info.Id != 0 ? info.Id : r.Id,
            MasterId = info.MasterId is > 0 ? info.MasterId : null,
            Artist = artist,
            Title = info.Title,
            AlbumKey = TextNormalizer.AlbumKey(artist, info.Title),
        };
    }

    private static async Task<DiscogsStatus> StatusAsync(User u, AppDbContext db, DiscogsClient discogs,
        CancellationToken ct) =>
        new(discogs.IsConfigured, u.DiscogsUsername, u.LastDiscogsSync,
            await db.DiscogsCollectionItems.CountAsync(i => i.UserId == u.Id, ct));
}
