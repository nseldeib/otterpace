# Strava import + PostHog analytics — setup & how it works

Two optional/cross-cutting integrations added in M5. The code is in place; the
steps below are the account/config work only you can do (API keys, a DB table,
Xcode/Vercel config). Both ride on the same Vercel deploy as the AI coach.

---

## Strava import

**How it works.** Strava OAuth needs the client secret to exchange/refresh tokens,
so that happens server-side. The app generates a random **anonymous device key**
(Keychain), runs the OAuth web flow, and the Vercel functions store the Strava
tokens in **Supabase** keyed by that device key — the tokens never touch the
device. The app then calls a backend proxy that returns mapped runs.

```
app ──authorize (ASWebAuthenticationSession)──▶ Strava
   ◀──redirect──  otterpace.com/api/strava/callback  ──▶ otterpace://strava-callback?code=…&state=<deviceKey>
app ──POST {code, deviceKey}──▶ /api/strava/exchange ──▶ Strava token  ──▶ Supabase (store)
app ──GET ?deviceKey=──────────▶ /api/strava/activities ─(read+refresh token)─▶ Strava ──▶ mapped runs
```

Files: `api/_lib/strava.ts`, `api/strava/{callback,exchange,activities,disconnect}.ts`,
`Sources/AppCore/Strava/StravaService.swift`, Settings → Strava card,
`OtterpaceModel.ingestStravaWorkouts`.

### Setup (you)
1. **Create a Strava API application** — https://www.strava.com/settings/api
   - Note the **Client ID** and **Client Secret**.
   - **Authorization Callback Domain**: `otterpace.com`
2. **Create the Supabase table** — in your Supabase project's SQL editor:
   ```sql
   create table strava_tokens (
     device_key text primary key,
     athlete_id bigint,
     access_token text not null,
     refresh_token text not null,
     expires_at bigint not null,
     updated_at timestamptz default now()
   );
   ```
   (Row Level Security can stay on — the backend uses the service-role key, which
   bypasses RLS. Don't expose the service-role key anywhere client-side.)
3. **Vercel env vars** (Project → Settings → Environment Variables):
   - `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`
   - `SUPABASE_URL` (e.g. `https://xxxx.supabase.co`)
   - `SUPABASE_SERVICE_ROLE_KEY` (Supabase → Project Settings → API → service_role)
4. **Xcode / app config** — in `App/Info.plist`, set `StravaClientID` to your
   Client ID. The `otterpace://` URL scheme is already registered there.
5. **Deploy** Vercel, then in the app: **Settings → Strava → Connect**.

### Verify
- `https://otterpace.com/api/strava/activities?deviceKey=test` returns
  `{"connected":false,"activities":[]}` once deployed (no token for that key yet).
- After connecting in-app, your recent runs appear in Activity History / Today.

---

## PostHog analytics (on by default)

**Product decision:** analytics is **on by default**. Events are anonymous (a
random per-install id, no PII, no health/activity data) and POSTed to PostHog's
HTTP capture endpoint — no SDK dependency. Disabled automatically when no key is
configured (so tests/scenarios never send events).

Files: `Sources/AppCore/Analytics/Analytics.swift`. Events captured so far:
`app_opened`, `strava_connected` (extend `Analytics.shared.capture(…)` as needed —
never pass health/activity data or PII in properties).

### Setup (you)
1. **PostHog project** — create one (PostHog Cloud US/EU or self-hosted). Copy the
   **Project API key** (a write-only client key — safe to ship in the app).
2. **`App/Info.plist`** — set `PostHogProjectKey` to that key. If your project is
   EU-hosted, set `PostHogHost` to `https://eu.i.posthog.com`.

### ⚠️ App Store privacy label — REQUIRED
Because analytics is on by default and Strava tokens are stored on our backend,
the App Store privacy "nutrition label" must now declare data collection. In App
Store Connect → App Privacy, declare at minimum:
- **Usage Data / Product Interaction** — collected, **not linked** to identity,
  used for **Analytics** / **App Functionality** (PostHog events).
- **Identifiers** — the anonymous device/analytics id (not linked to the user).
- If Strava is used: the **Strava activity data** you import + the stored tokens
  (App Functionality).

The published privacy policy (`site/privacy.html`) was updated to disclose all of
this — keep the two in sync. This reverses the earlier "no analytics / no
tracking" stance, which is no longer accurate.
