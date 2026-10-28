# ARCHITECTURE.md — OMAPP System Blueprint

## 1. Repository Layout

```text
omarchy-omapp/
├── manifest.json              # Omarchy plugin manifest (overlay, menu, bar-widget)
├── bin/omapp                  # CLI wrapper invoking `omarchy-shell shell`
├── Omapp.qml                  # Root overlay window, state orchestrator, keyboard router
├── OmappBarWidget.qml         # Omarchy top-bar telemetry widget (CPU % · RAM GiB)
├── OmappHeader.qml            # Top bar: search input, system telemetry pill, 4-tab switcher, category pills
├── AppGridRow.qml             # Delegate row for Applications table
├── AppInspector.qml           # Right-hand inspector for selected package (files, dep tree, downgrade)
├── TaskManagerView.qml        # Split view for Tasks tab (6-column table + TaskInspector)
├── SystemJanitorView.qml      # 8-card bento grid for System Janitor + Backup Restore list
├── LeftoverReviewModal.qml    # 4-phase Deep Uninstall & residual file preview modal
├── SudoPromptModal.qml        # Password modal for `sudo -S -v` session unlock
├── ui/
│   ├── AppsView.qml           # Applications split view (batch bar + 5-column header + ListView + AppInspector)
│   ├── TaskInspector.qml      # Process inspector (kill, freeze/resume, priority, ports, journal logs)
│   ├── StartupServicesView.qml# 4th tab: systemd user/system units, boot blame, autostart & log viewer
│   ├── ContextMenuPopup.qml   # Right-click action popup menu for Apps, Tasks, and Services
│   └── KeybindFooterBar.qml   # Bottom keyboard shortcut hint bar
├── script/
│   ├── SafeOps.js             # Path normalization, protected package & dotfile guards, tar backup/restore
│   ├── SudoKeeper.js          # Sudo session validation, uninstall, batch remove, downgrade command builders
│   ├── Scanner.js             # Pacman, AUR, Flatpak, AppImage, desktop & user-data footprint scanner
│   ├── Sorter.js              # Category filtering & multi-column sorting (with pinned priority) for Apps
│   ├── TaskManager.js         # Process, DRM fdinfo GPU, NVIDIA GPU, /proc/io Disk B/s & system telemetry parser
│   ├── TaskControl.js         # Kill, SIGSTOP/SIGCONT freeze, renice, taskset affinity, ss ports & PID journal logs
│   ├── StartupServices.js     # Systemd user/system units, systemd-analyze blame, Hyprland & XDG autostart scanner
│   ├── JanitorOps.js          # 8-category storage scanner & cleaner commands + backup archive listing
│   ├── LeftoverHunter.js      # Residual config/cache scanner, orphaned dotfile scanner & file preview builder
│   ├── StateStore.js          # Persistent JSON preferences (`~/.local/state/omapp/preferences.json`)
│   └── ModelSync.js           # In-place QML ListModel synchronizer & context menu action builders
└── tests/
    ├── test_safe_ops.js
    ├── test_sudo_keeper.js
    ├── test_scanner.js
    ├── test_sorter.js
    ├── test_task_manager.js
    ├── test_leftover_hunter.js
    └── test_extended_modules.js
```

## 2. Layer Flow
`manifest.json / bin/omapp` → `Omapp.qml` → `ui/*.qml` & View QMLs → `script/*.js` → `Quickshell.Io.Process`.

- `script/*.js` modules never import QML components and remain pure ES5/ES6 compatible with both QML's JS engine and Node.js test runners.
- All UI surfaces inherit from Omarchy's `qs.Ui` primitives (`BorderSurface`, `CursorSurface`, `Button`, `TextField`, `PanelSeparator`, `Panel`) and `qs.Commons` (`Color`, `Style`, `Border`, `Util`).
