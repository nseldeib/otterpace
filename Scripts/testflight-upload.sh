#!/usr/bin/env bash
#
# One-command TestFlight upload: archive -> export -> upload.
#
# Prereqs (one-time):
#   1. An App Store Connect API key with **App Manager** access:
#        App Store Connect -> Users and Access -> Integrations -> App Store
#        Connect API -> Keys -> +  (role: App Manager) -> Download the .p8 ONCE.
#   2. Place the key where Apple's tools look for it (NEVER in the repo):
#        mkdir -p ~/.appstoreconnect/private_keys
#        mv ~/Downloads/AuthKey_<KEY_ID>.p8 ~/.appstoreconnect/private_keys/
#   3. Export the key's identifiers in your shell (or pass as args):
#        export ASC_KEY_ID=<KEY_ID>        # e.g. AB12CD34EF
#        export ASC_ISSUER_ID=<ISSUER_ID>  # the UUID atop the Keys page
#
# Then, after bumping the build number (CURRENT_PROJECT_VERSION in
# App.xcodeproj/project.pbxproj — App Store Connect rejects duplicate build
# numbers for the same marketing version):
#
#   Scripts/testflight-upload.sh
#
# Signing is automatic (cloud-managed Apple Distribution); no cert wrangling.
set -euo pipefail

KEY_ID="${ASC_KEY_ID:-${1:-}}"
ISSUER_ID="${ASC_ISSUER_ID:-${2:-}}"
SCHEME="App"
ARCHIVE="build/Otterpace.xcarchive"
EXPORT_DIR="build/export"
IPA="${EXPORT_DIR}/App.ipa"

if [[ -z "${KEY_ID}" || -z "${ISSUER_ID}" ]]; then
  echo "error: set ASC_KEY_ID and ASC_ISSUER_ID (env or args). See the header of this script." >&2
  exit 2
fi
if [[ ! -f "${HOME}/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8" ]]; then
  echo "error: ~/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8 not found." >&2
  echo "       Download the ASC API key once and place it there (see header)." >&2
  exit 2
fi

echo "==> Cleaning previous build artifacts"
rm -rf build/

echo "==> Archiving (Release, generic iOS device)"
xcodebuild -scheme "${SCHEME}" -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "${ARCHIVE}" \
  -allowProvisioningUpdates archive

echo "==> Exporting for App Store Connect"
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE}" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "${EXPORT_DIR}" \
  -allowProvisioningUpdates

echo "==> Validating ${IPA}"
xcrun altool --validate-app -f "${IPA}" -t ios \
  --apiKey "${KEY_ID}" --apiIssuer "${ISSUER_ID}"

echo "==> Uploading to TestFlight"
xcrun altool --upload-app -f "${IPA}" -t ios \
  --apiKey "${KEY_ID}" --apiIssuer "${ISSUER_ID}"

echo "==> Done. The build will appear in App Store Connect -> TestFlight as 'Processing' (5-30 min)."
