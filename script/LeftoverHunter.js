// LeftoverHunter.js — Deep scanner for residual files, configs, caches, and autostarts
// Discovers leftovers matching app identifiers and validates them against SafeOps barriers

(function(exports) {
  "use strict";

  var SafeOps = typeof require !== "undefined" ? require("./SafeOps.js") : (this.SafeOps || {});

  function generateCandidateSlugs(app) {
    if (!app || typeof app !== "object") return [];
    var rawList = [];

    if (app.pkg) rawList.push(app.pkg);
    if (app.exec) {
      // Remove flags like --no-sandbox or %u
      var cleanExec = app.exec.split(/\s+/)[0];
      cleanExec = cleanExec.split("/").pop();
      if (cleanExec) rawList.push(cleanExec);
    }
    if (app.desktopFile) {
      var dName = app.desktopFile.replace(/\.desktop$/i, "");
      rawList.push(dName);
    }
    if (app.name) {
      rawList.push(app.name);
    }

    var slugs = {};
    for (var i = 0; i < rawList.length; i++) {
      var s = String(rawList[i]).trim();
      if (!s) continue;
      // Strip common package suffixes
      var stripped = s.replace(/(-bin|-git|-appimage|-nightly|-stable|-electron|\.desktop)$/i, "");
      var lower = stripped.toLowerCase();
      var noHyphen = lower.replace(/[-_]/g, "");

      if (lower.length >= 2) slugs[lower] = true;
      if (stripped.length >= 2) slugs[stripped] = true;
      if (noHyphen.length >= 2) slugs[noHyphen] = true;
    }

    return Object.keys(slugs);
  }

  function getCategoryForPath(path, home) {
    var rel = SafeOps.getRelativePath(path, home) || "";
    if (rel.startsWith(".config/autostart")) return "autostart";
    if (rel.startsWith(".config/systemd")) return "service";
    if (rel.startsWith(".config/")) return "config";
    if (rel.startsWith(".local/share/")) return "data";
    if (rel.startsWith(".cache/")) return "cache";
    if (rel.startsWith(".local/state/")) return "state";
    if (rel.startsWith(".")) return "dotdir";
    return "other";
  }

  function buildScanScript(app, home) {
    var slugs = generateCandidateSlugs(app);
    if (slugs.length === 0) return null;

    var escapedHome = SafeOps.shellEscape(SafeOps.normalizePath(home));
    var escapedSlugs = slugs.map(SafeOps.shellEscape).join(" ");

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

  function parseScanOutput(stdoutText, home) {
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

      var check = SafeOps.validateLeftoverPath(p, home);
      if (check.valid && !seen[check.normalized]) {
        seen[check.normalized] = true;
        var cat = getCategoryForPath(check.normalized, home);
        items.push({
          path: check.normalized,
          relative: check.relative,
          size: size,
          sizeFormatted: SafeOps.formatBytes(size),
          category: cat,
          selected: true
        });
      }
    }

    return items;
  }

  exports.generateCandidateSlugs = generateCandidateSlugs;
  exports.getCategoryForPath = getCategoryForPath;
  exports.buildScanScript = buildScanScript;
  exports.parseScanOutput = parseScanOutput;

})(typeof exports !== "undefined" ? exports : (this.LeftoverHunter = {}));
