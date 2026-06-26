# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security vulnerabilities.

Instead, report them privately via GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
("Report a vulnerability" under the repository's **Security** tab), or email
**hello@codeyam.com**.

We'll acknowledge your report as quickly as we can and keep you updated on the fix.

## Scope & data handling

Otterpace is **privacy-forward by design**. The shipping app integrates with real
data sources, so here is exactly what handles your data:

- **Apple Health (HealthKit)** — read on-device only (steps, distance, active
  energy, workouts). HealthKit data is never sent to a server by the app itself;
  it only leaves the device if you explicitly enable the optional account sync
  below.
- **AI coach** — a bring-your-own-key proxy (`api/coach.ts`). Your Anthropic API
  key is sent per-request in a header and is **never stored, logged, or
  persisted** server-side. The day's `TodayState` is sent as coaching context.
- **Strava (optional)** — OAuth tokens are held **server-side only** (`api/strava/`);
  the app never sees them. Connecting Strava is opt-in.
- **Account sync (optional, Sign in with Apple)** — settings and, only behind a
  separate explicit opt-in, a health snapshot can sync to a backend
  (`api/account/`) so they survive reinstalls. Authenticated per request; off
  unless you sign in and enable it. Sign in with Apple is optional — the app is
  fully usable as a guest, with no account required.

### Known limitations

- **Rate limiting on the coach proxy is best-effort.** It is an in-memory,
  per-instance limiter (`api/_lib/ratelimit.ts`), so on a serverless host the
  effective limit scales with the number of warm instances — it throttles
  trivial floods but is not a hard global quota. A production deployment expecting
  abuse should front it with a shared store (e.g. Upstash/Redis).

Reports about data handling, permission scopes, the coach proxy, the Strava
backend, or the account-sync endpoints are all in scope and very welcome.
