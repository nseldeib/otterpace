---
title: "hello@otterpace.com — Free Send + Receive"
mode: ui
createdAt: "2026-06-26T18:16:13Z"
source: manual
---

## Summary

Make `hello@otterpace.com` a fully usable, **free** support address — both
**receive** and **send** — without exposing the personal `nseldeib@gmail.com`
anywhere public. Receiving already works via Namecheap's free Email Forwarding
(MX `eforward1–5.registrar-servers.com` and the forwarding SPF are live on the
domain today). The missing half is **sending as** `hello@otterpace.com`: this plan
wires Gmail's "Send mail as" to a **free Brevo SMTP relay** (300 emails/day) so
replies leave as `hello@otterpace.com` instead of leaking the Gmail address. The
only repo change is documenting the setup in `docs/testflight-prep.md`; everything
else is one-time account/DNS config in Namecheap, Brevo, and Gmail. If Brevo's
domain authentication proves fiddly, the documented fallback is **forwarding-only
(option a)** — still free, still hides the published address, just sends replies
from Gmail.

## Key Decisions

- **Keep Namecheap forwarding for inbound** — the MX + forwarding SPF are already
  live; nothing to change for receiving. We layer sending on top rather than
  migrating mail elsewhere.
- **Brevo for the free SMTP relay** — 300 emails/day on the free tier with real
  SMTP credentials (`smtp-relay.brevo.com:587`), far more than a support address
  needs. Chosen over SendGrid (100/day free) and Mailgun (no real free tier). No
  new mail client — it plugs into Gmail's existing "Send mail as".
- **Merge SPF, never add a second `v=spf1` record** — a domain may have only one
  SPF TXT record. We edit the existing
  `v=spf1 include:spf.efwd.registrar-servers.com ~all` to also include Brevo, i.e.
  `v=spf1 include:spf.efwd.registrar-servers.com include:spf.brevo.com ~all`.
  Adding a second SPF record would break both senders.
- **Gmail confirmation closes the loop through forwarding** — when Gmail verifies
  the new "Send mail as" address, its confirmation email is sent to
  `hello@otterpace.com`, which forwards to the Gmail inbox. So inbound forwarding
  is a prerequisite, not a separate track.
- **Option (a) stays the fallback** — documented inline so that if domain auth or
  send-as is more trouble than it's worth at launch, dropping send-as leaves a
  working, free, address-hiding setup.

## Implementation

### 1. Document the email setup (repo change — 🤖 Claude)

**File**: `docs/testflight-prep.md`

Add an **"Email — hello@otterpace.com (free send + receive)"** subsection to the
DNS area (Section A, near the existing line-61 note that foreshadows it). It should
capture: the inbound forwarding that's already live, the Brevo send-as steps below,
the **merged** SPF value, and the option-(a) fallback. This is the single source of
truth so the setup is reproducible and the next person isn't re-deriving it.

### 2. Confirm inbound forwarding alias (👤 manual — Namecheap)

**No file change.** Namecheap → Domain List → Manage `otterpace.com` → **Mail
Settings = Email Forwarding** (already set; MX is live). In the **Email Forwarding**
table add the alias if not already present:
- **Alias:** `hello` → **Forwards to:** `nseldeib@gmail.com` → Save.

This is the entire "option (a)" setup and a prerequisite for step 5's verification
email.

### 3. Create a free Brevo account + SMTP key (👤 manual — Brevo)

**No file change.** Sign up at [brevo.com](https://www.brevo.com) (free plan). Go to
**SMTP & API → SMTP** and capture:
- **SMTP server:** `smtp-relay.brevo.com`, **port** `587` (STARTTLS).
- **Login** (the SMTP username Brevo shows) and a generated **SMTP key** (used as
  the password — not the account login password).

### 4. Authenticate the domain in Brevo (👤 manual — Brevo + Namecheap DNS)

**No file change.** In Brevo → **Senders, Domains & Dedicated IPs → Domains → Add
domain** `otterpace.com`. Brevo shows the exact records; add them in Namecheap
**Advanced DNS**:
- **Brevo verification** TXT (`brevo-code: …`) — confirms domain ownership.
- **DKIM** record (Brevo gives a `mail._domainkey` / `brevo._domainkey` TXT or
  CNAME) — signs outbound mail so Gmail/recipients trust it.
- **SPF — edit the existing record, do not add a new one.** Change
  `v=spf1 include:spf.efwd.registrar-servers.com ~all`
  → `v=spf1 include:spf.efwd.registrar-servers.com include:spf.brevo.com ~all`.
- *(Optional)* a basic **DMARC** TXT (`v=DMARC1; p=none; rua=mailto:hello@otterpace.com`)
  to monitor.

Wait for Brevo to show the domain/records as **verified** (minutes, up to a few
hours for DNS propagation).

### 5. Wire Gmail "Send mail as" (👤 manual — Gmail)

**No file change.** Gmail → **Settings → Accounts and Import → "Send mail as" → Add
another email address**:
- **Name:** Otterpace (or similar), **Email:** `hello@otterpace.com`,
  **uncheck** "Treat as an alias".
- **SMTP server:** `smtp-relay.brevo.com`, **Port** `587`, **Username:** Brevo SMTP
  login, **Password:** Brevo SMTP key, **TLS**.
- Gmail emails a confirmation code to `hello@otterpace.com` → it forwards to the
  Gmail inbox (thanks to step 2). Enter the code / click the link.
- Optionally set `hello@otterpace.com` as the default From, or just pick it from the
  From dropdown when replying to support.

### 6. Verify end-to-end (👤 manual)

**No file change.**
- **Receive:** from an outside account, email `hello@otterpace.com` → lands in
  `nseldeib@gmail.com` (mark "not spam" on the first one).
- **Send:** compose in Gmail with From = `hello@otterpace.com` to an outside account
  → arrives showing `hello@otterpace.com`, **not** the Gmail address.
- **Auth health:** send a test to [mail-tester.com](https://www.mail-tester.com) and
  confirm SPF + DKIM **pass** (aim for ~10/10) so support replies don't hit spam.

## Reused existing code / existing setup

- **Namecheap free Email Forwarding** — already live on `otterpace.com`
  (MX `eforward1–5.registrar-servers.com`, SPF `spf.efwd.registrar-servers.com`);
  reused as-is for inbound. No MX changes.
- **`docs/testflight-prep.md` Section A (DNS)** — the existing home for domain
  config and the line-61 email note this plan fulfills.
- **Existing SPF TXT record** — edited (merged), not duplicated.
- Web A record (`76.76.21.21` → Vercel) is untouched; mail (MX/TXT) and web (A) are
  independent record types.

## Scenarios to Demonstrate

This is account/DNS/email config with no app UI surface, so there are no codeyam UI
scenarios. The verifiable outcomes are:

- Inbound: external email to `hello@otterpace.com` arrives in `nseldeib@gmail.com`.
- Outbound: a Gmail message sent as `hello@otterpace.com` arrives at an external
  inbox with that From address (Gmail not exposed).
- Deliverability: mail-tester (or Gmail "show original") shows **SPF: pass** and
  **DKIM: pass** for `otterpace.com`.
- Fallback proven: with send-as removed, forwarding alone still receives and still
  hides the published address (option a).
