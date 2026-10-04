#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash tools/switch-psx.sh eximia
  bash tools/switch-psx.sh bamblue

This helper switches the active PolyScope X development URCap in the simulator.
Exímia PSX and BamBlue PSX are intentionally mutually exclusive.

Use this command only when switching from one product to the other.
If the requested product is already the active one, run npm run install-fast
inside that product repository instead.
EOF
}

target="${1:-}"
case "$target" in
  eximia|bamblue)
    ;;
  -h|--help|"")
    usage
    exit 0
    ;;
  *)
    echo "ERROR: unknown target '$target'." >&2
    usage >&2
    exit 2
    ;;
esac

sdk_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

eximia_dir="${EXIMIA_PSX_DIR:-$sdk_root/eximia-10.13}"
bamblue_dir="${BAMBLUE_PSX_DIR:-$sdk_root/bamblue-10.13}"

require_project() {
  local dir="$1"
  local label="$2"

  if [[ ! -f "$dir/package.json" ]]; then
    echo "ERROR: $label project was not found at:" >&2
    echo "  $dir" >&2
    exit 3
  fi
}

require_project "$eximia_dir" "Exímia PSX"
require_project "$bamblue_dir" "BamBlue PSX"

if [[ "$target" == "eximia" ]]; then
  source_name="BamBlue PSX"
  source_dir="$bamblue_dir"
  target_name="Exímia PSX"
  target_dir="$eximia_dir"
else
  source_name="Exímia PSX"
  source_dir="$eximia_dir"
  target_name="BamBlue PSX"
  target_dir="$bamblue_dir"
fi

echo "=== PolyScope X application switch ==="
echo "From: $source_name"
echo "To:   $target_name"
echo

if [[ -f "$target_dir/scripts/target-preflight.js" ]]; then
  echo "[switch-psx] Checking simulator before changing installed URCaps..."
  (
    cd "$target_dir"
    node - <<'NODE'
const { assertSimulatorReachable } = require('./scripts/target-preflight');

assertSimulatorReachable()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(`\n[switch-psx] ${error?.message || String(error)}`);
    process.exit(1);
  });
NODE
  )
else
  echo "[switch-psx] WARNING: target preflight helper not found."
  echo "[switch-psx] The target repository may need git pull --ff-only."
fi

echo
echo "[switch-psx] Removing $source_name..."
(
  cd "$source_dir"
  npm run delete-urcap
)

echo
echo "[switch-psx] Installing $target_name..."
(
  cd "$target_dir"
  npm run install-fast
)

echo
echo "[switch-psx] Switch complete: $target_name is now the active development URCap."
