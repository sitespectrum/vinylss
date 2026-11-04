using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Vinylss.Api.Data;

namespace Vinylss.Api.Infrastructure;

/// <summary>
/// Persistent JSON cache backed by SQLite. Uses a fresh DbContext per call so it is safe to
/// use from concurrent tasks.
/// </summary>
public sealed class DbCache(IDbContextFactory<AppDbContext> dbFactory, ILogger<DbCache> log)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public async Task<T> GetOrCreateAsync<T>(string key, TimeSpan ttl, Func<CancellationToken, Task<T>> factory,
        CancellationToken ct)
    {
        await using (var db = await dbFactory.CreateDbContextAsync(ct))
        {
            var hit = await db.CacheEntries.AsNoTracking().FirstOrDefaultAsync(c => c.Key == key, ct);
            if (hit is not null && hit.ExpiresAt > DateTime.UtcNow)
                return JsonSerializer.Deserialize<T>(hit.Json, Json)!;
        }

        var value = await factory(ct);
        await SetAsync(key, value, ttl, ct);
        return value;
    }

    private async Task SetAsync<T>(string key, T value, TimeSpan ttl, CancellationToken ct)
    {
        try
        {
            await using var db = await dbFactory.CreateDbContextAsync(ct);
            var json = JsonSerializer.Serialize(value, Json);
            var entry = await db.CacheEntries.FirstOrDefaultAsync(c => c.Key == key, ct);
            if (entry is null)
                db.CacheEntries.Add(new CacheEntry { Key = key, Json = json, ExpiresAt = DateTime.UtcNow + ttl });
            else
            {
                entry.Json = json;
                entry.ExpiresAt = DateTime.UtcNow + ttl;
            }

            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException ex)
        {
            // Another task wrote the same key concurrently; the value is still usable.
            log.LogDebug(ex, "Cache write for {Key} lost a race", key);
        }
    }
}
