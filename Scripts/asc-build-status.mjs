#!/usr/bin/env node
// Report the processing state of Otterpace builds in App Store Connect.
//
// Usage:
//   ASC_KEY_ID=... ASC_ISSUER_ID=... node Scripts/asc-build-status.mjs [bundleId] [version]
//
// Auth: signs an ES256 JWT with the ASC API key at
// ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 (same key used for upload).
// Prints one line per matching build and exits 0 when a build is VALID, 2 while
// still PROCESSING / not yet ingested, 1 on FAILED/INVALID or error.

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";

const KEY_ID = process.env.ASC_KEY_ID;
const ISSUER_ID = process.env.ASC_ISSUER_ID;
const BUNDLE_ID = process.argv[2] || "com.otterpace.app";
const VERSION = process.argv[3] || null; // build number string, e.g. "2"

if (!KEY_ID || !ISSUER_ID) {
  console.error("set ASC_KEY_ID and ASC_ISSUER_ID");
  process.exit(1);
}

const keyPath = `${os.homedir()}/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8`;
const privateKey = crypto.createPrivateKey(fs.readFileSync(keyPath));

function b64url(buf) {
  return Buffer.from(buf).toString("base64url");
}
function jwt() {
  const header = b64url(JSON.stringify({ alg: "ES256", kid: KEY_ID, typ: "JWT" }));
  const now = Math.floor(Date.now() / 1000);
  const payload = b64url(
    JSON.stringify({ iss: ISSUER_ID, iat: now, exp: now + 600, aud: "appstoreconnect-v1" }),
  );
  const signer = crypto.createSign("SHA256");
  signer.update(`${header}.${payload}`);
  const sig = signer.sign({ key: privateKey, dsaEncoding: "ieee-p1363" });
  return `${header}.${payload}.${b64url(sig)}`;
}

async function api(path) {
  const res = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    headers: { Authorization: `Bearer ${jwt()}` },
  });
  if (!res.ok) {
    throw new Error(`ASC API ${res.status} on ${path}: ${(await res.text()).slice(0, 300)}`);
  }
  return res.json();
}

const apps = await api(`/v1/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}&fields[apps]=name`);
const app = apps.data?.[0];
if (!app) {
  console.error(`No app found for bundleId ${BUNDLE_ID} (is the App Store Connect app record created?)`);
  process.exit(1);
}

let path = `/v1/builds?filter[app]=${app.id}&fields[builds]=version,processingState,uploadedDate,expired&limit=10&sort=-uploadedDate`;
if (VERSION) path += `&filter[version]=${encodeURIComponent(VERSION)}`;
const builds = await api(path);

if (!builds.data?.length) {
  console.log(`${app.attributes.name}: no builds ingested yet${VERSION ? ` for build ${VERSION}` : ""} (still processing upload).`);
  process.exit(2);
}

let anyProcessing = false;
let anyValid = false;
for (const b of builds.data) {
  const a = b.attributes;
  console.log(
    `build ${a.version}: ${a.processingState}` +
      (a.uploadedDate ? `  (uploaded ${a.uploadedDate})` : "") +
      (a.expired ? "  [expired]" : ""),
  );
  if (a.processingState === "PROCESSING") anyProcessing = true;
  if (a.processingState === "VALID") anyValid = true;
}

if (anyProcessing) process.exit(2);
process.exit(anyValid ? 0 : 1);
