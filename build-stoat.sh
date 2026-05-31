#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nix
#
# Build Stoat for Desktop — all Linux + Flatpak targets
# Uses the repo's own default.nix for the dev environment.
#
# Usage:
#   ./build-stoat.sh                    # clone + build
#   ./build-stoat.sh /path/to/repo      # use existing repo
#   ./build-stoat.sh --skip-pull        # skip git pull

set -euo pipefail
shopt -s inherit_errexit

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="${1:-"$SCRIPT_DIR/stoat-for-desktop"}"
SKIP_PULL=false

for arg in "$@"; do
  case "$arg" in
    --skip-pull) SKIP_PULL=true ;;
  esac
done

if [ ! -d "$REPO" ]; then
  echo ":: Cloning stoatchat/for-desktop → $REPO"
  git clone --recursive https://github.com/stoatchat/for-desktop.git "$REPO"
fi

cd "$REPO"

if [ "$SKIP_PULL" = false ]; then
  echo ":: Pulling latest changes"
  git pull --recurse-submodules
fi

echo ":: Initialising submodules"
git submodule update --init --recursive

echo ":: Entering nix dev shell and building"
nix-shell default.nix --run '
  set -euo pipefail

  echo "  → Installing dependencies (pnpm install)"
  pnpm install --frozen-lockfile

  echo "  → Building ALL Linux + Flatpak targets (pnpm make)"
  pnpm make

  echo ""
  echo "  ✓ Build complete!"
  echo "  → Outputs are in: out/make/"
  echo "    - out/make/zip/          (Linux .zip) "
  echo "    - out/make/deb/          (.deb package)"
  echo "    - out/make/flatpak/      (.flatpak bundle)"
'
