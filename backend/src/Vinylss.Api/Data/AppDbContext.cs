using Microsoft.EntityFrameworkCore;

namespace Vinylss.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<AlbumMark> AlbumMarks => Set<AlbumMark>();
    public DbSet<DiscogsCollectionItem> DiscogsCollectionItems => Set<DiscogsCollectionItem>();
    public DbSet<CacheEntry> CacheEntries => Set<CacheEntry>();
    public DbSet<RecommendationSnapshot> RecommendationSnapshots => Set<RecommendationSnapshot>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<User>().HasIndex(u => u.SpotifyUserId).IsUnique();

        b.Entity<AlbumMark>(e =>
        {
            e.HasIndex(m => new { m.UserId, m.SpotifyAlbumId }).IsUnique();
            e.Property(m => m.Kind).HasConversion<string>();
        });

        b.Entity<DiscogsCollectionItem>().HasIndex(i => i.UserId);

        b.Entity<CacheEntry>().HasKey(c => c.Key);

        b.Entity<RecommendationSnapshot>(e =>
        {
            e.HasKey(s => s.UserId);
            e.Property(s => s.Status).HasConversion<string>();
        });
    }
}
