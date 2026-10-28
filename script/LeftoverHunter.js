// LeftoverHunter.js — Deep scanner for residual files, orphaned dotfiles (#17), and file preview (#18)

function getSafe(safeParam) {
  if (safeParam && safeParam.validateLeftoverPath) return safeParam;
  if (typeof SafeOps !== "undefined" && SafeOps && SafeOps.validateLeftoverPath) return SafeOps;
  if (typeof globalThis !== "undefined" && globalThis.SafeOps) return globalThis.SafeOps;
  if (typeof require !== "undefined") {
    try { return require("./SafeOps.js"); } catch (e) {}
  }
  return {};
}

function generateCandidateSlugs(app) {
  if (!app || typeof app !== "object") return [];
  var rawList = [];

  if (app.pkg) rawList.push(app.pkg);
  if (app.exec) {
    var cleanExec = app.exec.split(/\s+/)[0].split("/").pop();
    if (cleanExec) rawList.push(cleanExec);
  }
  if (app.desktopFile) {
    rawList.push(app.desktopFile.replace(/\.desktop$/i, ""));
  }
  if (app.name) rawList.push(app.name);

  var slugs = {};
  for (var i = 0; i < rawList.length; i++) {
    var s = String(rawList[i]).trim();
    if (!s) continue;
    var stripped = s.replace(/(-bin|-git|-appimage|-nightly|-stable|-electron|\.desktop)$/i, "");
    var lower = stripped.toLowerCase();
    var noHyphen = lower.replace(/[-_]/g, "");

    if (lower.length >= 2) slugs[lower] = true;
    if (stripped.length >= 2) slugs[stripped] = true;
    if (noHyphen.length >= 2) slugs[noHyphen] = true;
  }

  return Object.keys(slugs);
}

function getCategoryForPath(path, home, safeHelper) {
  var safe = getSafe(safeHelper);
  var rel = safe.getRelativePath ? (safe.getRelativePath(path, home) || "") : "";
  if (rel.startsWith(".config/autostart")) return "autostart";
  if (rel.startsWith(".config/systemd")) return "service";
  if (rel.startsWith(".config/")) return "config";
  if (rel.startsWith(".local/share/")) return "data";
  if (rel.startsWith(".cache/")) return "cache";
  if (rel.startsWith(".local/state/")) return "state";
  if (rel.startsWith(".")) return "dotdir";
  return "other";
}

function buildScanScript(app, home, safeHelper) {
  var safe = getSafe(safeHelper);
  var slugs = generateCandidateSlugs(app);
  if (slugs.length === 0) return null;

  var escapedHome = safe.shellEscape ? safe.shellEscape(safe.normalizePath(home)) : ("'" + home + "'");
  var escapedSlugs = slugs.map(function(s) {
    return safe.shellEscape ? safe.shellEscape(s) : ("'" + s + "'");
  }).join(" ");

  var script = [
    'home=' + escapedHome,
    'slugs=(' + escapedSlugs + ')',
    'declare -A seen=()',
    'for slug in "${slugs[@]}"; do',
    '  for base in "$home/.config" "$home/.local/share" "$home/.cache" "$home/.local/state" "$home/.$slug"; do',
    '    target="$base"',
    '    if [ "$base" != "$home/.$slug" ]; then target="$base/$slug"; fi',
    '    if [ -e "$target" ] && [ -z "${seen[$target]}" ]; then',
    '      seen["$target"]=1',
    '      sz=$(du -sb "$target" 2>/dev/null | cut -f1)',
    '      echo -e "$target\\t$sz"',
    '    fi',
    '  done',
    '  for auto in "$home/.config/autostart/$slug"*.desktop; do',
    '    if [ -e "$auto" ] && [ -z "${seen[$auto]}" ]; then',
    '      seen["$auto"]=1',
    '      sz=$(du -sb "$auto" 2>/dev/null | cut -f1)',
    '      echo -e "$auto\\t$sz"',
    '    fi',
    '  done',
    'done'
  ].join("\n");

  return {
    argv: ["bash", "-c", script],
    slugs: slugs
  };
}

