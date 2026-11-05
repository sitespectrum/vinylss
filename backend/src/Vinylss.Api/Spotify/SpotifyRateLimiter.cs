namespace Vinylss.Api.Spotify;

/// <summary>
/// Process-wide gate for Spotify Web API calls (the limit is per app, not per user or request).
/// Spaces requests out so a recommendation run does not burst, and when Spotify answers 429 it
/// pauses every caller until Retry-After has passed. Hammering Spotify while it is returning 429
/// is what turns a short back-off into a ban of many hours.
/// </summary>
public sealed class SpotifyRateLimiter(TimeProvider time)
{
    /// <summary>Minimum gap between requests (~2 per second, well under Spotify's rolling 30 s window).</summary>
    public static readonly TimeSpan MinInterval = TimeSpan.FromMilliseconds(500);

    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly Lock _lock = new();
    private DateTimeOffset _nextSlot = DateTimeOffset.MinValue;
    private DateTimeOffset _blockedUntil = DateTimeOffset.MinValue;

    public DateTimeOffset BlockedUntil
    {
        get { lock (_lock) return _blockedUntil; }
    }

    /// <summary>Waits for this caller's turn. Throws without waiting if Spotify blocked us for longer than <paramref name="maxWait"/>.</summary>
    public async Task WaitAsync(TimeSpan maxWait, CancellationToken ct)
    {
        await _gate.WaitAsync(ct);
        try
        {
            var now = time.GetUtcNow();
            var blockedUntil = BlockedUntil;
            if (blockedUntil - now > maxWait)
                throw new SpotifyRateLimitedException(blockedUntil);

            var start = _nextSlot > blockedUntil ? _nextSlot : blockedUntil;
            if (start > now)
                await Task.Delay(start - now, time, ct);
            _nextSlot = time.GetUtcNow() + MinInterval;
        }
        finally
        {
            _gate.Release();
        }
    }

    /// <summary>Records a 429 so that all callers back off, not just the one that got it.</summary>
    public void Block(TimeSpan retryAfter)
    {
        var until = time.GetUtcNow() + retryAfter;
        lock (_lock)
            if (until > _blockedUntil)
                _blockedUntil = until;
    }
}

public sealed class SpotifyRateLimitedException(DateTimeOffset until)
    : Exception($"Spotify is rate limiting this app until {until:u}. Try again after that.")
{
    public DateTimeOffset Until { get; } = until;
}
