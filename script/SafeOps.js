// SafeOps.js — Path validation, core package lock (#20), and backup/restore (#16) barriers

var BLACKLIST_EXACT = [
  "/", "/etc", "/usr", "/var", "/home", "/root", "/bin", "/sbin",
  "/lib", "/boot", "/dev", "/sys", "/proc", "/tmp", "/run"
];

var BLACKLIST_USER_REL = [
  "", ".", "..", ".config", ".local", ".local/share", ".cache",
  ".local/state", ".ssh", ".gnupg", ".bashrc", ".bash_profile",
  ".zshrc", ".profile", ".gitconfig", ".config/hypr",
  ".config/omarchy", ".config/ghostty", ".config/foot",
  ".config/kitty", ".config/alacritty"
];

var PROTECTED_CORE_PACKAGES = [
  "base", "linux", "linux-omarchy", "linux-lts", "linux-zen", "linux-firmware",
  "systemd", "systemd-libs", "glibc", "gcc-libs", "bash", "coreutils",
  "sudo", "pacman", "hyprland", "quickshell", "quickshell-git", "omarchy",
  "uwsm", "wayland", "pipewire", "wireplumber", "dbus", "networkmanager"
];

function isProtectedCorePackage(pkgName) {
  if (!pkgName || typeof pkgName !== "string") return false;
  var clean = pkgName.trim().toLowerCase();
  for (var i = 0; i < PROTECTED_CORE_PACKAGES.length; i++) {
    if (clean === PROTECTED_CORE_PACKAGES[i]) return true;
  }
  return false;
}

function normalizePath(p) {
  if (!p || typeof p !== "string") return "";
  var clean = p.replace(/\/+/g, "/");
  if (clean.length > 1 && clean.endsWith("/")) {
    clean = clean.slice(0, -1);
  }
  return clean;
}

function getRelativePath(absPath, home) {
  var normHome = normalizePath(home);
  var normPath = normalizePath(absPath);
  if (!normHome || !normPath) return null;
  if (normPath === normHome) return "";
  if (normPath.startsWith(normHome + "/")) {
    return normPath.slice(normHome.length + 1);
  }
  return null;
}

function validateLeftoverPath(path, home) {
  if (!path || typeof path !== "string") {
    return { valid: false, reason: "Empty or invalid path" };
  }
  if (path.indexOf("\0") !== -1) {
    return { valid: false, reason: "NUL byte rejected" };
  }
  var norm = normalizePath(path);

  if (norm.indexOf("..") !== -1) {
    return { valid: false, reason: "Directory traversal detected (..)" };
  }

  for (var i = 0; i < BLACKLIST_EXACT.length; i++) {
    if (norm === BLACKLIST_EXACT[i]) {
      return { valid: false, reason: "Protected system path: " + norm };
    }
  }

  var rel = getRelativePath(norm, home);
  if (rel === null) {
    return { valid: false, reason: "Path is outside user home directory" };
  }

  for (var j = 0; j < BLACKLIST_USER_REL.length; j++) {
    if (rel === BLACKLIST_USER_REL[j]) {
      return { valid: false, reason: "Protected user config/directory: " + rel };
    }
  }

  var segments = rel.split("/").filter(function(s) { return s.length > 0; });
  if (segments.length < 2) {
    if (segments.length === 1 && segments[0].startsWith(".") && segments[0].length > 2) {
      // Allowed top-level dotdir (e.g. .mozilla)
    } else {
      return { valid: false, reason: "Path depth too shallow: " + rel };
    }
  }

  return { valid: true, normalized: norm, relative: rel };
}

