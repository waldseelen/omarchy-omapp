# SPEC.md — OMAPP Functional Specification

## 1. Core Tabs & Navigation
OMAPP exposes 4 primary tabs accessible via top segmented buttons or keys `1`–`4`, plus an Omarchy top-bar widget (`OmappBarWidget.qml`):
1. **Apps (`1`)**: Unified inventory of Pacman, AUR (`pacman -Qm`), Flatpak (`flatpak list --app`), AppImage (`~/Applications/*.AppImage`), and Web Apps (`omarchy-webapp-*`).
2. **Tasks (`2`)**: Real-time process task manager polling every 2000ms (with a 500ms initial delta sample on open).
3. **Services (`3`)**: Systemd user units (`systemctl --user`), systemd system services, `systemd-analyze blame` boot impact, Hyprland `exec-once` entries, and `~/.config/autostart/*.desktop` items.
4. **Janitor (`4`)**: 8-category storage reclamation bento grid, orphaned dotfile scanner, and `~/.local/share/omapp/backups/*.tar.gz` 1-click restore manager.

## 2. Telemetry & Formulas
- **System Header Telemetry (`TaskManager.parseSystemHeaderStats`)**:
  - **CPU %**: Computed from `/proc/stat` delta `(dTotal - dIdle) / dTotal * 100`.
  - **RAM**: Computed from `/proc/meminfo` `(MemTotal - MemAvailable) / 1048576` GiB.
  - **GPU %**: Maximum value across `/sys/class/drm/card*/device/gpu_busy_percent`.
  - **Temperature**: Maximum millidegree sensor from `/sys/class/hwmon/hwmon*/temp1_input` divided by `1000`.
- **Per-Process GPU Usage (`TaskManager.parseProcessOutput`)**:
  - Combines NVIDIA compute memory (`nvidia-smi`) with Linux DRM `/proc/[0-9]*/fdinfo/*` (`drm-memory-vram`, `drm-memory-gtt`, and nanosecond engine counters `drm-engine-*`).
  - Engine utilization % is `((engNs_now - engNs_prev) / ((tsMs_now - tsMs_prev) * 1e6)) * 100`, deduplicated by `pid:drm-client-id`.
- **Per-Process Disk I/O (`TaskManager.parseProcessOutput`)**:
  - Reads `read_bytes + write_bytes` from `/proc/[0-9]*/io` and computes `diskBps = (bytes_now - bytes_prev) / deltaSeconds`.

## 3. Safety Specifications
- **Core Package Guard (`SafeOps.PROTECTED_CORE_PACKAGES`)**: Prevents uninstallation of critical boot/session packages (`base`, `linux`, `systemd`, `hyprland`, `quickshell`, `omarchy`, `sudo`, `pacman`, `glibc`, `bash`, `zsh`, `networkmanager`, `pipewire`, `wireplumber`).
- **Residual Path Validation (`SafeOps.validatePurgeTarget`)**: Requires absolute path inside `$HOME` with relative depth `>= 2`, non-symlink, and not matching `PROTECTED_USER_RELATIVES` (`.ssh`, `.gnupg`, `.config/hypr`, `.config/omarchy`, `.local/share/omapp`, etc.).
- **Safe Browser Cache Cleaning (`JanitorOps.buildCleanCommand("browser")`)**: Removes only transient `Cache`, `Code Cache`, and `GPUCache` directories; never touches `Cookies`, `Login Data`, or `Bookmarks`.
