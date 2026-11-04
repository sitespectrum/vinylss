using System.Security.Claims;
using System.Text.Json;
using Vinylss.Api.Auth;
using Vinylss.Api.Data;
using Vinylss.Api.Recommendations;

namespace Vinylss.Api.Endpoints;

public static class RecommendationEndpoints
{
    public sealed record SnapshotResponse(
        SnapshotStatus Status,
        DateTime? StartedAt,
        DateTime? GeneratedAt,
        string? Error,
        RecommendationResult? Result);

    public static void MapRecommendationEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/recommendations").RequireAuthorization();

        g.MapGet("", async (ClaimsPrincipal principal, AppDbContext db, RecommendationService service,
            CancellationToken ct) =>
        {
            var userId = principal.UserId();
            if (await db.Users.FindAsync([userId], ct) is not { } user) return Results.Unauthorized();

            var snapshot = await db.RecommendationSnapshots.FindAsync([userId], ct);
            if (snapshot is null)
                return Json(new SnapshotResponse(SnapshotStatus.Idle, null, null, null, null));

            var result = snapshot.ResultJson is null
                ? null
                : JsonSerializer.Deserialize<RecommendationResult>(snapshot.ResultJson, RecommendationService.ResultJson);

            // Hide anything marked since the snapshot was generated, without waiting for a refresh.
            if (result is not null)
            {
                var exclusions = await service.LoadExclusionsAsync(userId, UserSettings.FromJson(user.SettingsJson), ct);
                foreach (var section in result.Sections)
                    section.Items = section.Items.Where(i => !exclusions.Excludes(i)).ToList();
            }

            return Json(new SnapshotResponse(snapshot.Status, snapshot.StartedAt, snapshot.GeneratedAt,
                snapshot.Error, result));
        });

        g.MapPost("/refresh", async (ClaimsPrincipal principal, AppDbContext db, RecommendationQueue queue,
            CancellationToken ct) =>
        {
            var userId = principal.UserId();
            if (await db.Users.FindAsync([userId], ct) is null) return Results.Unauthorized();

            var snapshot = await db.RecommendationSnapshots.FindAsync([userId], ct);
            if (snapshot is null)
            {
                snapshot = new RecommendationSnapshot { UserId = userId };
                db.RecommendationSnapshots.Add(snapshot);
            }

            if (snapshot.Status is not (SnapshotStatus.Queued or SnapshotStatus.Running))
            {
                snapshot.Status = SnapshotStatus.Queued;
                snapshot.StartedAt = DateTime.UtcNow;
                snapshot.Error = null;
                await db.SaveChangesAsync(ct);
                queue.Enqueue(userId);
            }

            return Results.Json(new SnapshotResponse(snapshot.Status, snapshot.StartedAt, snapshot.GeneratedAt,
                null, null), RecommendationService.ResultJson, statusCode: StatusCodes.Status202Accepted);
        });
    }

    private static IResult Json(SnapshotResponse response) =>
        Results.Json(response, RecommendationService.ResultJson);
}
