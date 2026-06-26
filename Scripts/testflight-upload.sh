#!/usr/bin/env bash
#
# One-command TestFlight upload: bump build number -> archive -> export -> upload.
#
# Prereqs (one-time):
#   1. An App Store Connect API key with **App Manager** access:
#        App Store Connect -> Users and Access -> Integrations -> App Store
#        Connect API -> Team Keys -> +  (role: App Manager) -> Download the .p8 ONCE.
#   2. Place the key where Apple's tools look for it (NEVER in the repo):
#        mkdir -p ~/.appstoreconnect/private_keys
#        mv ~/Downloads/AuthKey_<KEY_ID>.p8 ~/.appstoreconnect/private_keys/
#   3. Export the key's identifiers in your shell (or pass as args):
#        export ASC_KEY_ID=<KEY_ID>        # e.g. LHDZUB2V8A
#        export ASC_ISSUER_ID=<ISSUER_ID>  # the UUID atop the Keys page
#
# Then just run:
#
#   Scripts/testflight-upload.sh                 # auto-bumps the build number
#   Scripts/testflight-upload.sh --no-bump       # use the current build number as-is
#
# The build number (CURRENT_PROJECT_VERSION) auto-increments by default, because
# App Store Connect rejects a duplicate build number for the same marketing
# version. The bump is left as an uncommitted working-tree change for you to
# commit. Signing is automatic (cloud-managed Apple Distribution); no certs to
# manage.
set -euo pipefail

# --- args: --no-bump flag, plus optional positional KEY_ID / ISSUER_ID ----------
BUMP=1
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --no-bump) BUMP=0 ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done

KEY_ID="${ASC_KEY_ID:-${POSITIONAL[0]:-}}"
ISSUER_ID="${ASC_ISSUER_ID:-${POSITIONAL[1]:-}}"
SCHEME="App"
PBXPROJ="App.xcodeproj/project.pbxproj"
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

# --- auto-bump the build number (CURRENT_PROJECT_VERSION) -----------------------
if [[ "${BUMP}" -eq 1 ]]; then
  CURRENT="$(grep -m1 -oE 'CURRENT_PROJECT_VERSION = [0-9]+;' "${PBXPROJ}" | grep -oE '[0-9]+')"
  if [[ -z "${CURRENT}" ]]; then
    echo "error: could not read CURRENT_PROJECT_VERSION from ${PBXPROJ}." >&2
    exit 1
  fi
  NEXT=$((CURRENT + 1))
  sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = ${NEXT};/g" "${PBXPROJ}"
  echo "==> Bumped build number ${CURRENT} -> ${NEXT} (commit this change when you're happy)"
else
  CURRENT="$(grep -m1 -oE 'CURRENT_PROJECT_VERSION = [0-9]+;' "${PBXPROJ}" | grep -oE '[0-9]+')"
  echo "==> Using current build number ${CURRENT} (--no-bump)"
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
