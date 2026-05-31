# chat.shedinternet.net

Build scripts for [Stoat](https://github.com/stoatchat/for-desktop) desktop client, pointed at [chat.shedinternet.net](https://chat.shedinternet.net).

## Usage

```sh
# Default build (clones stoatchat/for-desktop, builds all Linux targets)
./build-stoat.sh

# Build with custom app server URL
./build-stoat.sh --server-url https://chat.shedinternet.net

# Use an existing checkout
./build-stoat.sh /path/to/stoat-for-desktop

# Override the git clone URL
./build-stoat.sh --url https://github.com/your-fork/for-desktop.git

# Skip git pull
./build-stoat.sh --skip-pull
```

Artifacts are produced in `stoat-for-desktop/out/make/`:

| Format | Path |
|---|---|
| Flatpak | `stoat-for-desktop/out/make/flatpak/` |
| Deb | `stoat-for-desktop/out/make/deb/` |
| Zip | `stoat-for-desktop/out/make/zip/` |

## Requirements

- [Nix](https://nixos.org/download) with flakes enabled
