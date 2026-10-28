# CLAUDE.md — OMAPP Binding Engineering Rules

## 0. Read Order
Before modifying any file in this repository, read the project documents in this order:
1. `CLAUDE.md` — binding rules and invariants
2. `ARCHITECTURE.md` — component tree, layer flow, and IPC entrypoints
3. `SPEC.md` — intended behavior, schemas, and formulas
4. `MEMORY.md` — durable non-obvious Quickshell and Linux kernel facts
5. `PROGRESS.md` — gate results and session log
6. `README.md` — human-facing orientation

## 1. Approval Protocol
- Zero state-changing actions without explicit user approval (`başla`, `uygula`, `onaylıyorum`).
- Read-only inspection (`read_file`, `grep_search`, `git status/diff/log`) is always allowed prior to approval.

## 2. Hard Invariants
1. **File Size Limit (`≤400 lines`)**: Every `.qml` and `.js` source file in this repository must stay at or below 400 lines. Split components into `ui/*.qml` and pure logic into `script/*.js` before approaching the limit.
2. **Zero Hardcoded Colors**: Never use hex color literals (`#[0-9a-fA-F]{6}`) in any `.qml` file. Always bind to Omarchy's native `qs.Commons` theme tokens (`Color.menu.background`, `Color.menu.text`, `Color.accent`, `Color.urgent`, `Color.muted`, `Style.normalFill`, `Style.hoverFill`).
3. **Business Logic in `script/`**: Parsing, sorting, filtering, command construction, and path validation live in pure JavaScript modules under `script/*.js` with Node.js unit test coverage in `tests/test_*.js`. QML components only orchestrate state and render UI.
4. **In-Place `ListModel` Sync**: Never bind a rapidly refreshing `ListView` directly to a reassigned JS array (`model: root.displayTasks`). Always synchronize a persistent `ListModel` via `ModelSync.js` (`set` / `append` / `remove`) so touchpad kinetic flicking is never interrupted.
5. **Path & Package Safety Barriers**:
   - All user file deletions must pass `SafeOps.validatePurgeTarget(path, home)` (depth ≥ 2 inside `$HOME`, never symlink, never in `PROTECTED_USER_RELATIVES`).
   - Core system packages listed in `SafeOps.PROTECTED_CORE_PACKAGES` (`linux`, `systemd`, `hyprland`, `quickshell`, `omarchy`, etc.) must be blocked from uninstallation in both `SafeOps.js` and `SudoKeeper.js`.
6. **Zero Credential Leaks**: Sudo authentication streams the password via stdin (`printf "%s\n" "$1" | sudo -S -v`) and never interpolates passwords into shell command strings.

## 3. Verification Gates
Every change must pass all three gates before completion or commit:
1. **Unit Tests**: `for t in tests/test_*.js; do node "$t" || exit 1; done`
2. **Line Limit Gate**: `wc -l *.qml ui/*.qml script/*.js` (every file `≤400` lines)
3. **Theme Token Gate**: `! grep -En '#[0-9a-fA-F]{6}' *.qml ui/*.qml` (0 matches)
