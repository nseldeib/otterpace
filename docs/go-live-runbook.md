# Otterpace — Go-Live Runbook

The end-to-end, ordered checklist to take Otterpace from "code-complete" to "live
site + TestFlight build." Everything here is **account/config work** — the code is
already written and pushed. Deep-dives live in the per-area docs (linked inline);
this is the master sequence so nothing is done out of order.

**Critical path:** Vercel deploy → DNS → provider keys → app config → Xcode
capabilities → TestFlight → App Store privacy label. The single biggest unlock is
**Vercel**, because the AI coach, Strava, and the site all ride on it.

Legend: ☐ = you do it. Each phase ends with a **Verify** you can actually check.

---

## Phase 0 — Accounts you'll need
- ☐ **Apple Developer Program** membership (signing, capabilities, TestFlight).
- ☐ **Vercel** account (your personal one — not the Stripe-Projects `fun-site`).
- ☐ **Namecheap** — you own `otterpace.com` already.
- ☐ **Strava API app** (Phase 3) — for the optional Strava import.
- ☐ **Supabase** project (Phase 3) — stores Strava tokens.
- ☐ **PostHog** project (Phase 3) — analytics.
- Note: the **AI coach is bring-your-own-key** — *end users* paste their own
  Anthropic key in the app. You don't need an Anthropic key to ship.

---

## Phase 1 — Deploy the site + API to Vercel
Unblocks the coach, Strava, and the marketing/privacy site at once.
1. ☐ Vercel → **Add New… → Project** → import `nseldeib/otterpace`. Framework
   preset: **Other** (it auto-detects `vercel.json` → static `site/` + `api/`).
2. ☐ Deploy. Note the temporary `*.vercel.app` URL.

**Verify:** the `*.vercel.app` site loads the landing page, and
`…vercel.app/api/coach` returns **405** to a plain GET (POST-only — proves the
function deployed). Ref: `docs/site-and-dns.md`.

---

## Phase 2 — Point otterpace.com at Vercel
1. ☐ Vercel project → **Settings → Domains** → add `otterpace.com` (+ `www`).
2. ☐ In **Namecheap → Advanced DNS**, set the records Vercel shows (typically
   `A @ 76.76.21.21` and `CNAME www cname.vercel-dns.com.`). Remove Namecheap's
   default parking/redirect records on `@`/`www` first.
3. ☐ Wait for DNS (30 min–24 h); Vercel issues HTTPS automatically.

**Verify:** `https://otterpace.com` and `https://otterpace.com/privacy` load over
HTTPS. Ref: `docs/site-and-dns.md`.

---

## Phase 3 — Provider keys → Vercel env vars
All in Vercel → **Settings → Environment Variables** (then redeploy).

### 3a. AI coach (optional override)
- ☐ `COACH_MODEL` — only if you want to override the default `claude-opus-4-8`.
  No server key needed (BYO). Ref: `docs/ai-coach.md`.

### 3b. Strava
- ☐ Create a Strava app → https://www.strava.com/settings/api → copy **Client ID**
  + **Client Secret**; set **Authorization Callback Domain** = `otterpace.com`.
- ☐ In Supabase, run the `strava_tokens` table SQL from `docs/strava-and-analytics.md`.
- ☐ Vercel env: `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`, `SUPABASE_URL`,
  `SUPABASE_SERVICE_ROLE_KEY`.

**Verify:** `https://otterpace.com/api/strava/activities?deviceKey=test` returns
`{"connected":false,"activities":[]}`.

### 3c. PostHog (analytics is ON by default)
- ☐ Create a PostHog project → copy the **Project API key** (used in Phase 4).

---

## Phase 4 — App config (`App/Info.plist`)
1. ☐ `StravaClientID` → your Strava Client ID.
2. ☐ `PostHogProjectKey` → your PostHog project key (`PostHogHost` if EU).
3. Already set: bundle id `com.otterpace.app`, `otterpace://` URL scheme,
   HealthKit usage string, launch screen.