function parseScanOutput(stdoutText, home, safeHelper) {
  var safe = getSafe(safeHelper);
  if (!stdoutText || typeof stdoutText !== "string") return [];
  var lines = stdoutText.split("\n");
  var items = [];
  var seen = {};

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (!line) continue;
    var parts = line.split("\t");
    var p = parts[0];
    var size = parseInt(parts[1], 10) || 0;

    var check = safe.validateLeftoverPath ? safe.validateLeftoverPath(p, home) : { valid: true, normalized: p, relative: p };
    if (check.valid && !seen[check.normalized]) {
      seen[check.normalized] = true;
      var cat = getCategoryForPath(check.normalized, home, safe);
      var sizeFmt = safe.formatBytes ? safe.formatBytes(size) : (size + " B");
      items.push({
        path: check.normalized,
        relative: check.relative,
        size: size,
        sizeFormatted: sizeFmt,
        category: cat,
        selected: true
      });
    }
  }

  return items;
}

// #18 Quick file/directory preview before purging
function buildPreviewCommand(targetPath, home, safeHelper) {
  var safe = getSafe(safeHelper);
  var check = safe.validateLeftoverPath ? safe.validateLeftoverPath(targetPath, home) : { valid: false };
  if (!check.valid) return null;
  var esc = safe.shellEscape ? safe.shellEscape(check.normalized) : ("'" + check.normalized + "'");
  var script = 'p=' + esc + '; if [ -d "$p" ]; then ls -la "$p" 2>/dev/null | head -n 30; elif [ -f "$p" ]; then head -n 30 "$p" 2>/dev/null; fi';
  return ["bash", "-c", script];
}

// #17 Orphaned user dotfiles scanner (folders in ~/.cache & ~/.config with no matching installed package)
function buildOrphanDotfilesScanScript(home, safeHelper) {
  var safe = getSafe(safeHelper);
  var escapedHome = safe.shellEscape ? safe.shellEscape(safe.normalizePath(home)) : ("'" + home + "'");
  var script = [
    'home=' + escapedHome,
    'declare -A pkgset=()',
    'for p in $(pacman -Qq 2>/dev/null | tr "[:upper:]" "[:lower:]" | sed "s/-bin$//;s/-git$//"); do',
    '  pkgset["$p"]=1',
    '  pkgset["${p//[-_]/}"]=1',
    'done',
    'for sys in mesa_shader_cache mesa_shader_cache_db fontconfig yay paru pip go-build bravesoftware chromium mozilla nvidia qtshadercache qtshadercache-x86_64-little_endian-lp64 gstreamer-1.0 ibusibus-table trash thumbnails waldseelen.omapp omapp omarchy hypr quickshell dconf gtk-3.0 gtk-4.0 pulse systemd xsettingsd mimeapps.list; do',
    '  pkgset["$sys"]=1',
    'done',
    'for d in "$home/.cache"/* "$home/.config"/*; do',
    '  [ -d "$d" ] || continue',
    '  [ -L "$d" ] && continue',
    '  bn=$(basename "$d" | tr "[:upper:]" "[:lower:]")',
    '  bn_clean="${bn//[-_]/}"',
    '  if [ -z "${pkgset[$bn]}" ] && [ -z "${pkgset[$bn_clean]}" ]; then',
    '    sz=$(du -sb "$d" 2>/dev/null | cut -f1)',
    '    if [ "${sz:-0}" -gt 4096 ]; then',
    '      echo -e "$d\\t$sz"',
    '    fi',
    '  fi',
    'done'
  ].join("\n");
  return ["bash", "-c", script];
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    generateCandidateSlugs: generateCandidateSlugs,
    getCategoryForPath: getCategoryForPath,
    buildScanScript: buildScanScript,
    parseScanOutput: parseScanOutput,
    buildPreviewCommand: buildPreviewCommand,
    buildOrphanDotfilesScanScript: buildOrphanDotfilesScanScript
  };
}
