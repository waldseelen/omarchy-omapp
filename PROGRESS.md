# PROGRESS.md

## Current Gate Status (2026-10-28)

- `omarchy plugin validate /home/hp/Work/omarchy-omapp`: **PASS** exit 0, schemaVersion 1, valid manifest & kinds/entrypoints mapping
- `for t in tests/test_*.js; do node "$t" || exit 1; done`: **PASS** 7 suites (`test_safe_ops`, `test_sudo_keeper`, `test_scanner`, `test_sorter`, `test_task_manager`, `test_leftover_hunter`, `test_extended_modules`); 0 errors
- `wc -l *.qml ui/*.qml script/*.js`: **PASS** all 25 source files ≤400 lines (max: `Omapp.qml` 397 lines, `LeftoverReviewModal.qml` 396 lines)
- `! grep -En '#[0-9a-fA-F]{6}' *.qml ui/*.qml`: **PASS** 0 hardcoded hex colors across all QML files

## 2026-10-28 — Touchpad Sensitivity & Smooth Kinetic Scrolling Overhaul

- **Değişen alanlar (`path›symbol`)**:
  - `TaskManagerView.qml`: Added dedicated `WheelHandler` with `1.8x` fine `pixelDelta` amplification and `50px` notch stepping; added `scrollActiveTimer` (1200ms) to lock background timer refreshes during active scrolling (`isUserScrolling`); tuned physics with `pixelAligned: false`, `flickDeceleration: 750`, `maximumFlickVelocity: 6000`.
  - `ui/AppsView.qml`, `ui/StartupServicesView.qml`: Configured `WheelHandler` and optimized physics parameters (`pixelAligned: false`, `flickDeceleration: 750`, `maximumFlickVelocity: 6000`).
  - `SystemJanitorView.qml`, `AppInspector.qml`, `ui/TaskInspector.qml`, `LeftoverReviewModal.qml`: Equipped all `Flickable` containers with `WheelHandler` and fluid kinetic scrolling parameters.
- **Kanıt**: `omarchy plugin validate` PASS (exit 0), 7 Node.js test suites PASS (exit 0), `wc -l` ≤400 lines PASS across all 25 source files, 0 hex colors PASS.
- **Kalan boşluk**: Yok.

## 2026-10-28 — Omarchy Plugin Marketplace Compliance & BarWidget Refactor

- **Değişen alanlar (`path›symbol`)**:
  - `OmappBarWidget.qml`: Refactored base component from `Panel` to `BarWidget` and `WidgetButton` (`qs.Ui`), adhering to Omarchy's official bar widget contract; added tooltip, click registration via `bar.run(...)`, and native hover handling.
  - `README.md`: Documented official marketplace installation (`omarchy plugin add`), removal (`omarchy plugin remove`), and direct Omarchy Shell IPC summon routes.
  - `ARCHITECTURE.md`: Registered `BarWidget` and `WidgetButton` under `qs.Ui` primitive dependencies.
- **Kanıt**: `omarchy plugin validate` PASS (exit 0), 7 Node.js test suites PASS (exit 0), `wc -l` ≤400 lines PASS, 0 hex colors PASS.
- **Kalan boşluk**: Yok.

## 2026-10-28 — System Janitor Verification, Inline Confirmation & Feedback Banner

- **Değişen alanlar (`path›symbol`)**:
  - `script/SudoKeeper.js›buildCacheCleanCommand, buildOrphanCleanCommand`: Updated Pacman cache cleaner to `paccache -rk1 && paccache -ruk0` (with `pacman -Sc --noconfirm` fallback) and added structured `CLEAN_OK:` completion output.
  - `script/JanitorOps.js›buildJanitorScanScript, parseJanitorStats, buildCleanCommand`: Aligned scanned vs. cleaned directory paths for `yay`/`paru`, `dev` (`_cacache`, `_logs`, `_npx`), and `browser`; normalized empty directory `<=16 KiB` metadata to `0 B`; added `size` alias for backup objects and `CLEAN_OK:` status output.
  - `script/LeftoverHunter.js›buildOrphanDotfilesScanScript`: Added desktop/system cache whitelist (`mesa_shader_cache`, `fontconfig`, `omarchy`, `hypr`, etc.) and scanned both `~/.cache` and `~/.config`.
  - `SystemJanitorView.qml`, `Omapp.qml`: Added 2-step inline `Confirm Clean / Cancel` guard on all 8 Janitor cards and backup `Restore`, live `Cleaning...` state, `Rescan` button, and a status feedback banner; fixed missing `SafeOps` argument in `scanOrphanDotfiles()`.