function shellEscape(arg) {
  if (arg === null || arg === undefined) return "''";
  return "'" + String(arg).replace(/'/g, "'\\''") + "'";
}

function formatBytes(bytes) {
  if (isNaN(bytes) || bytes === null || bytes === undefined || bytes < 0) return "0 B";
  if (bytes === 0) return "0 B";
  var units = ["B", "KiB", "MiB", "GiB", "TiB"];
  var i = Math.floor(Math.log(bytes) / Math.log(1024));
  if (i < 0) i = 0;
  if (i >= units.length) i = units.length - 1;
  var val = bytes / Math.pow(1024, i);
  return (i === 0 ? val.toString() : val.toFixed(1)) + " " + units[i];
}

function parsePacmanSize(sizeStr) {
  if (!sizeStr || typeof sizeStr !== "string") return 0;
  var trimmed = sizeStr.trim();
  var match = trimmed.match(/^([\d.]+)\s*([KMGTP]?i?B)$/i);
  if (!match) return 0;
  var num = parseFloat(match[1]);
  var unit = match[2].toUpperCase();
  var multiplier = 1;
  if (unit === "B") multiplier = 1;
  else if (unit === "KIB" || unit === "KB") multiplier = 1024;
  else if (unit === "MIB" || unit === "MB") multiplier = 1024 * 1024;
  else if (unit === "GIB" || unit === "GB") multiplier = 1024 * 1024 * 1024;
  else if (unit === "TIB" || unit === "TB") multiplier = 1024 * 1024 * 1024 * 1024;
  return Math.round(num * multiplier);
}

function buildBackupCommand(paths, appSlug, home) {
  var validPaths = [];
  for (var i = 0; i < paths.length; i++) {
    var check = validateLeftoverPath(paths[i], home);
    if (check.valid) {
      validPaths.push(check.normalized);
    }
  }
  if (validPaths.length === 0) return null;

  var backupDir = normalizePath(home) + "/.local/share/omapp/backups";
  var safeSlug = (appSlug || "app").replace(/[^a-zA-Z0-9_-]/g, "_");
  var timestamp = new Date().toISOString().replace(/[-:T.]/g, "").slice(0, 14);
  var targetTar = backupDir + "/" + safeSlug + "-" + timestamp + ".tar.gz";

  var escapedPaths = validPaths.map(shellEscape).join(" ");
  var cmd = "mkdir -p " + shellEscape(backupDir) + " && tar -czf " + shellEscape(targetTar) + " -P " + escapedPaths;
  return {
    command: cmd,
    backupFile: targetTar,
    validPaths: validPaths
  };
}

function buildPurgeCommand(paths, home) {
  var validPaths = [];
  for (var i = 0; i < paths.length; i++) {
    var check = validateLeftoverPath(paths[i], home);
    if (check.valid) {
      validPaths.push(check.normalized);
    }
  }
  if (validPaths.length === 0) return null;

  var escapedPaths = validPaths.map(shellEscape).join(" ");
  var cmd = "rm -rf -- " + escapedPaths;
  return {
    command: cmd,
    validPaths: validPaths
  };
}

function buildRestoreBackupCommand(backupFilePath, home) {
  if (!backupFilePath || typeof backupFilePath !== "string") return null;
  var normHome = normalizePath(home);
  var normBackup = normalizePath(backupFilePath);
  var expectedDir = normHome + "/.local/share/omapp/backups/";
  if (!normBackup.startsWith(expectedDir) || normBackup.indexOf("..") !== -1 || !normBackup.endsWith(".tar.gz")) {
    return null;
  }
  return ["tar", "-xzf", normBackup, "-P"];
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    BLACKLIST_EXACT: BLACKLIST_EXACT,
    BLACKLIST_USER_REL: BLACKLIST_USER_REL,
    PROTECTED_CORE_PACKAGES: PROTECTED_CORE_PACKAGES,
    isProtectedCorePackage: isProtectedCorePackage,
    normalizePath: normalizePath,
    getRelativePath: getRelativePath,
    validateLeftoverPath: validateLeftoverPath,
    shellEscape: shellEscape,
    formatBytes: formatBytes,
    parsePacmanSize: parsePacmanSize,
    buildBackupCommand: buildBackupCommand,
    buildPurgeCommand: buildPurgeCommand,
    buildRestoreBackupCommand: buildRestoreBackupCommand
  };
}
