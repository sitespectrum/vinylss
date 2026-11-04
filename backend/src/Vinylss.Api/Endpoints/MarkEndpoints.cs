using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using Vinylss.Api.Auth;
using Vinylss.Api.Data;
using Vinylss.Api.Recommendations;

namespace Vinylss.Api.Endpoints;

/// <summary>"I own it" / "Not interested" marks that hide albums from recommendations.</summary>
public static class MarkEndpoints
{
    public sealed record MarkRequest(MarkKind Kind, string Title, string Artist, string? PrimaryArtist, string? CoverUrl);

    public sealed record MarkResponse(
        string SpotifyAlbumId, string Title, string Artist, string? CoverUrl, MarkKind Kind, DateTime CreatedAt);

    public static void MapMarkEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("").RequireAuthorization();

        g.MapGet("/marks", async (ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var marks = await db.AlbumMarks.Where(m => m.UserId == userId)
                .OrderByDescending(m => m.CreatedAt)
                .Select(m => new MarkResponse(m.SpotifyAlbumId, m.Title, m.Artist, m.CoverUrl, m.Kind, m.CreatedAt))
                .ToListAsync(ct);
            return Results.Json(marks, UserSettings.Json);
        });

        g.MapPost("/albums/{spotifyAlbumId}/mark", async (string spotifyAlbumId, HttpRequest req,
            ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var body = await req.ReadFromJsonAsync<MarkRequest>(UserSettings.Json, ct);
            if (body is null || string.IsNullOrWhiteSpace(body.Title)) return Results.BadRequest();

            var userId = principal.UserId();
            var mark = await db.AlbumMarks.FirstOrDefaultAsync(
                           m => m.UserId == userId && m.SpotifyAlbumId == spotifyAlbumId, ct)
                       ?? db.AlbumMarks.Add(new AlbumMark
                       {
                           UserId = userId,
                           SpotifyAlbumId = spotifyAlbumId,
                           AlbumKey = "",
                       }).Entity;

            mark.Kind = body.Kind;
            mark.Title = body.Title;
            mark.Artist = body.Artist;
            mark.CoverUrl = body.CoverUrl;
            mark.AlbumKey = TextNormalizer.AlbumKey(body.PrimaryArtist ?? body.Artist, body.Title);
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });

        g.MapDelete("/albums/{spotifyAlbumId}/mark", async (string spotifyAlbumId, ClaimsPrincipal principal,
            AppDbContext db, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            await db.AlbumMarks.Where(m => m.UserId == userId && m.SpotifyAlbumId == spotifyAlbumId)
                .ExecuteDeleteAsync(ct);
            return Results.NoContent();
        });
    }
}
