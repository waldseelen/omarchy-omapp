// Scanner.js — Unified inventory scanner for Arch packages, AUR, Desktop applications, and Web Apps

function getSafe(safeParam) {
  if (safeParam && safeParam.parsePacmanSize) return safeParam;
  if (typeof SafeOps !== "undefined" && SafeOps && SafeOps.parsePacmanSize) {
    return SafeOps;
  }
  if (typeof globalThis !== "undefined" && globalThis.SafeOps) {
    return globalThis.SafeOps;
  }
  if (typeof require !== "undefined") {
    try { return require("./SafeOps.js"); } catch (e) {}
  }
  return {};
}

function buildInventoryScanScript() {
  var script = [
    'echo "===AUR_START==="',
    'pacman -Qmq 2>/dev/null',
    'echo "===AUR_END==="',
    'echo "===DESKTOP_START==="',
    'for f in /usr/share/applications/*.desktop "$HOME/.local/share/applications/"*.desktop; do',
    '  [ -f "$f" ] || continue',
    '  name=$(grep -m1 "^Name=" "$f" | cut -d= -f2-)',
    '  icon=$(grep -m1 "^Icon=" "$f" | cut -d= -f2-)',
    '  exec_cmd=$(grep -m1 "^Exec=" "$f" | cut -d= -f2-)',
    '  nodisplay=$(grep -m1 "^NoDisplay=" "$f" | cut -d= -f2-)',
    '  cats=$(grep -m1 "^Categories=" "$f" | cut -d= -f2-)',
    '  desc=$(grep -m1 "^Comment=" "$f" | cut -d= -f2-)',
    '  [ "$nodisplay" = "true" ] && continue',
    '  [ -n "$name" ] && echo -e "$f\\t$name\\t$icon\\t$exec_cmd\\t$cats\\t$desc"',
    'done',
    'echo "===DESKTOP_END==="',
    'echo "===PACMAN_START==="',
    'pkgs=$(pacman -Qeq 2>/dev/null)',
    'if [ -n "$pkgs" ]; then',
    '  pacman -Qi $pkgs 2>/dev/null',
    'fi',
    'echo "===PACMAN_END==="'
  ].join("\n");

  return ["bash", "-c", script];
}

function parsePacmanBlock(blockText) {
  var pkgs = {};
  var current = null;
  var lines = blockText.split("\n");

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (!line.trim()) {
      if (current && current.Name) {
        pkgs[current.Name] = current;
      }
      current = null;
      continue;
    }

    var colonIdx = line.indexOf(":");
    if (colonIdx > 0 && line.slice(0, colonIdx).trim().length > 0) {
      var key = line.slice(0, colonIdx).trim();
      var val = line.slice(colonIdx + 1).trim();
      if (!current) current = {};
      current[key] = val;
    }
  }
  if (current && current.Name) {
    pkgs[current.Name] = current;
  }

  return pkgs;
}

