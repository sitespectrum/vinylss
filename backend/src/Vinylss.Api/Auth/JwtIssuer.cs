using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using Vinylss.Api.Infrastructure;

namespace Vinylss.Api.Auth;

/// <summary>Issues the app's own bearer tokens (the Spotify tokens never leave the server).</summary>
public sealed class JwtIssuer(JwtOptions options)
{
    public SymmetricSecurityKey Key { get; } = new(Encoding.UTF8.GetBytes(options.SigningKey));

    public string Issuer => options.Issuer;

    public string Issue(Guid userId) =>
        new JsonWebTokenHandler().CreateToken(new SecurityTokenDescriptor
        {
            Issuer = options.Issuer,
            Audience = options.Issuer,
            Subject = new ClaimsIdentity([new Claim(JwtRegisteredClaimNames.Sub, userId.ToString())]),
            Expires = DateTime.UtcNow.AddDays(options.LifetimeDays),
            SigningCredentials = new SigningCredentials(Key, SecurityAlgorithms.HmacSha256),
        });

    public TokenValidationParameters ValidationParameters => new()
    {
        ValidIssuer = options.Issuer,
        ValidAudience = options.Issuer,
        IssuerSigningKey = Key,
        ValidateIssuerSigningKey = true,
    };
}

public static class ClaimsPrincipalExtensions
{
    public static Guid UserId(this ClaimsPrincipal principal) =>
        Guid.Parse(principal.FindFirstValue(JwtRegisteredClaimNames.Sub)
                   ?? throw new InvalidOperationException("Missing sub claim"));
}