- **Kanıt**: 7 Node.js test suite PASS, `wc -l` ≤400 lines PASS, 0 hex colors PASS.
- **Kalan boşluk**: Yok.

## 2026-10-28 — OMAPP Pro 30-Feature Expansion & Modular Architecture

- **Değişen alanlar (`path›symbol`)**:
  - `script/SafeOps.js›isProtectedCorePackage, buildRestoreBackupCommand`: Core package uninstall guard (#20) and `.tar.gz` backup restore command builder (#16).
  - `script/SudoKeeper.js›buildUninstallCommand, buildBatchUninstallCommand, buildDowngradeCommand`: Flatpak removal (#12), multi-package batch removal (#13), and cached `.pkg.tar.zst` downgrade (#14).
  - `script/Scanner.js›buildInventoryScanScript, parseInventory, buildPackageDeepInspectScript`: User config/cache footprint (#11), Flatpak & AppImage discovery (#12), >30-day unused flag (#15), `pacman -Qlq` file list (#14), and `pactree` dependency tree (#19).
  - `script/Sorter.js›filterItems, sortItems`: Pinned-first sorting (#30), `userdata`/`total` footprint sorting (#11), and `flatpak`/`unused` category filters (#12, #15).
  - `script/TaskManager.js›buildProcessScanScript, parseSystemHeaderStats, parseProcessOutput, groupTasksByApp`: Live system telemetry (#2), `/proc/<pid>/io` Disk B/s (#5), frozen `T` state & nice value (#3, #4), and collapsible process grouping by app (#1).
  - `script/TaskControl.js›buildFreezeCommand, buildReniceCommand, buildAffinityCommand, parseProcessDetails`: Process `SIGSTOP`/`SIGCONT` (#4), `renice`/`taskset` (#3), `ss -tulnp` listening ports (#10), and `journalctl _PID` logs (#9).
  - `script/StartupServices.js›buildServicesScanScript, parseServicesOutput, buildServiceActionCommand`: 4th tab systemd user/system services, `systemd-analyze blame` impact (#7), Hyprland/XDG autostart (#6), and unit control/logs (#8, #9).
  - `script/JanitorOps.js›buildJanitorScanScript, buildCleanCommand`: 8-card System Janitor for Journal vacuum (#21), Dev caches (#22), Docker prune (#23), Broken symlinks & `.pacnew` (#24), Safe browser caches (#25), and backup list (#16).
  - `script/LeftoverHunter.js›buildPreviewCommand, buildOrphanDotfilesScanScript`: Leftover file/folder preview (#18) and orphaned `~/.cache` scanner (#17).
  - `script/StateStore.js`, `script/ModelSync.js`: Persistent user preferences (#28, #30) and in-place `ListModel` sync.
  - `Omapp.qml`, `OmappHeader.qml`, `OmappBarWidget.qml`, `AppGridRow.qml`, `AppInspector.qml`, `TaskManagerView.qml`, `SystemJanitorView.qml`, `LeftoverReviewModal.qml`, `ui/*.qml`: Modular QML UI (all ≤400 lines, 0 hex colors) implementing all 30 features including right-click context menu (#26), keybind footer (#27), and Omarchy bar widget (#29).
- **Kanıt**: 7 Node.js test suite PASS, `wc -l` ≤400 lines PASS, 0 hex colors PASS.
- **Kalan boşluk**: Yok.