function parseInventory(rawOutput, safeHelper) {
  var safe = getSafe(safeHelper);
  if (!rawOutput || typeof rawOutput !== "string") return [];

  var aurStart = rawOutput.indexOf("===AUR_START===");
  var aurEnd = rawOutput.indexOf("===AUR_END===");
  var deskStart = rawOutput.indexOf("===DESKTOP_START===");
  var deskEnd = rawOutput.indexOf("===DESKTOP_END===");
  var pacStart = rawOutput.indexOf("===PACMAN_START===");
  var pacEnd = rawOutput.indexOf("===PACMAN_END===");

  // 1. Parse AUR set
  var aurSet = {};
  if (aurStart !== -1 && aurEnd !== -1) {
    var aurText = rawOutput.slice(aurStart + 16, aurEnd);
    var aurLines = aurText.split("\n");
    for (var a = 0; a < aurLines.length; a++) {
      var pName = aurLines[a].trim();
      if (pName) aurSet[pName] = true;
    }
  }

  // 2. Parse Pacman packages
  var pacmanDict = {};
  if (pacStart !== -1 && pacEnd !== -1) {
    var pacText = rawOutput.slice(pacStart + 19, pacEnd);
    pacmanDict = parsePacmanBlock(pacText);
  }

  // 3. Parse Desktop applications
  var desktopItems = [];
  if (deskStart !== -1 && deskEnd !== -1) {
    var deskText = rawOutput.slice(deskStart + 20, deskEnd);
    var deskLines = deskText.split("\n");
    for (var d = 0; d < deskLines.length; d++) {
      var line = deskLines[d].trim();
      if (!line) continue;
      var parts = line.split("\t");
      var filePath = parts[0] || "";
      var fileName = filePath.split("/").pop();
      var name = parts[1] || "";
      var icon = parts[2] || "application-x-executable";
      var exec = parts[3] || "";
      var categories = parts[4] || "";
      var comment = parts[5] || "";

      desktopItems.push({
        filePath: filePath,
        fileName: fileName,
        name: name,
        icon: icon,
        exec: exec,
        categories: categories,
        comment: comment
      });
    }
  }

  // 4. Merge and build unified items
  var unified = [];
  var claimedPkgs = {};

  // First, pass through Desktop entries
  for (var i = 0; i < desktopItems.length; i++) {
    var dt = desktopItems[i];
    var binName = dt.exec.split(/\s+/)[0].split("/").pop();
    var isLocal = dt.filePath.indexOf(".local/share/applications") !== -1;
    var isWebApp = isLocal && (dt.exec.indexOf("--app=") !== -1 || dt.categories.indexOf("WebApp") !== -1);

    // Match pacman package by exact binary, filename without .desktop, or lowercase name
    var matchedPkg = null;
    var candidates = [
      binName,
      dt.fileName.replace(/\.desktop$/i, ""),
      dt.name.toLowerCase().replace(/\s+/g, "-"),
      dt.name.toLowerCase().replace(/\s+/g, "")
    ];

    for (var c = 0; c < candidates.length; c++) {
      var cand = candidates[c];
      if (cand && pacmanDict[cand]) {
        matchedPkg = pacmanDict[cand];
        claimedPkgs[cand] = true;
        break;
      }
    }

    var pkgName = matchedPkg ? matchedPkg.Name : (isWebApp ? dt.name : binName);
    var sizeBytes = matchedPkg ? (safe.parsePacmanSize ? safe.parsePacmanSize(matchedPkg["Installed Size"]) : 0) : 0;
    var isAur = !!aurSet[pkgName];
    var category = isWebApp ? "webapp" : "desktop";

    unified.push({
      id: "desk_" + (matchedPkg ? matchedPkg.Name : dt.fileName),
      name: dt.name,
      pkg: pkgName,
      version: matchedPkg ? matchedPkg.Version : "1.0",
      description: (matchedPkg && matchedPkg.Description) || dt.comment || "Application",
      icon: dt.icon,
      exec: dt.exec,
      size: sizeBytes,
      sizeFormatted: safe.formatBytes ? safe.formatBytes(sizeBytes) : (sizeBytes + " B"),
      installDate: matchedPkg ? matchedPkg["Install Date"] || "" : "",
      buildDate: matchedPkg ? matchedPkg["Build Date"] || "" : "",
      packager: matchedPkg ? matchedPkg.Packager || "" : "Local",
      url: matchedPkg ? matchedPkg.URL || "" : "",
      licenses: matchedPkg ? matchedPkg.Licenses || "" : "",
      dependsOn: matchedPkg ? matchedPkg["Depends On"] || "None" : "",
      requiredBy: matchedPkg ? matchedPkg["Required By"] || "None" : "None",
      category: category,
      isAur: isAur,
      isDesktop: true,
      isWebApp: isWebApp,
      desktopFile: dt.fileName
    });
  }

  // Second, add remaining explicitly installed packages (CLI tools, system packages)
  var pacmanKeys = Object.keys(pacmanDict);
  for (var k = 0; k < pacmanKeys.length; k++) {
    var p = pacmanKeys[k];
    if (claimedPkgs[p]) continue;

    var info = pacmanDict[p];
    var pSize = safe.parsePacmanSize ? safe.parsePacmanSize(info["Installed Size"]) : 0;
    var pIsAur = !!aurSet[p];

    unified.push({
      id: "pkg_" + p,
      name: p,
      pkg: p,
      version: info.Version || "",
      description: info.Description || "",
      icon: "utilities-terminal",
      exec: p,
      size: pSize,
      sizeFormatted: safe.formatBytes ? safe.formatBytes(pSize) : (pSize + " B"),
      installDate: info["Install Date"] || "",
      buildDate: info["Build Date"] || "",
      packager: info.Packager || "",
      url: info.URL || "",
      licenses: info.Licenses || "",
      dependsOn: info["Depends On"] || "None",
      requiredBy: info["Required By"] || "None",
      category: pIsAur ? "aur" : "system",
      isAur: pIsAur,
      isDesktop: false,
      isWebApp: false,
      desktopFile: ""
    });
  }

  return unified;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    buildInventoryScanScript: buildInventoryScanScript,
    parsePacmanBlock: parsePacmanBlock,
    parseInventory: parseInventory
  };
}
