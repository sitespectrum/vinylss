using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Vinylss.Api.Auth;
using Vinylss.Api.Data;
using Vinylss.Api.Discogs;
using Vinylss.Api.Endpoints;
using Vinylss.Api.Infrastructure;
using Vinylss.Api.Recommendations;
using Vinylss.Api.Spotify;

var builder = WebApplication.CreateBuilder(args);
var config = builder.Configuration;

builder.Services.Configure<SpotifyOptions>(config.GetSection("Spotify"));
builder.Services.Configure<DiscogsOptions>(config.GetSection("Discogs"));
builder.Services.Configure<AppOptions>(config.GetSection("App"));
builder.Services.Configure<RecommendationOptions>(config.GetSection("Recommendations"));

var jwtOptions = config.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
if (jwtOptions.SigningKey.Length < 32)
{
    if (!builder.Environment.IsDevelopment())
        throw new InvalidOperationException("Jwt:SigningKey must be at least 32 characters.");
    // Dev convenience: tokens stop working when the server restarts.
    jwtOptions.SigningKey = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));
}

var jwt = new JwtIssuer(jwtOptions);
builder.Services.AddSingleton(jwt);

builder.Services.AddDbContextFactory<AppDbContext>(o =>
    o.UseSqlite(config.GetConnectionString("Default") ?? "Data Source=vinylss.db"));
builder.Services.AddScoped(sp => sp.GetRequiredService<IDbContextFactory<AppDbContext>>().CreateDbContext());
builder.Services.AddMemoryCache();

builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<SpotifyRateLimiter>();
builder.Services.AddHttpClient<SpotifyClient>(c => c.BaseAddress = new Uri("https://api.spotify.com/v1/"));
builder.Services.AddHttpClient<SpotifyAccountsClient>(c => c.BaseAddress = new Uri("https://accounts.spotify.com/"));
builder.Services.AddHttpClient<DiscogsClient>(c => c.BaseAddress = new Uri("https://api.discogs.com/"));

builder.Services.AddSingleton<DbCache>();
builder.Services.AddScoped<SpotifyTokenProvider>();
builder.Services.AddScoped<IVinylLookup, DiscogsVinylLookup>();
builder.Services.AddSingleton<CandidateCollector>();
builder.Services.AddSingleton<IRecommendationStrategy, MostListenedAlbumsStrategy>();
builder.Services.AddSingleton<IRecommendationStrategy, DeepCutsStrategy>();
builder.Services.AddScoped<RecommendationService>();
builder.Services.AddSingleton<RecommendationQueue>();
builder.Services.AddHostedService<RecommendationWorker>();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;
        o.TokenValidationParameters = jwt.ValidationParameters;
    });
builder.Services.AddAuthorization();
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
builder.Services.ConfigureHttpJsonOptions(o =>
    o.SerializerOptions.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase)));

var app = builder.Build();

if (string.IsNullOrEmpty(app.Services.GetRequiredService<Microsoft.Extensions.Options.IOptions<SpotifyOptions>>().Value.ClientId))
    app.Logger.LogWarning("Spotify:ClientId is not set. Login will not work until it is (see README).");

using (var scope = app.Services.CreateScope())
    scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.EnsureCreated();

// The Spotify refresh token was revoked or expired: tell the app to log in again.
app.Use(async (ctx, next) =>
{
    try
    {
        await next();
    }
    catch (SpotifyAuthExpiredException) when (!ctx.Response.HasStarted)
    {
        ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
        await ctx.Response.WriteAsJsonAsync(new { error = "spotify_auth_expired" });
    }
});

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));
app.MapAuthEndpoints();
app.MapUserEndpoints();
app.MapRecommendationEndpoints();
app.MapMarkEndpoints();
app.MapDiscogsEndpoints();

app.Run();

public partial class Program;
