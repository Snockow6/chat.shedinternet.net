# chat.shedinternet.net

Build scripts for [Stoat](https://github.com/stoatchat/for-desktop) desktop client, pointed at [chat.shedinternet.net](https://chat.shedinternet.net).

## Usage

### Linux

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

### Windows

```powershell
# Default build (clones and builds Squirrel installer + ZIP)
.\build-stoat.ps1

# Build with custom app server URL
.\build-stoat.ps1 -ServerUrl https://chat.shedinternet.net

# Use an existing checkout
.\build-stoat.ps1 C:\projects\stoat-for-desktop

# Override the git clone URL
.\build-stoat.ps1 -Url https://github.com/your-fork/for-desktop.git

# Include AppX (MSIX) target (requires Windows SDK signing cert)
.\build-stoat.ps1 -NoCi
```

Artifacts are produced in `stoat-for-desktop/out/make/`:

| Platform | Format | Path |
|---|---|---|
| Linux | Flatpak | `stoat-for-desktop/out/make/flatpak/` |
| Linux | Deb | `stoat-for-desktop/out/make/deb/` |
| Linux | Zip | `stoat-for-desktop/out/make/zip/` |
| Windows | Squirrel | `stoat-for-desktop/out/make/squirrel/` |
| Windows | Zip | `stoat-for-desktop/out/make/zip/` |
| Windows | AppX (opt-in) | `stoat-for-desktop/out/make/appx/` |

## Downloads

Pre-built binaries for each release are available on the [Releases](https://github.com/Snockow6/chat.shedinternet.net/releases) page:

| Platform | Format | File |
|---|---|---|
| Linux | Flatpak | `chat.stoat.stoat-desktop_stable_x86_64.flatpak` |
| Linux | Deb | `stoat-desktop_<version>_amd64.deb` |
| Linux | Zip | `Stoat-linux-x64-<version>.zip` |
| Windows | Squirrel installer | `stoat-desktop-setup.exe` |
| Windows | Zip | `Stoat-win32-x64-<version>.zip` |

## Requirements

### Linux
- [Nix](https://nixos.org/download) with flakes enabled

### Windows
- [Node.js](https://nodejs.org) (pnpm is installed via corepack automatically)
