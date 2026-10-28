// Scanner.js — Unified inventory scanner for Arch, AUR, Desktop, WebApps, Flatpak (#12), AppImage (#12), User Data (#11), Unused (#15), and Package Deep Inspect (#14, #19)

function getSafe(safeParam) {
  if (safeParam && safeParam.parsePacmanSize) return safeParam;
  if (typeof SafeOps !== "undefined" && SafeOps && SafeOps.parsePacmanSize) return SafeOps;
  if (typeof globalThis !== "undefined" && globalThis.SafeOps) return globalThis.SafeOps;
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
    'if [ -n "$pkgs" ]; then LANG=C pacman -Qi $pkgs 2>/dev/null; fi',
    'echo "===PACMAN_END==="',
    'echo "===USERDATA_START==="',
    'du -sk "$HOME/.config"/* "$HOME/.cache"/* "$HOME/.local/share"/* 2>/dev/null || true',
    'echo "===USERDATA_END==="',
    'echo "===FLATPAK_START==="',
    'if command -v flatpak >/dev/null 2>&1; then flatpak list --app --columns=application,name,version,size 2>/dev/null || true; fi',
    'echo "===FLATPAK_END==="',
    'echo "===APPIMAGE_START==="',
    'for ai in "$HOME/Applications"/*.AppImage "$HOME/.local/bin"/*.AppImage "$HOME/Downloads"/*.AppImage; do',
    '  [ -f "$ai" ] || continue',
    '  sz=$(stat -c "%s" "$ai" 2>/dev/null || echo 0)',
    '  mt=$(stat -c "%Y" "$ai" 2>/dev/null || echo 0)',
    '  echo -e "$ai\\t$sz\\t$mt"',
    'done',
    'echo "===APPIMAGE_END==="'
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
      if (current && current.Name) pkgs[current.Name] = current;
      current = null;
      continue;
    }
    var colonIdx = line.indexOf(":");
    if (colonIdx > 0 && line.slice(0, colonIdx).trim().length > 0 && line.charAt(0) !== " ") {
      var key = line.slice(0, colonIdx).trim();
      var val = line.slice(colonIdx + 1).trim();
      if (!current) current = {};
      current[key] = val;
    }
  }
  if (current && current.Name) pkgs[current.Name] = current;
  return pkgs;
}

function sliceSection(raw, startTag, endTag) {
  var s = raw.indexOf(startTag);
  var e = raw.indexOf(endTag);
  if (s === -1 || e === -1 || e <= s) return "";
  return raw.slice(s + startTag.length, e).trim();
}

function parseUserDataMap(blockText) {
  var map = {};
  if (!blockText) return map;
  var lines = blockText.split("\n");
  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].trim().split(/\t|\s+/);
    if (parts.length < 2) continue;
    var kib = parseInt(parts[0], 10) || 0;
    var fullPath = parts.slice(1).join(" ");
    var base = fullPath.split("/").pop().toLowerCase().replace(/[-_]/g, "");
    if (base && kib > 0) {
      map[base] = (map[base] || 0) + (kib * 1024);
    }
  }
  return map;
}

function lookupUserDataBytes(userDataMap, pkg, name) {
  var keys = [];
  if (pkg) {
    var cleanPkg = pkg.toLowerCase().replace(/(-bin|-git|-appimage)$/i, "").replace(/[-_]/g, "");
    if (cleanPkg) keys.push(cleanPkg);
  }
  if (name) {
    var cleanName = name.toLowerCase().replace(/\s+/g, "").replace(/[-_]/g, "");
    if (cleanName && keys.indexOf(cleanName) === -1) keys.push(cleanName);
  }
  var total = 0;
  for (var i = 0; i < keys.length; i++) {
    if (userDataMap[keys[i]]) total += userDataMap[keys[i]];
  }
  return total;
}

