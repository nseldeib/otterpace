# Otterpace — TestFlight & DNS walkthrough

The detailed Xcode / App Store Connect / DNS companion to the master sequence in
**[go-live-runbook.md](go-live-runbook.md)** (start there for the full order).
Everything here happens in Xcode, App Store Connect, Namecheap, and Vercel — it
can't be done from the codeyam CLI.

## Status at a glance

**Done in-repo ✅**
- Rebranded to **Otterpace** (mascot stays **Buddy**); bundle id `com.otterpace.app`.
- All features built: HealthKit, Sign in with Apple (+ account deletion),
  AI coach (BYO key), Strava import, movement reminders, analytics.
- App icon (1024² opaque, asset catalog wired) + branded launch screen.
- Version `1.0` / build `1`; `ITSAppUsesNonExemptEncryption = NO` set (skips the
  export-compliance prompt — Otterpace uses only standard HTTPS/TLS).
- `swift test` green (83/83); backend type-checks clean.

**Yours, outside the repo (this doc):** Apple Developer App ID + capabilities,
the App Store Connect app record, DNS, archive/upload, privacy label.

---

## A. DNS — point otterpace.com at Vercel (Namecheap)

Do this **after** the site is deployed on Vercel (runbook Phase 1). Add the domain
in Vercel first so it tells you the exact records, then enter them in Namecheap.

1. **Vercel** → `otterpace` project → **Settings → Domains** → add `otterpace.com`.
   Vercel shows the records to create — typically:
   - **A** `@ → 76.76.21.21`
   - **CNAME** `www → cname.vercel-dns.com`

   Use whatever Vercel displays; that page is authoritative.
