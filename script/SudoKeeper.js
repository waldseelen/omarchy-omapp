// SudoKeeper.js — Session-long sudo authentication, batch uninstall (#13), and downgrade (#14)

var CORE_PROTECTED = {
  "base": true, "linux": true, "linux-omarchy": true, "linux-lts": true,
  "linux-zen": true, "linux-firmware": true, "systemd": true, "glibc": true,
  "gcc-libs": true, "bash": true, "coreutils": true, "sudo": true,
  "pacman": true, "hyprland": true, "quickshell": true, "quickshell-git": true,
  "omarchy": true, "uwsm": true, "wayland": true, "pipewire": true
};

function isSafePkgName(name) {
  if (!name || typeof name !== "string") return false;
  var clean = name.trim();
  if (CORE_PROTECTED[clean.toLowerCase()]) return false;
  return /^[a-zA-Z0-9@._+-]+$/.test(clean);
}

function getStatusCheckCommand() {
  return ["sudo", "-n", "true"];
}

function getAuthCommand() {
  return ["sudo", "-S", "-v"];
}

function getKeepaliveScript(parentPid) {
  var pid = parseInt(parentPid, 10);
  if (isNaN(pid) || pid <= 0) {
    return "while true; do sudo -n -v 2>/dev/null || exit 0; sleep 50; done";
  }
  return "while kill -0 " + pid + " 2>/dev/null; do sudo -n -v 2>/dev/null || exit 0; sleep 50; done";
}

function buildUninstallCommand(packageName, category) {
  if (!packageName || typeof packageName !== "string") return null;
  var safeName = packageName.trim();
  if (category === "flatpak") {
    if (!/^[a-zA-Z0-9._-]+$/.test(safeName)) return null;
    return ["flatpak", "uninstall", "-y", safeName];
  }
  if (!isSafePkgName(safeName)) return null;
  return ["sudo", "-n", "pacman", "-Rns", "--noconfirm", safeName];
}

function buildBatchUninstallCommand(pkgList) {
  if (!pkgList || !Array.isArray(pkgList) || pkgList.length === 0) return null;
  var valid = [];
  for (var i = 0; i < pkgList.length; i++) {
    var name = String(pkgList[i] || "").trim();
    if (isSafePkgName(name) && valid.indexOf(name) === -1) {
      valid.push(name);
    }
  }
  if (valid.length === 0) return null;
  return ["sudo", "-n", "pacman", "-Rns", "--noconfirm"].concat(valid);
}

function buildDowngradeCommand(archivePath) {
  if (!archivePath || typeof archivePath !== "string") return null;
  var clean = archivePath.trim();
  if (!clean.startsWith("/var/cache/pacman/pkg/") || clean.indexOf("..") !== -1 || !/\.pkg\.tar\.(zst|xz|gz)$/.test(clean)) {
    return null;
  }
  return ["sudo", "-n", "pacman", "-U", "--noconfirm", clean];
}

function buildOrphanCleanCommand() {
  return [
    "bash", "-c",
    'orphans=$(pacman -Qtdq 2>/dev/null); if [ -n "$orphans" ]; then (sudo -n pacman -Rns --noconfirm $orphans 2>&1 || pacman -Rns --noconfirm $orphans 2>&1) && echo "CLEAN_OK:Pruned orphan packages"; else echo "CLEAN_OK:No orphan packages to prune"; fi'
  ];
}

function buildOrphanPruneCommand() {
  return buildOrphanCleanCommand();
}

function buildCacheCleanCommand() {
  return [
    "bash", "-c",
    'if command -v paccache >/dev/null 2>&1; then (sudo -n paccache -rk1 2>&1 && sudo -n paccache -ruk0 2>&1) && echo "CLEAN_OK:Trimmed pacman cache (kept latest version)"; else (sudo -n pacman -Sc --noconfirm 2>&1) && echo "CLEAN_OK:Cleaned pacman cache"; fi'
  ];
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    getStatusCheckCommand: getStatusCheckCommand,
    getAuthCommand: getAuthCommand,
    getKeepaliveScript: getKeepaliveScript,
    buildUninstallCommand: buildUninstallCommand,
    buildBatchUninstallCommand: buildBatchUninstallCommand,
    buildDowngradeCommand: buildDowngradeCommand,
    buildOrphanCleanCommand: buildOrphanCleanCommand,
    buildOrphanPruneCommand: buildOrphanPruneCommand,
    buildCacheCleanCommand: buildCacheCleanCommand
  };
}