**Verify:** the keys read back at runtime — Settings → Strava shows **Connect
Strava** (not "Not set up"), and analytics events arrive after Phase 7.

---

## Phase 5 — Xcode capabilities & signing
Open `App.xcodeproj` → target → **Signing & Capabilities**.
1. ☐ Set your **Team**; confirm bundle id `com.otterpace.app`.
2. ☐ **+ Capability → HealthKit.**
3. ☐ **+ Capability → Sign in with Apple.** (Ensure `App/App.entitlements` is the
   target's Code Signing Entitlements — it contains both entitlements but may not
   be wired into the build settings yet.)
4. ☐ Register the App ID + bundle id in the Apple Developer portal if prompted.
- Account deletion (App Store guideline 5.1.1(v)) is already implemented:
  Settings → Account → Delete account.

**Verify:** the app builds & runs on a *physical device* (HealthKit + Sign in with
Apple don't fully work in the simulator).

---

## Phase 6 — On-device integration smoke test
On a real device, confirm each integration end-to-end:
- ☐ **HealthKit** — permission sheet appears; steps/distance populate the dashboard.
- ☐ **Sign in with Apple** — sign in, sign out, delete account all work.
- ☐ **AI coach** — Settings → AI Coach → paste your Anthropic key → ask a question
  → real reply (a bad key falls back to the built-in coach).
- ☐ **Strava** — Settings → Strava → Connect → approve → recent runs import.
- ☐ **Reminders** — toggle a reminder on → permission prompt → it schedules.
- ☐ **Analytics** — open the app → an `app_opened` event appears in PostHog.

---

## Phase 7 — App Store privacy label  ⚠️ REQUIRED
Analytics-on + server-stored Strava tokens mean you **must** declare data
collection in App Store Connect → **App Privacy**:
- ☐ **Usage Data → Product Interaction** — collected, *not linked* to identity,
  for **Analytics** / **App Functionality** (PostHog).
- ☐ **Identifiers** — the anonymous analytics/device id (not linked to the user).
- ☐ **Health & Fitness / Strava activity** (if Strava enabled) — App Functionality.
Keep this in sync with `site/privacy.html`. Ref: `docs/strava-and-analytics.md`.

---

## Phase 8 — TestFlight
1. ☐ App Store Connect → create the app record (bundle id `com.otterpace.app`).
2. ☐ Xcode → **Product → Archive** → **Distribute App → TestFlight**.
3. ☐ Complete export compliance + the privacy label (Phase 7) + test notes.
4. ☐ Add internal testers; install via TestFlight and re-run the Phase 6 smoke test
   on the TestFlight build.
Ref: `docs/testflight-prep.md`.

---

## Phase 9 — Nice-to-haves (post-launch)
- ☐ Email alias `hello@otterpace.com` (Namecheap/mail provider) — used in the
  privacy policy + Code of Conduct.
- ☐ Pin `@anthropic-ai/sdk` / `@vercel/node` to exact versions in `package.json`
  after the first green Vercel build (they're on `latest` to guarantee install).
- ☐ App Store listing copy, screenshots, keywords.

---

## One-glance dependency map
```
Apple Developer ─┬─▶ Phase 5 (capabilities/signing) ─▶ Phase 6 ─▶ Phase 8 (TestFlight)
                 └─▶ Phase 7 (privacy label) ──────────────────────▶ Phase 8
Vercel deploy ───┬─▶ Phase 2 (DNS) ─▶ site live
(Phase 1)        ├─▶ coach live      (needs nothing else server-side; BYO key)
                 ├─▶ Strava live     ◀─ Phase 3b (Strava app + Supabase)
                 └─▶ analytics       ◀─ Phase 3c + Phase 4 (PostHog key)
App config ──────▶ Phase 4 (Info.plist: StravaClientID, PostHogProjectKey)
```
