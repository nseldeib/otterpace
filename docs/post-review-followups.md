# Post-review follow-ups

Tracking the work left after the OSS / TestFlight code-quality pass (the pass
itself fixed all blockers + highs and most mediums). Two buckets: **deploy/config
actions** (require credentials or infra only you can provision) and **deferred
findings** (low-severity product decisions intentionally left open).

To turn any deferred item into a formal build, run `/codeyam-plan` and reference
the finding id below.

---

## A. Deploy / config actions (required to go fully live)

### A1. Account-sync backend (the BE-1 auth subsystem)
The new session-token auth is code-complete and tested, but the backend needs
provisioning before signed-in sync works against the deployed API:

- [ ] Create the `account_sessions` table in Supabase (SQL in `docs/account-sync.md`).
- [ ] Set the `APPLE_BUNDLE_ID` env var in Vercel (defaults to `com.otterpace.app`;
      set explicitly if the bundle id differs).
- [ ] Deploy the updated `api/`. Until then, signed-in sync degrades **gracefully**
      (the server 401s, the client silently keeps data local) — no crash, no data loss.

### A2. Strava (code-complete + hardened; gated off by config)
Strava is fully wired and now BE-2-hardened; the v1 "hidden" state is just the
empty `StravaClientID`. To enable it:

- [ ] Register a Strava API application to get a client id + secret.
- [ ] Set `StravaClientID` in `App/Info.plist` (public, safe to ship).
- [ ] Set `STRAVA_CLIENT_ID` and `STRAVA_CLIENT_SECRET` in Vercel.
- [ ] Confirm the Strava app's Authorization Callback Domain is `otterpace.com`.

Leaving these blank keeps the Strava card hidden — a valid v1 shipping state.

### A3. New TestFlight build
The build config is archive-ready (Release config, wired entitlements, automatic
signing, iPhone-only). To ship a build:

- [ ] Bump `CURRENT_PROJECT_VERSION` (build number) in the App target before each
      upload — now driven from build settings, not hardcoded in `Info.plist`.
- [ ] Archive (Release) and upload via the existing `docs/testflight-prep.md` runbook.

---

## B. Deferred findings (low-severity — your call)

### B1. CUT-3 — PostHog analytics ships disabled
`PostHogProjectKey` is empty, so analytics is a no-op. Decide: **(a)** keep the
no-op stub (zero data collection, honest default), or **(b)** remove the analytics
wiring entirely until it's configured. Recommendation: keep the stub — it's already
disclosed in the privacy policy and costs nothing.

### B2. SW-4 — Strava connect can land on a silent empty dashboard
`StravaService.fetchActivities()` returns `[]` on both "no activities" and "fetch
failed", so a failed import after a successful connect shows an empty state with no
error. Plan: have `fetchActivities()` distinguish the two (throw or return optional)
so `SettingsView` can surface `strava.lastError` / a retry.

### B3. BE-6 — prefs health-field denylist is top-level only
`prefsContainHealthFields` only inspects top-level keys, so a nested health field
could slip past the defense-in-depth guard. Plan: recurse the object (bounded depth)
or schema-validate the prefs payload. Low risk (the client never nests health into
prefs), defense-in-depth only.

### B4. BE-7 — coach content-type strictness
`coach.ts` enforces POST + size bounds but doesn't hard-require
`Content-Type: application/json`. CORS is intentionally left unset (the endpoint is
called from the app, not a browser, so the restrictive default is correct). Plan:
optionally reject non-JSON content types for stricter input validation.

### B5. TF-5 — unused `NSHealthUpdateUsageDescription` (intentionally kept)
The app never writes to HealthKit, so this usage string is technically unused. It
was **kept on purpose**: removing it would reverse a prior TestFlight fix and an
extra usage string is harmless on upload. Revisit only if Apple ever flags it.
