# Smart Public Transport Tracker

BMIT2073 Mobile Application Development — Flutter starter project.

Live bus tracking + stop search + favourites, built on Malaysia's official
open transit data (`api.data.gov.my`).

## What's already built

```
lib/
  core/
    constants.dart      # API URLs, GTFS category, map defaults
    app_theme.dart       # Shared theme
  models/
    stop.dart             # GTFS static stop
    vehicle_position.dart # Live GTFS-realtime vehicle
    favourite_stop.dart  # User's saved stop
  services/
    gtfs_static_service.dart    # Downloads + parses GTFS ZIP (stops.txt)
    gtfs_realtime_service.dart  # Fetches + parses live protobuf feed
    database_service.dart       # SQLite: cached stops + favourites
    location_service.dart       # GPS via geolocator
  providers/
    transit_provider.dart      # Member A: stops + live vehicle state
    favourites_provider.dart   # Member B: favourites state
  screens/
    splash_screen.dart
    home_map_screen.dart    # Member A: live map (tap a stop dot for ETAs)
    search_screen.dart      # Member B: search + save
    favourites_screen.dart  # Member B: saved stops
    stop_detail_screen.dart # Live ETA list for one stop
    settings_screen.dart
  widgets/
    root_nav.dart          # Bottom navigation shell
    stop_list_tile.dart
main.dart
pubspec.yaml
```

This is a **working starting point**, not a finished app — the core
plumbing (fetch static data → cache in SQLite → poll live positions →
render on map → search/favourite) is done. You'll extend it with routes,
ETAs, trip planning logic, and UI polish.

## 1. Prerequisites

