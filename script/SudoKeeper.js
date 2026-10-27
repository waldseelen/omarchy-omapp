// SudoKeeper.js — Session-long sudo authentication and keepalive helper
// Protects credentials by streaming via stdin and avoiding cleartext argv exposure

(function(exports) {
  "use strict";

  function getStatusCheckCommand() {
    return ["sudo", "-n", "true"];
  }

  function getAuthCommand() {
    // Reads password strictly from stdin (-S)
    return ["sudo", "-S", "-v"];
  }

  function getKeepaliveScript(parentPid) {
    var pid = parseInt(parentPid, 10);
    if (isNaN(pid) || pid <= 0) {
      return "while true; do sudo -n -v 2>/dev/null || exit 0; sleep 50; done";
    }
    return "while kill -0 " + pid + " 2>/dev/null; do sudo -n -v 2>/dev/null || exit 0; sleep 50; done";
  }

  function buildUninstallCommand(packageName) {
    if (!packageName || typeof packageName !== "string") return null;
    var safeName = packageName.trim();
    if (!/^[a-zA-Z0-9@._+-]+$/.test(safeName)) return null;
    return ["sudo", "-n", "pacman", "-Rns", "--noconfirm", safeName];
  }

  function buildOrphanCleanCommand() {
    return [
      "bash", "-c",
      'orphans=$(pacman -Qtdq 2>/dev/null); if [ -n "$orphans" ]; then sudo -n pacman -Rns --noconfirm $orphans; else echo "NO_ORPHANS"; fi'
    ];
  }

  function buildCacheCleanCommand() {
    return [
      "bash", "-c",
      'if command -v paccache >/dev/null 2>&1; then sudo -n paccache -r; else echo "paccache not installed"; fi'
    ];
  }

  exports.getStatusCheckCommand = getStatusCheckCommand;
  exports.getAuthCommand = getAuthCommand;
  exports.getKeepaliveScript = getKeepaliveScript;
  exports.buildUninstallCommand = buildUninstallCommand;
  exports.buildOrphanCleanCommand = buildOrphanCleanCommand;
  exports.buildCacheCleanCommand = buildCacheCleanCommand;

})(typeof exports !== "undefined" ? exports : (this.SudoKeeper = {}));
