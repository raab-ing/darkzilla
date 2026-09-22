# darkzilla

**FileZilla Client for Windows 11, with native dark mode.**

Unofficial build of [FileZilla Client](https://filezilla-project.org/) that adds
one feature: real Windows dark mode. It **follows the Windows light/dark
setting** automatically — no configuration needed.

## Why?

FileZilla draws its UI with wxWidgets, which only gained Windows dark-mode
support in wxWidgets 3.3 (`wxApp::MSWEnableDarkMode()`). Upstream FileZilla
still builds against wxWidgets 3.2.x, so the official binaries can't go dark.
This project rebuilds FileZilla against wxWidgets 3.3 with a small patch
series that enables dark mode and fixes the rendering bugs it exposes.

## Installing

**One-liner** (paste into PowerShell — downloads and installs the latest
release, no zip needed):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm 'https://raw.githubusercontent.com/raab-ing/darkzilla/main/install.ps1')"
```

**Or from the zip:**

1. Download `darkzilla-<ver>-win64.zip` from the
   [Releases](../../releases) page.
2. Extract it anywhere.
3. Double-click **`install.cmd`**. It copies the app to
   `%LOCALAPPDATA%\darkzilla` and creates Start Menu/Desktop shortcuts —
   no admin required.

> Running `install.ps1` directly fails on stock Windows ("not digitally
> signed") — that's the PowerShell execution policy, not a bug. Use
> `install.cmd`, or if you prefer the script:
> `powershell -ExecutionPolicy Bypass -File .\install.ps1`.

Or skip the installer entirely and just run `filezilla.exe` from the
extracted folder; it's portable (settings live in `%APPDATA%\FileZilla`,
shared with any stock FileZilla install).

## Updating — dark mode survives every release

A scheduled GitHub Actions workflow checks weekly for new upstream FileZilla
releases. When one appears, it applies the patch series, builds, and publishes
a new `darkzilla` release automatically.

To update your install, double-click **`update.cmd`** in
`%LOCALAPPDATA%\darkzilla` (or in a freshly extracted zip), or run:

```powershell
%LOCALAPPDATA%\darkzilla\install.cmd -Update
```

The built-in FileZilla update checker is **disabled** in these builds
(`--disable-manualupdatecheck`) — updating through the official updater would
replace the dark build with a stock (light-only) one. Always update via
darkzilla releases instead.

## What's patched

See [`CHANGES.darkzilla.md`](CHANGES.darkzilla.md) for the per-file list.
Summary:

| Patch | Purpose |
|---|---|
| `patches/filezilla/0001-port-to-wxwidgets-3.3.patch` | Compile/runtime fixes so FileZilla builds and behaves correctly on wxWidgets 3.3 |
| `patches/filezilla/0002-enable-dark-mode.patch` | `MSWEnableDarkMode()` (follow-system) + readable group-box labels in dark mode |
| `patches/filezilla/0003-dark-mode-filelist-flicker.patch` | Fix file-list hover flicker in dark mode |
| `patches/wxwidgets/wx333-darkmode-ownerdrawn-fixes.patch` | wxWidgets fix: route `WM_DRAWITEM` by HWND — without it, checkboxes/radio buttons render blank in dark dialogs |

Patch set derived from the excellent reference implementation at
[Pharaoh2k/FileZilla-Themed-For-Windows](https://github.com/Pharaoh2k/FileZilla-Themed-For-Windows),
repackaged here as a patch series + automated build pipeline.

## Building yourself

Everything runs in CI, but you can build locally with MSYS2:

```sh
# in an MSYS2 MINGW64 shell
pacman -S --needed patch zip tar curl make
pacboy -S toolchain:p pkgconf:p nettle:p gnutls:p sqlite3:p gettext:p \
         libidn2:p boost:p gmp:p argon2:p meson:p ninja:p
scripts/build-msys2.sh 3.71.0
# produces work/dist/darkzilla-3.71.0-win64.zip
```

Dependency versions are pinned at the top of `scripts/build-msys2.sh`
(`WXVER`, `LIBFZVER`, `FZSSHVER`).

## Notes & caveats

- **Unsigned binary** — Windows SmartScreen will warn on first run ("Windows
  protected your PC" → *More info* → *Run anyway*).
- **wxWidgets 3.3 is a development branch** — production-suitable per upstream,
  but ABI/API isn't frozen between 3.3.x releases, so the version is pinned.
- **wxWidgets patch note** — the `WM_DRAWITEM`-by-HWND patch is applied to the
  wxWidgets source before building; FileZilla reuses `nullID` for many
  owner-drawn controls, which breaks wx's id-based dispatch.
- If a future FileZilla release changes the patched lines, the CI build fails
  loudly instead of shipping a broken/light build; patches then get rebased.

## License & trademark

FileZilla is **GPL-3.0-or-later**; these modifications are licensed the same.
Complete source = upstream `filezilla_<ver>.orig.tar.xz` + the patches in this
repository. "FileZilla" is a trademark of its respective owner; darkzilla is an
unofficial, unaffiliated build — the name and branding are distinct to comply
with the FileZilla trademark policy.
