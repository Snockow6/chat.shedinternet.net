#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nix
#
# Build Stoat for Desktop — all Linux + Flatpak targets
# Uses the repo's own default.nix for the dev environment.
#
# Usage:
#   ./build-stoat.sh                                            # clone + build
#   ./build-stoat.sh /path/to/repo                              # use existing repo
#   ./build-stoat.sh --skip-pull                                # skip git pull
#   ./build-stoat.sh --url https://example.com/repo             # override clone URL
#   ./build-stoat.sh --server-url https://example.com           # set app server URL
#   STOAT_REPO_URL=... STOAT_SERVER_URL=... ./build-stoat.sh    # via env vars
#
# Environment:
#   STOAT_REPO_URL    git URL to clone (default: https://github.com/stoatchat/for-desktop.git)
#   STOAT_SERVER_URL  app server URL baked into the build (default: whatever is in source)

set -euo pipefail
shopt -s inherit_errexit

STOAT_REPO_URL="${STOAT_REPO_URL:-https://github.com/stoatchat/for-desktop.git}"
STOAT_SERVER_URL="${STOAT_SERVER_URL:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO=""
SKIP_PULL=false

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-pull) SKIP_PULL=true; shift ;;
    --url) STOAT_REPO_URL="$2"; shift 2 ;;
    --server-url) STOAT_SERVER_URL="$2"; shift 2 ;;
    *) REPO="$1"; shift ;;
  esac
done

REPO="${REPO:-"$SCRIPT_DIR/stoat-for-desktop"}"

if [ ! -d "$REPO" ]; then
  echo ":: Cloning $STOAT_REPO_URL → $REPO"
  git clone --recursive "$STOAT_REPO_URL" "$REPO"
fi

cd "$REPO"

if [ "$SKIP_PULL" = false ]; then
  echo ":: Pulling latest changes"
  git pull --recurse-submodules
fi

echo ":: Initialising submodules"
git submodule update --init --recursive

WINDOW_SRC="src/native/window.ts"

if [ -n "$STOAT_SERVER_URL" ]; then
  echo ":: Patching server URL → $STOAT_SERVER_URL"
  # grab the current URL to restore later
  OLD_URL=$(sed -n "s/.*\"\(https\?:\/\/[^\"]*\)\".*/\1/p" "$WINDOW_SRC" | head -1)
  sed -i "s|\"https\?://[^\"]*\"|\"$STOAT_SERVER_URL\"|g" "$WINDOW_SRC"
fi

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

if [ -n "$STOAT_SERVER_URL" ]; then
  echo ":: Restoring original server URL"
  git checkout -- "$WINDOW_SRC"
fi
