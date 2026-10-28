# OMAPP — Omarchy App Manager, Task Manager, Services & Deep Cleaner

Native Quickshell overlay and bar widget for Omarchy and Arch Linux. Manage installed packages (`pacman`, AUR, Flatpak, AppImage, Web Apps), monitor real-time CPU/GPU/RAM/Disk I/O per process, control systemd startup services, and deeply purge residual user dotfiles with automatic safety backups.

![OMAPP Preview](preview.png)

---

## Features

- **Applications & Package Manager (`Apps` Tab)**:
  - Unified inventory across native Arch (`pacman`), AUR (`yay`), Flatpak, AppImage (`~/Applications`), and Web Apps.
  - Per-application **User Data Footprint** (`~/.config`, `~/.cache`, `~/.local/share`) alongside binary size.
  - Multi-select checkboxes for **Batch Uninstall**, **Pin to Top**, and **Unused (>30d)** package filtering.
  - Deep package inspector with `pacman -Ql` file viewer, `pactree` dependency tree, and 1-click cached version **Downgrade**.
  - **Core Package Guard** preventing accidental removal of critical system packages (`linux`, `systemd`, `hyprland`, `quickshell`, `omarchy`).
- **Task Manager Pro (`Tasks` Tab)**:
  - Windows Task Manager style clickable column headers (`Process Name`, `PID`, `CPU`, `GPU`, `RAM`, `Disk`).
  - Hybrid GPU tracking combining NVIDIA (`nvidia-smi`) and Linux DRM `/proc/<pid>/fdinfo` engine % + VRAM/GTT memory.
  - **Group Apps** mode collapsing multi-process apps (e.g. `brave (12)`) with aggregated resource totals.
  - Process **Freeze / Resume** (`SIGSTOP` / `SIGCONT`), **Priority (`renice`)**, **CPU Affinity**, **Listening Ports (`ss`)**, and **Live PID Journal Logs**.
- **Startup & Services (`Services` Tab)**:
  - Manage `systemctl --user` units, system daemons, Hyprland `exec-once` rules, and `~/.config/autostart/*.desktop` entries.
  - **Boot Impact Analysis** powered by `systemd-analyze blame` (`High`, `Medium`, `Low` ms) and live unit journal logs.
- **System Janitor & Backup Restore (`Janitor` Tab)**:
  - 8-card storage reclamation grid: Orphan Packages, Pacman Cache, AUR Cache, Systemd Journal Vacuum, Developer Caches (`npm`, `pip`, `cargo`, `go`, `gradle`), Safe Browser Caches, Docker Prune, and Broken Symlinks / `.pacnew`.
  - **Orphaned Dotfiles Scanner** and 1-click `.tar.gz` **Backup Restore** from `~/.local/share/omapp/backups/`.
- **Omarchy Top-Bar Widget**:
  - Live `CPU % · RAM GiB` bar indicator (`OmappBarWidget.qml`) that summons OMAPP directly to the Task Manager on click.

---

## Installation & CLI Usage

```bash
# Install and enable via Omarchy Plugin Manager
omarchy plugin add https://github.com/waldseelen/omarchy-omapp.git --enable

# Safe removal
omarchy plugin remove waldseelen.omapp
```

Summon or toggle from CLI or keybindings:

```bash
omapp           # Toggle OMAPP overlay
omapp apps      # Open directly to Applications tab
omapp tasks     # Open directly to Task Manager tab
omapp services  # Open directly to Startup & Services tab
omapp janitor   # Open directly to System Janitor tab

# Direct Omarchy Shell IPC summon
omarchy-shell shell summon waldseelen.omapp '{"tab":"tasks"}'
omarchy-shell shell hide waldseelen.omapp
```

---

## Keyboard Shortcuts

| Keybinding | Action |
| :--- | :--- |
| `SUPER + Ç` | Toggle OMAPP overlay |
| `1` / `2` / `3` / `4` | Switch between `Apps`, `Tasks`, `Services`, and `Janitor` tabs |
| `↑` / `↓` or `J` / `K` | Navigate rows |
| `/` | Focus search / filter input |
| `Space` | Toggle batch selection checkbox (`Apps` tab) |
| `P` | Pin / Unpin selected application or process to top |
| `G` | Toggle Group by Application (`Tasks` tab) |
| `F` | Freeze (`SIGSTOP`) / Resume (`SIGCONT`) selected process (`Tasks` tab) |
| `Del` or `U` | Deep Uninstall (`Apps`) or End Task (`Tasks`) |
| `Right-Click` | Open quick context action menu |
| `Esc` | Close active popup/modal or exit OMAPP |

---

## License

MIT © 2026 waldseelen