2. **Namecheap** → **Domain List → Manage** otterpace.com → **Advanced DNS**:
   - **Delete the defaults** Namecheap auto-creates: `CNAME @ → parkingpage.namecheap.com`
     and any `URL Redirect Record` (they'll fight the new records).
   - **Add New Record** ×2:

     | Type         | Host | Value                  | TTL       |
     |--------------|------|------------------------|-----------|
     | A Record     | `@`  | `76.76.21.21`          | Automatic |
     | CNAME Record | `www`| `cname.vercel-dns.com` | Automatic |

   - Enter the CNAME value without a trailing dot (Namecheap adds it). **Save** each row.
3. **Vercel** re-checks automatically (minutes, up to ~24–48 h worst case). When it
   reads **Valid Configuration**, set `otterpace.com` as primary (so `www`
   redirects to it). **HTTPS is issued automatically** — no cert work.
4. **Verify:**
   ```
   dig otterpace.com +short        # → 76.76.21.21
   dig www.otterpace.com +short    # → cname.vercel-dns.com / Vercel IPs
   ```
   Then `https://otterpace.com`, `/privacy`, and `…/api/coach` (405 to GET) all
   respond, and Strava's callback domain (`otterpace.com`) resolves.

> Web DNS only. Adding `hello@otterpace.com` later is separate **MX** records and
> won't conflict with the above.

---

## B. Add the build as a new TestFlight app

### 1. Register the App ID (once)
[developer.apple.com](https://developer.apple.com) → Certificates, IDs & Profiles →
**Identifiers → +** → App IDs → App → Bundle ID `com.otterpace.app` (explicit) →
enable **HealthKit** and **Sign In with Apple** → Register. *(Xcode automatic
signing can also create this on first archive; doing it explicitly avoids
surprises.)*

### 2. Create the app record
[App Store Connect](https://appstoreconnect.apple.com) → **Apps → + → New App**:
- Platform **iOS**, Name **Otterpace** (must be unique on the App Store — keep a
  fallback like "Otterpace Run" ready), Primary Language, Bundle ID
  `com.otterpace.app`, SKU `otterpace-ios`, Full access. → Create.

### 3. Prep the build in Xcode (`App.xcodeproj`)
- **Signing & Capabilities**: enable **Automatically manage signing**, pick your
  **Team**, confirm bundle id `com.otterpace.app`.
- **+ Capability → HealthKit** and **+ Capability → Sign in with Apple**. Ensure
  `App/App.entitlements` is the target's *Code Signing Entitlements* (it carries
  both entitlements). `NSHealthShareUsageDescription` is already in Info.plist.
- Set the **app config values** in `App/Info.plist` for live integrations:
  `StravaClientID`, `PostHogProjectKey` (runbook Phases 3–4). The `otterpace://`
  URL scheme and `ITSAppUsesNonExemptEncryption = NO` are already there.
- Version `1.0` / Build `1` (bump **Build** for every later upload).

### 4. Archive & upload
- Destination **Any iOS Device (arm64)** — Archive is disabled for simulators.
- **Product → Archive** → Organizer → **Distribute App → App Store Connect →
  Upload** (keep defaults: automatic signing, upload symbols).
- **CLI alternative** (no Organizer clicking): export the archive with
  `ExportOptions.plist` and upload with an **App Store Connect API key** — see
  **[C. App Store Connect API key](#c-app-store-connect-api-key-cli-upload)** below.

### 5. After upload
- The build appears in App Store Connect → **TestFlight** as "Processing"
  (5–30 min; you get an email).
- Fill **Test Information** (beta description + feedback email). Export compliance
  is auto-answered by the `ITSAppUsesNonExemptEncryption` key.
- **Internal testing** (≤100 App Store Connect team users): add them to an internal
  group → they install via the **TestFlight** app and redeem — **no Beta App
  Review**, available immediately.
- **External testing** (public/email testers): needs a one-time **Beta App Review**
  + the **App Privacy** label completed first (runbook Phase 7;
  see `app-store-listing.md`).

### 6. Smoke-test the TestFlight build
On a real device, run the runbook **Phase 6** checklist end-to-end: HealthKit,
Sign in with Apple, AI coach, Strava, reminders, analytics.

---

## C. App Store Connect API key (CLI upload)

Lets you upload builds from the terminal instead of Xcode Organizer. Requires the
**App Store Connect API Access Request** to be **approved** for your team (one-time;
the Account Holder approves it under *Users and Access → Integrations*). Once
approved, the **App Store Connect API** section is unlocked.

### 1. Generate the key (one-time)
[App Store Connect](https://appstoreconnect.apple.com) → **Users and Access →
Integrations → App Store Connect API → Keys → +**:
- Name e.g. `otterpace-ci`; **Access: App Manager** (sufficient for TestFlight uploads).
- **Generate** → **Download API Key** — this `.p8` can be downloaded **only once**.
  Apple never lets you re-download it; if lost, revoke and make a new one.
- Capture three values you'll need every upload:
  - **Key ID** — shown next to the key (e.g. `AB12CD34EF`).
  - **Issuer ID** — at the top of the Keys page (a UUID, shared by all your keys).
  - the **`.p8`** file itself.

### 2. Store the key safely (never commit it)
Put the file where the Apple tools look by default:
```
mkdir -p ~/.appstoreconnect/private_keys
mv ~/Downloads/AuthKey_<KEY_ID>.p8 ~/.appstoreconnect/private_keys/
```
With it there, `altool`/`notarytool` find it from the Key ID alone — no path flag
needed. **Keep `.p8` out of the repo** (the `.gitignore` ignores `*.p8` and
`AuthKey_*.p8`). Treat the key like a password.

### 3. Export the archive, then upload
`ExportOptions.plist` is already set to `app-store-connect` / team `4D67UCFK3J`.
```
# Export the .ipa from the archive made in B.4
xcodebuild -exportArchive \
  -archivePath build/Otterpace.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export

# Validate (optional but catches errors before the long upload)
xcrun altool --validate-app -f build/export/Otterpace.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>

# Upload to TestFlight
xcrun altool --upload-app -f build/export/Otterpace.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```
`--apiKey` is the **Key ID** (not a path); `altool` resolves it to
`~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`.

### 4. Confirm
The build appears in App Store Connect → **TestFlight** as "Processing" (5–30 min),
then continue with **B.5** (Test Information, internal testers) and **B.6** (smoke test).
