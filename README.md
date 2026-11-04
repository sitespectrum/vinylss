# Vinylss

Vinyl recommendations based on your Spotify listening. Log in with Spotify and Vinylss finds:

- **Albums you already love**: records that contain many of the tracks you play. Plays of
  singles, remasters and deluxe editions all count toward the standard album.
- **More from your favourite artists** (deep cuts): albums by your top artists that you have
  barely listened to.

Discogs is used to check that a vinyl pressing exists, and to show its price and a buy link. You
can choose vinyl-only, prefer-vinyl or any-album mode. Albums you mark as **owned** or **not
interested** are hidden from recommendations. You can also sync your **Discogs collection** to
hide records you already own. Every recommendation type, listening source and filter can be
switched on or off in Settings.

```
backend/   ASP.NET Core 10 API (Spotify OAuth, recommendation engine, Discogs, SQLite)
app/       Flutter client (Android + Linux desktop; web later)
```

## 1. Prerequisites

1. **Spotify app**: create one at <https://developer.spotify.com/dashboard>.
   - Redirect URI: `http://127.0.0.1:5080/auth/callback`. Spotify requires a loopback IP here;
     `localhost` is not accepted.
   - APIs used: Web API.
   - While the app is in *development mode*, add your Spotify account under **User Management**.
     Accounts that are not on the list get a 403.
2. **Discogs token** (optional, but needed for vinyl lookups): <https://www.discogs.com/settings/developers>
   → *Generate new token*.

## 2. Backend

```sh
cd backend/src/Vinylss.Api
dotnet user-secrets set Spotify:ClientId     <client id>
dotnet user-secrets set Spotify:ClientSecret <client secret>
dotnet user-secrets set Discogs:Token        <discogs token>
dotnet user-secrets set Jwt:SigningKey       "$(openssl rand -base64 48)"
dotnet run                  # http://127.0.0.1:5080
```

- Data is stored in `vinylss.db` (SQLite). The schema is created on startup. If the schema
  changes, delete the file.
- If `Jwt:SigningKey` is not set, Development mode generates a random key at startup. App logins
  then stop working whenever the server restarts.
- Tests: `cd backend && dotnet test`

#### Docker

```sh
cd backend
cp .env.example .env        # fill in Spotify/Discogs credentials and JWT_SIGNING_KEY
docker compose up -d --build   # http://127.0.0.1:5080
```

The container runs in Production mode, so `JWT_SIGNING_KEY` is required. The SQLite database is
kept in the `vinylss-data` volume. Run `docker compose down -v` to wipe it, for example after a
schema change.

**Cloudflare Tunnel** (optional, the `tunnel` profile): exposes the API on a public hostname
without opening ports.

1. In the Cloudflare dashboard (Zero Trust → Networks → Tunnels), create a tunnel of type
   *Cloudflared* and copy its token into `CLOUDFLARE_TUNNEL_TOKEN`.
2. Add a public hostname (e.g. `vinylss.example.com`) with service `http://api:8080`.
3. Set `SPOTIFY_REDIRECT_URI=https://vinylss.example.com/auth/callback` and add that URI to the
   Spotify app.
4. Build the app with `--dart-define=API_BASE_URL=https://vinylss.example.com`.

`COMPOSE_PROFILES=tunnel` in `.env` starts the tunnel with `docker compose up`. Remove it to run
locally only.

### How a refresh works

`POST /recommendations/refresh` queues a background job. The job does the following:

1. Pulls your top tracks and artists (all three time ranges), liked songs and recently played
   tracks.
2. Weights each track by where it appears.
3. Collects candidate albums: albums of the tracks you play, plus the catalogues of your top
   artists.
4. Collapses editions of the same album and matches tracklists by normalized title and artist.
5. Runs the enabled strategies.
6. Checks Discogs for vinyl pressings.

Discogs allows about 60 requests per minute, so the first run takes a minute or two. Spotify
and Discogs responses are cached in SQLite, so later runs are fast. The limits are under
`Recommendations` in `appsettings.json`.

### API

| Method | Path | |
|---|---|---|
| GET | `/auth/login?returnUrl=` | Starts Spotify login (`returnUrl` must be in `App:AllowedReturnUrls`) |
| POST | `/auth/token` | Exchanges the one-time `code` from the callback for a JWT |
| GET | `/me` | Current user |
| GET/PUT | `/settings` | Recommendation preferences |
| GET | `/recommendations` | Latest snapshot + status (`idle/queued/running/ready/failed`) |
| POST | `/recommendations/refresh` | Queues a new run |
| GET | `/marks` | Owned / not-interested albums |
| POST/DELETE | `/albums/{spotifyAlbumId}/mark` | Mark (`{kind, title, artist, primaryArtist, coverUrl}`) or unmark an album |
| GET | `/discogs` | Discogs link status |
| PUT | `/discogs/username` | Links a Discogs username (`null` unlinks) |
| POST | `/discogs/sync` | Imports the (public) Discogs collection |

## 3. App

```sh
cd app
flutter pub get
flutter run -d linux                     # desktop, talks to http://127.0.0.1:5080
flutter emulators --launch <emulator>    # Android emulator, with a visible window
flutter run -d emulator-5554             # uses http://10.0.2.2:5080 automatically
```

Override the backend with `--dart-define=API_BASE_URL=https://...`.

Login callbacks:

- **Android**: `vinylss://callback`, a deep link handled with `app_links`.
- **Desktop**: `http://127.0.0.1:43823/callback`. The app listens on that loopback port during login.

Both must be in the backend's `App:AllowedReturnUrls`.

Tests: `flutter analyze && flutter test`

Screenshots of every screen (phone + desktop, sample data) for design review:
`flutter test tool/screenshots_test.dart`, written to `app/build/screenshots/`.