function parseInventory(rawOutput, safeHelper) {
  var safe = getSafe(safeHelper);
  if (!rawOutput || typeof rawOutput !== "string") return [];

  var fmt = function(b) { return safe.formatBytes ? safe.formatBytes(b) : (b + " B"); };
  var isProt = function(p) { return safe.isProtectedCorePackage ? safe.isProtectedCorePackage(p) : false; };

  var aurSet = {};
  var aurText = sliceSection(rawOutput, "===AUR_START===", "===AUR_END===");
  if (aurText) {
    var aurLines = aurText.split("\n");
    for (var a = 0; a < aurLines.length; a++) {
      var pName = aurLines[a].trim();
      if (pName) aurSet[pName] = true;
    }
  }

  var pacText = sliceSection(rawOutput, "===PACMAN_START===", "===PACMAN_END===");
  var pacmanDict = pacText ? parsePacmanBlock(pacText) : parsePacmanBlock(rawOutput);
  var userDataMap = parseUserDataMap(sliceSection(rawOutput, "===USERDATA_START===", "===USERDATA_END==="));

  var desktopItems = [];
  var deskText = sliceSection(rawOutput, "===DESKTOP_START===", "===DESKTOP_END===");
  if (deskText) {
    var deskLines = deskText.split("\n");
    for (var d = 0; d < deskLines.length; d++) {
      var line = deskLines[d].trim();
      if (!line) continue;
      var parts = line.split("\t");
      var filePath = parts[0] || "";
      desktopItems.push({
        filePath: filePath,
        fileName: filePath.split("/").pop(),
        name: parts[1] || "",
        icon: parts[2] || "application-x-executable",
        exec: parts[3] || "",
        categories: parts[4] || "",
        comment: parts[5] || ""
      });
    }
  }

  var unified = [];
  var claimedPkgs = {};
  var thirtyDaysMs = 30 * 24 * 3600 * 1000;
  var nowMs = Date.now();

  for (var i = 0; i < desktopItems.length; i++) {
    var dt = desktopItems[i];
    var binName = dt.exec.split(/\s+/)[0].split("/").pop();
    var isLocal = dt.filePath.indexOf(".local/share/applications") !== -1;
    var isWebApp = isLocal && (dt.exec.indexOf("--app=") !== -1 || dt.categories.indexOf("WebApp") !== -1);

    var matchedPkg = null;
    var stem = dt.fileName.replace(/\.desktop$/i, "");
    var slug = dt.name.toLowerCase().replace(/\s+/g, "-");
    var compact = dt.name.toLowerCase().replace(/\s+/g, "");
    var candidates = [
      binName, binName + "-bin", binName + "-git",
      stem, stem + "-bin", stem + "-git",
      slug, slug + "-bin", slug + "-git",
      compact, compact + "-bin"
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
    var uBytes = lookupUserDataBytes(userDataMap, pkgName, dt.name);
    var instDate = matchedPkg ? matchedPkg["Install Date"] || "" : "";
    var instMs = instDate ? (new Date(instDate).getTime() || 0) : 0;
    var isUnused = (instMs > 0 && (nowMs - instMs) > thirtyDaysMs && uBytes === 0);

    unified.push({
      id: "desk_" + (matchedPkg ? matchedPkg.Name : dt.fileName),
      name: dt.name,
      pkg: pkgName,
      version: matchedPkg ? matchedPkg.Version : "1.0",
      description: (matchedPkg && matchedPkg.Description) || dt.comment || "Application",
      icon: dt.icon,
      exec: dt.exec,
      size: sizeBytes,
      sizeFormatted: fmt(sizeBytes),
      userDataBytes: uBytes,
      userDataFormatted: fmt(uBytes),
      totalFootprintBytes: sizeBytes + uBytes,
      installDate: instDate,
      buildDate: matchedPkg ? matchedPkg["Build Date"] || "" : "",
      packager: matchedPkg ? matchedPkg.Packager || "" : "Local",
      url: matchedPkg ? matchedPkg.URL || "" : "",
      licenses: matchedPkg ? matchedPkg.Licenses || "" : "",
      dependsOn: matchedPkg ? matchedPkg["Depends On"] || "None" : "",
      requiredBy: matchedPkg ? matchedPkg["Required By"] || "None" : "None",
      category: isWebApp ? "webapp" : "desktop",
      isAur: !!aurSet[pkgName],
      isDesktop: true,
      isWebApp: isWebApp,
      isProtected: isProt(pkgName),
      isUnused: isUnused,
      desktopFile: dt.fileName
    });
  }

  var pacmanKeys = Object.keys(pacmanDict);
  for (var k = 0; k < pacmanKeys.length; k++) {
    var p = pacmanKeys[k];
    if (claimedPkgs[p]) continue;
    var info = pacmanDict[p];
    var pSize = safe.parsePacmanSize ? safe.parsePacmanSize(info["Installed Size"]) : 0;
    var pUBytes = lookupUserDataBytes(userDataMap, p, p);
    var pIsAur = !!aurSet[p];
    var pInst = info["Install Date"] || "";
    var pInstMs = pInst ? (new Date(pInst).getTime() || 0) : 0;

    unified.push({
      id: "pkg_" + p,
      name: p,
      pkg: p,
      version: info.Version || "",
      description: info.Description || "",
      icon: "utilities-terminal",
      exec: p,
      size: pSize,
      sizeFormatted: fmt(pSize),
      userDataBytes: pUBytes,
      userDataFormatted: fmt(pUBytes),
      totalFootprintBytes: pSize + pUBytes,
      installDate: pInst,
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
      isProtected: isProt(p),
      isUnused: (pInstMs > 0 && (nowMs - pInstMs) > thirtyDaysMs && pUBytes === 0 && info["Required By"] === "None"),
      desktopFile: ""
    });
  }

  // Flatpak apps (#12)
  var fpText = sliceSection(rawOutput, "===FLATPAK_START===", "===FLATPAK_END===");
  if (fpText) {
    var fpLines = fpText.split("\n");
    for (var f = 0; f < fpLines.length; f++) {
      var fpParts = fpLines[f].trim().split("\t");
      if (fpParts.length >= 2 && fpParts[0]) {
        var fpId = fpParts[0].trim();
        var fpName = (fpParts[1] || fpId).trim();
        var fpVer = (fpParts[2] || "latest").trim();
        var fpSz = safe.parsePacmanSize ? safe.parsePacmanSize(fpParts[3] || "0 B") : 0;
        unified.push({
          id: "fp_" + fpId, name: fpName, pkg: fpId, version: fpVer,
          description: "Flatpak sandboxed application", icon: fpId, exec: "flatpak run " + fpId,
          size: fpSz, sizeFormatted: fmt(fpSz), userDataBytes: 0, userDataFormatted: "0 B",
          totalFootprintBytes: fpSz, installDate: "", buildDate: "", packager: "Flathub",
          url: "", licenses: "", dependsOn: "Flatpak Runtime", requiredBy: "None",
          category: "flatpak", isAur: false, isDesktop: true, isWebApp: false,
          isProtected: false, isUnused: false, desktopFile: ""
        });
      }
    }
  }

  // AppImage binaries (#12)
  var aiText = sliceSection(rawOutput, "===APPIMAGE_START===", "===APPIMAGE_END===");
  if (aiText) {
    var aiLines = aiText.split("\n");
    for (var m = 0; m < aiLines.length; m++) {
      var aiParts = aiLines[m].trim().split("\t");
      if (aiParts.length >= 2 && aiParts[0]) {
        var aiPath = aiParts[0].trim();
        var aiSize = parseInt(aiParts[1], 10) || 0;
        var aiBase = aiPath.split("/").pop().replace(/\.AppImage$/i, "");
        unified.push({
          id: "ai_" + aiBase, name: aiBase, pkg: aiPath, version: "AppImage",
          description: "Portable AppImage binary (" + aiPath + ")", icon: "application-x-executable",
          exec: aiPath, size: aiSize, sizeFormatted: fmt(aiSize), userDataBytes: 0,
          userDataFormatted: "0 B", totalFootprintBytes: aiSize, installDate: "", buildDate: "",
          packager: "Portable", url: "", licenses: "", dependsOn: "None", requiredBy: "None",
          category: "appimage", isAur: false, isDesktop: true, isWebApp: false,
          isProtected: false, isUnused: false, desktopFile: ""
        });
      }
    }
  }

  return unified;
}

function buildPackageDeepInspectScript(pkgName) {
  if (!pkgName || !/^[a-zA-Z0-9@._+-]+$/.test(pkgName)) return null;
  var script = [
    'pkg="' + pkgName + '"',
    'echo "===FILES_START==="',
    'pacman -Qlq "$pkg" 2>/dev/null | head -n 60 || true',
    'echo "===FILES_END==="',
    'echo "===CACHE_START==="',
    'ls -1t /var/cache/pacman/pkg/"$pkg"-[0-9]*.pkg.tar.* 2>/dev/null | head -n 10 || true',
    'echo "===CACHE_END==="',
    'echo "===TREE_START==="',
    'if command -v pactree >/dev/null 2>&1; then pactree -d 2 "$pkg" 2>/dev/null | head -n 40; else pacman -Qi "$pkg" 2>/dev/null | grep -E "^(Depends On|Required By)"; fi',
    'echo "===TREE_END==="'
  ].join("\n");
  return ["bash", "-c", script];
}

function parsePackageDeepInspect(rawText) {
  if (!rawText || typeof rawText !== "string") {
    return { files: [], cachedVersions: [], tree: "" };
  }
  var filesBlock = sliceSection(rawText, "===FILES_START===", "===FILES_END===");
  var cacheBlock = sliceSection(rawText, "===CACHE_START===", "===CACHE_END===");
  var treeBlock = sliceSection(rawText, "===TREE_START===", "===TREE_END===");

  var files = filesBlock ? filesBlock.split("\n").map(function(s) { return s.trim(); }).filter(Boolean) : [];
  var cached = cacheBlock ? cacheBlock.split("\n").map(function(s) { return s.trim(); }).filter(Boolean) : [];
  return {
    files: files,
    cachedVersions: cached,
    tree: treeBlock || "No dependency tree available"
  };
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    buildInventoryScanScript: buildInventoryScanScript,
    parsePacmanBlock: parsePacmanBlock,
    parseInventory: parseInventory,
    buildPackageDeepInspectScript: buildPackageDeepInspectScript,
    parsePackageDeepInspect: parsePackageDeepInspect
  };
}
