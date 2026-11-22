# The Thirteenth Bell: Prototype V2 release notes

**Status:** ready for human playtesting. It hasn't been played by testers yet, and no gameplay score is claimed until they have.
**Engine:** Godot 4.7.2 (Compatibility renderer).
**Branch:** `prototype-v2`. The V1 code is tagged `v1-baseline`.

## What's new
- **The Forgotten Promise:** an optional mystery at the village well. Gather three clues, piece together what Tobin promised Elsie, then decide whether to tell him. One choice earns his lantern for the Mistbound Path.
- **The Bell's Resonance:** choosing *Retune the bell* now means performing the Gathering Song on the bell. Follow the song's shape from the ledger, with no timing and unlimited retries.
- **Clearer interactions:** gold prompts for story objects, named and highlighted chapel seals, short captions instead of extra dialogue boxes, and Echo visions free of UI clutter.

## Fixed
- The Keeper ending no longer freezes. All three endings reach their title card, epilogue and Return to Title.
- Saving is no longer left disabled after leaving the mist trial through the title screen.
- Saves are crash-safe: written to a temporary file, verified, with the previous save kept as a backup.
- Long epilogues and long journals scroll (keyboard and mouse).
- Better visibility for the forge pin, for Rowan in fog, and for mist hazard warnings.
- Village subtitle at night; Camera2D warning; repeated "press F" tutorial lines.

See `V2_CHANGELOG.md` for details and the QA issue IDs.

## Known limitations
- **No human playtest yet.** Use `V2_PLAYTEST_GUIDE.md`.
- **Audio:** the new sounds (ritual notes, sour note, memory swell) were generated and their levels measured. Nobody has listened to them.
- **Gamepad:** bindings exist but are untested.
- **Browser:** the web build ran in the in-app browser through a new game, Echo, journal, saving, reload and Continue, The Keeper (complete) and the ritual into The Chorus.
  - Not verified there: frame rate (the test page was throttled in the background), F11 fullscreen (the browser refused a scripted request without a user gesture), and the mouse wheel on the epilogue.
  - Not tried: Firefox, Safari or mobile.
- **Windows `.exe`:** the V2 export boots to the title with no script errors. It has not been played through by hand.
- Phones aren't supported (no touch controls).

## How to run
- **Editor:** open `project.godot` in Godot 4.7.2 and press F5.
- **Windows:** `builds/windows_v2/TheThirteenthBell.exe` (not in Git; rebuild with the commands below).
- **Tests** (48 tests, about 90 s):
  ```powershell
  & "<godot>\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_runner.tscn
  ```
- **Visual tour** (windowed; saves screenshots to `docs/screenshots/v2/`; sections: `story`, `v2`, `endings`):
  ```powershell
  & "<godot>\Godot_v4.7.2-stable_win64_console.exe" --path . res://tests/tour.tscn -- --only=v2
  ```

## How to build
Export templates for 4.7.2 must be installed (Editor → Manage Export Templates).

```powershell
& "<godot>\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Web" builds/web_v2/index.html
& "<godot>\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Windows Desktop" builds/windows_v2/TheThirteenthBell.exe
```

- The **Web** preset is single-threaded, so it runs on any static host without special headers.
- **Test it locally:**
  ```powershell
  python -m http.server 8061 --bind 127.0.0.1 --directory builds/web_v2
  ```
  Open `http://localhost:8061` and click once to enable sound.
- **Publishing (manual, not done automatically):** the live Vercel site serves the `web/` folder on `main`. To publish V2:
  1. Merge `prototype-v2` into `main`.
  2. Copy `builds/web_v2/*` (except `probe.html`, a test page) into `web/`.
  3. Commit and push. Vercel redeploys `main` by itself.

  Pushing the `prototype-v2` branch would also create a Vercel *preview* deployment; this hasn't been done.

## Compatibility
- **Saves:** V1 saves load in V2 (tested with two saves the V1 game wrote during the audit). The format is unchanged (`version: 1`). A `.bak` copy of the previous save now sits next to the save.
- **Controls:** the same as V1. New screens use W/S, A/D, E and Esc.
