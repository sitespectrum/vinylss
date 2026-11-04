namespace Vinylss.Api.Discogs;

// Minimal shapes of Discogs API objects (snake_case on the wire).

public sealed class DiscogsSearchResponse
{
    public List<DiscogsSearchResult> Results { get; init; } = [];
}

public sealed class DiscogsSearchResult
{
    public long Id { get; init; }
    public long? MasterId { get; init; }

    /// <summary>"Artist - Title".</summary>
    public string Title { get; init; } = "";

    public string? Year { get; init; }
    public string? CoverImage { get; init; }
    public string? Uri { get; init; }
    public List<string> Format { get; init; } = [];
    public DiscogsCommunity? Community { get; init; }
}

public sealed class DiscogsCommunity
{
    public int Have { get; init; }
    public int Want { get; init; }
}

public sealed class DiscogsMarketplaceStats
{
    public DiscogsPrice? LowestPrice { get; init; }
    public int? NumForSale { get; init; }
}

public sealed class DiscogsPrice
{
    public decimal Value { get; init; }
    public string Currency { get; init; } = "";
}

public sealed class DiscogsCollectionPage
{
    public DiscogsPagination Pagination { get; init; } = new();
    public List<DiscogsCollectionRelease> Releases { get; init; } = [];
}

public sealed class DiscogsPagination
{
    public int Page { get; init; }
    public int Pages { get; init; }
    public int Items { get; init; }
}

public sealed class DiscogsCollectionRelease
{
    public long Id { get; init; }
    public DiscogsBasicInformation BasicInformation { get; init; } = new();
}

public sealed class DiscogsBasicInformation
{
    public long Id { get; init; }
    public long? MasterId { get; init; }
    public string Title { get; init; } = "";
    public List<DiscogsArtistRef> Artists { get; init; } = [];
}

public sealed class DiscogsArtistRef
{
    public string Name { get; init; } = "";
}

/// <summary>What we tell the client about vinyl availability for an album.</summary>
public sealed class VinylInfo
{
    public bool HasVinyl { get; init; }
    public long? ReleaseId { get; init; }
    public long? MasterId { get; init; }
    public string? Url { get; init; }
    public string? MarketplaceUrl { get; init; }
    public string? CoverUrl { get; init; }
    public string? Year { get; init; }
    public decimal? LowestPrice { get; init; }
    public string? Currency { get; init; }
    public int? NumForSale { get; init; }
}
