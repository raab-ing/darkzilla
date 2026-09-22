# Modifications to upstream FileZilla

Per GPLv3 §5, this file lists the changes darkzilla applies to the upstream
FileZilla Client source distribution (`filezilla_<ver>.orig.tar.xz`).

- **Base version:** FileZilla 3.71.0 (see `UPSTREAM_VERSION` for the current one)
- **License:** unchanged — GNU GPL v3 or (at your option) any later version
- **Derived from:** Pharaoh2k/FileZilla-Themed-For-Windows (GPLv3+), adapted
  into a patch series

## Patch series (`patches/filezilla/`)

### 0001-port-to-wxwidgets-3.3.patch

| File | Change |
|---|---|
| `configure`, `configure.ac` | Relax the "must use wxWidgets 3.2.x" version gate so wx 3.3.x is accepted |
| `src/interface/aui_notebook_ex.cpp` | `GetTabSize` override `wxDC&` → `wxReadOnlyDC&`; drop base `wxAuiNotebook::OnTabDragMotion(evt)` call (removed/internal in wx 3.3.2) |
| `src/interface/fileexistsdlg.cpp` | `wxIcon` `SetHandle`/`SetSize` → `InitFromHICON` |
| `src/interface/LocalTreeView.cpp` | Explicit `wchar_t` cast (wx 3.3 dropped implicit wxString narrowing) |
| `src/interface/sitemanager_controls.cpp` | Wide string literals (`L"..."`) for comparisons |
| `src/interface/settings/optionspage_filetype.cpp` | Wide char literal (`L'|'`) |
| `src/interface/file_utils.cpp` | `CallSHFileOperation`: create the modal-loop helper window hidden and size-less (`wxTRANSPARENT_WINDOW` is a no-op since wx 3.3); fixes file list/tree blanking behind shell delete/rename dialogs |
| `src/interface/Mainfrm.cpp` | Message log "as tab in queue pane": create status view as child of queue notebook + `Reparent` before `AddPage` (wx 3.3.3 asserts instead of reparenting) |

### 0002-enable-dark-mode.patch

| File | Change |
|---|---|
| `src/interface/FileZilla.cpp` | Call `MSWEnableDarkMode()` (DarkMode_Auto = follow Windows setting) in `OnInit()` before windows are created; when dark, re-enable `msw.staticbox.optimized-paint` so group-box labels aren't painted black |

### 0003-dark-mode-filelist-flicker.patch

| File | Change |
|---|---|
| `src/interface/filelistctrl.cpp` | Don't force `wxBG_STYLE_SYSTEM` in dark mode (fixes file-list row flicker on hover) |

## wxWidgets patch (`patches/wxwidgets/`)

Applied to the wxWidgets 3.3.3 source before building — not part of the
FileZilla tree:

- `wx333-darkmode-ownerdrawn-fixes.patch` — `src/msw/window.cpp`: route
  `WM_DRAWITEM` to the owner-drawn control by HWND instead of by id.
  FileZilla reuses `nullID = wxID_HIGHEST` for many controls, so the id-based
  lookup dispatched the draw to the wrong control, leaving dark-mode
  checkboxes/radio buttons blank.

## Build-level differences from upstream binaries

- Built against wxWidgets **3.3.3** (upstream: 3.2.x)
- Configured with `--disable-manualupdatecheck` (the stock updater would
  install non-dark builds; updates ship as darkzilla releases)
- The `fzshellext` Explorer context-menu extension is not built (its nested
  configure produces an absolute `srcdir` that mingw32-make cannot stat,
  and the 32-bit variant needs an i686 toolchain we don't install)
- Unsigned binaries
