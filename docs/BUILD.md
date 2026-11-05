# Build Instructions

All presets are in `export_presets.cfg`. First install export templates: **Editor → Manage Export Templates → Download and Install** (must match your Godot version).

## Desktop
| Platform | Command |
|---|---|
| Windows | `godot --headless --export-release "Windows Desktop"` → `build/windows/TheHollowBetween.exe` |
| Linux | `godot --headless --export-release "Linux"` → `build/linux/TheHollowBetween.x86_64` |
| macOS | `godot --headless --export-release "macOS"` (export on a Mac to sign/notarize) |

PCK is embedded, so each build is a single file.

## Web
`godot --headless --export-release "Web"` → `build/web/`. Threads are off, so it works on any static host (GitHub Pages, itch.io) without special headers. Serve locally with `python3 -m http.server -d build/web`.

**GitHub Pages:** the game is live at https://jaigod.github.io/the-hollow-between/ (landing page) and https://jaigod.github.io/the-hollow-between/play/ (the game). `.github/workflows/pages.yml` re-exports and deploys on every push to `main` (Settings → Pages → Source: **GitHub Actions**). The landing page is `web/index.html`; screenshots are copied from `docs/screenshots/`.

## Android
1. Install Android SDK + JDK 17; set paths in **Editor Settings → Export → Android**.
2. Create a release keystore:
   `keytool -genkey -v -keystore hollow.keystore -alias hollow -keyalg RSA -validity 10000`
3. Set it in the Android preset (stored in `.godot/export_credentials.cfg`, git-ignored).
4. `godot --headless --export-release "Android" build/android/TheHollowBetween.apk`
5. For Google Play, export an **AAB**: enable *Use Gradle Build*, install the Android build template, change the path to `.aab`. Package name: `com.jaking.hollowbetween`.

## iOS
Requires a Mac with Xcode. Set your Team ID in the iOS preset, export, open the generated Xcode project, then Archive → Distribute.

## Steam
1. Get an App ID in Steamworks; create depots for Windows/Mac/Linux.
2. Install **GodotSteam** (GDExtension from the Asset Library). `Achievements.gd` detects the `Steam` singleton automatically and forwards unlocks.
3. Create achievements in Steamworks with these API names: `first_spare`, `first_friend`, `pacifist_slice`, `archivist_spared`, `archivist_defeated`, `secret_hollow`, `graze_master`, `all_quests`.
4. **Cloud saves:** Steamworks → Auto-Cloud → root `WinAppDataRoaming` path `Godot/app_userdata/The Hollow Between/saves`, pattern `*.json`. No code needed.
5. Upload with SteamPipe: `steamcmd +login <user> +run_app_build app_build.vdf +quit`.
6. For local testing put `steam_appid.txt` (git-ignored) next to the executable.

## CI
`.github/workflows/pages.yml` (container `barichello/godot-ci:4.4.1`): runs the headless smoke test → exports Web → assembles the landing page + `/play/` → deploys to GitHub Pages.