- **Flutter SDK** (stable channel) — [install guide](https://docs.flutter.dev/get-started/install)
- **Android Studio** or **Xcode** (for the emulator/simulator), plus VS Code
  or Android Studio as your editor
- Git, obviously — clone/pull this repo as normal

This repo already includes the generated `android/` and `ios/` platform
folders (with location permissions and the auth deep-link scheme already
configured), plus a `supabase/` folder holding server-side code. You do
**not** need to run `flutter create` — just clone and go.

```bash
flutter pub get
flutter run
```

That's it for day-to-day development. The Supabase URL and anon key are
already checked into `lib/core/constants.dart` — see below for why that's
safe.

## 2. Backend setup (Supabase) — read this before touching auth code

This project uses **Supabase** for the account system (sign up / login /
password reset) and to sync favourites. A few things to know:

- **`lib/core/constants.dart` already has the project's URL and "anon" key
  committed.** This is intentional and safe — the anon key is meant to be
  public (it's embedded in every Supabase app's compiled binary anyway).
  Access to actual data is controlled by Row Level Security policies on
  the database side, not by keeping this key secret. You don't need to
  request or configure anything to just run the app.

- **You do NOT need a Supabase login to build/run the app.** Only someone
  changing the database schema or the `reset-password-with-pin` Edge
  Function needs dashboard/CLI access.

- **If you need dashboard access** (to see the Users list, edit table
  data, or check logs), ask [project owner] to invite you as a
  collaborator via **Supabase dashboard → Project Settings → Team**. This
  gives you your own login — there's no need to share any password for
  this.

- **Never commit or paste into chat/README:** the Supabase database
  password, the **service role key**, or any SMTP/email provider
  password. If you genuinely need one of these (e.g. to run
  `supabase link` yourself), get it from [project owner] over a private
  channel (Facebook or any social media), not this file.

### Password reset — no email required

Password reset doesn't send an email. Instead, each user sets a 4-6 digit
**security PIN** at sign-up (hashed with SHA-256, never stored in plain
text). Forgot Password asks for email + PIN + new password, and a
Supabase Edge Function (`supabase/functions/reset-password-with-pin/`)
verifies the PIN and applies the change server-side — this is the only
place the service-role key is used, and it never touches the app itself.

If you need to redeploy that function after changing it, you'll need the
Supabase CLI installed first — see **Environment setup** below.

```bash
supabase login
supabase link --project-ref <ask project owner for this>
supabase functions deploy reset-password-with-pin
```

The `SUPABASE_SERVICE_ROLE_KEY` the function needs is injected
automatically by Supabase — you never set it manually.

### Environment setup: installing the Supabase CLI

Only needed if you're deploying/editing the Edge Function or running SQL
migrations from your terminal. Most teammates can skip this entirely.

**Do not use `npm install -g supabase`** — Supabase dropped support for
global npm installs, and depending on your Node version it fails with a
confusing `primordials is not defined` crash instead of a clean error.
Use one of these instead:

**Windows (via Scoop):**
```powershell
# 1. Install Scoop first, if you don't have it (run each line separately)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# 2. Install the Supabase CLI through Scoop
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

**macOS (via Homebrew):**
```bash
brew install supabase/tap/supabase
```

**Linux (via Homebrew, or a .deb/.rpm/.apk from GitHub Releases):**
```bash
brew install supabase/tap/supabase
# or download the package for your distro from:
# https://github.com/supabase/cli/releases
```

**Verify it worked (any OS):**
```bash
supabase --version
```

Full docs (all platforms, troubleshooting): https://supabase.com/docs/guides/local-development/cli/getting-started

Once installed, log in and link to this project as shown above. `supabase
login` opens your browser to authenticate — approve it there and come
back to the terminal.

## 3. Add required permissions

Already done in this repo's `android/app/src/main/AndroidManifest.xml`
and `ios/Runner/Info.plist` — nothing to add here. (Kept for reference:
INTERNET, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION on Android;
`NSLocationWhenInUseUsageDescription` on iOS.)

## 4. Run it

```bash
flutter run
```

On first launch the app will:
1. Download the GTFS-Static feed (stops) and cache it in SQLite
2. Start polling the GTFS-Realtime feed every 20 seconds for live bus
   positions
3. Ask for location permission to centre the map on you

## How ETA works right now

Tap any stop (from Search, Favourites, or the small dots on the map) to
see live buses approaching it, e.g. "Bus 780 — ~4 min".

**Important caveat to mention in your report:** data.gov.my currently only
publishes GTFS-Realtime *vehicle positions*, not an official trip-updates
(predicted arrival) feed — that's still on their roadmap. So `EtaService`
estimates arrival as `distance ÷ assumed average speed`, filtered to
vehicles on any route within 5km of the stop. It's a reasonable
approximation, not an official prediction — call this out explicitly in
your "weaknesses of the module" write-up (Appendix D), since being upfront
about a known limitation is exactly what that section is asking for.

## 5. Where to go next

- **More accurate ETA**: parse `trips.txt` and `stop_times.txt` (same
  pattern as `routes.txt` in `gtfs_static_service.dart`) to know exactly
  which stops a route serves and in what order, instead of pure
  distance-based filtering. This is the natural "for excellent marks"
  extension of what's here now — mention it as a possible future
  improvement even if you don't have time to build it.
- **Trip planning**: in `favourites_provider.dart` / a new
  `trip_planner_provider.dart`, match a "from stop" and "to stop" against
  shared routes.
- **Notifications**: add `flutter_local_notifications` to remind users
  before a saved commute.
- **Polish**: loading skeletons, empty states, error retry buttons —
  the rubric explicitly rewards handling failures gracefully rather than
  crashing.
- **Before final submission**: strip all code comments from the
  codebase (the assignment brief requires this) and make sure your
  GitHub commit history shows contributions from both members.

## Data source

Malaysia's Open API, GTFS feeds from Prasarana (LRT/MRT/bus operator):
- Docs: https://developer.data.gov.my/realtime-api/gtfs-realtime
- Static feed: `https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl`
- Realtime feed: `https://api.data.gov.my/gtfs-realtime/vehicle-position/prasarana?category=rapid-bus-kl`

Change `AppConstants.gtfsCategory` in `lib/core/constants.dart` to switch
network (e.g. `rapid-rail-kl` for LRT/MRT).