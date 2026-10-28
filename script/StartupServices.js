// StartupServices.js — Systemd services, systemd-analyze blame (#7), and Hyprland/XDG autostart (#6, #8, #9)

function buildStartupScanScript() {
  var script = [
    'echo "===USER_UNITS_START==="',
    'systemctl --user list-units --type=service --all --no-legend --no-pager 2>/dev/null | awk \'{print $1 "\\t" $3 "\\t" $4}\'',
    'echo "===USER_UNITS_END==="',
    'echo "===SYS_UNITS_START==="',
    'systemctl list-units --type=service --state=running,failed --no-legend --no-pager 2>/dev/null | awk \'{print $1 "\\t" $3 "\\t" $4}\'',
    'echo "===SYS_UNITS_END==="',
    'echo "===BLAME_START==="',
    'systemd-analyze blame --user --no-pager 2>/dev/null | head -n 50 || true',
    'systemd-analyze blame --no-pager 2>/dev/null | head -n 50 || true',
    'echo "===BLAME_END==="',
    'echo "===AUTOSTART_START==="',
    'if [ -f "$HOME/.config/hypr/autostart.conf" ]; then',
    '  grep -nE "^(#\\s*disabled-by-omapp:\\s*)?exec-once\\s*=" "$HOME/.config/hypr/autostart.conf" 2>/dev/null | while IFS= read -r line; do',
    '    echo -e "HYPR\\t$line"',
    '  done',
    'fi',
    'for d in "$HOME/.config/autostart"/*.desktop; do',
    '  [ -f "$d" ] || continue',
    '  nm=$(grep -m1 "^Name=" "$d" | cut -d= -f2-)',
    '  ex=$(grep -m1 "^Exec=" "$d" | cut -d= -f2-)',
    '  hd=$(grep -m1 "^Hidden=" "$d" | cut -d= -f2-)',
    '  echo -e "XDG\\t$d\\t$nm\\t$ex\\t$hd"',
    'done',
    'echo "===AUTOSTART_END==="'
  ].join("\n");

  return ["bash", "-c", script];
}

function sliceSection(raw, startTag, endTag) {
  var s = raw.indexOf(startTag);
  var e = raw.indexOf(endTag);
  if (s === -1 || e === -1 || e <= s) return "";
  return raw.slice(s + startTag.length, e).trim();
}

function parseBlameTimeMs(timeStr) {
  if (!timeStr) return 0;
  var s = timeStr.trim();
  var totalMs = 0;
  var minMatch = s.match(/(\d+)min/);
  if (minMatch) totalMs += parseInt(minMatch[1], 10) * 60000;
  var msMatch = s.match(/(\d+)ms/);
  if (msMatch) totalMs += parseInt(msMatch[1], 10);
  var secMatch = s.match(/([\d.]+)s(?!\w)/);
  if (secMatch && !msMatch) totalMs += Math.round(parseFloat(secMatch[1]) * 1000);
  return totalMs;
}

function parseStartupOutput(rawText) {
  if (!rawText || typeof rawText !== "string") return [];

  var blameBlock = sliceSection(rawText, "===BLAME_START===", "===BLAME_END===");
  var blameMap = {};
  if (blameBlock) {
    var bLines = blameBlock.split("\n");
    for (var b = 0; b < bLines.length; b++) {
      var bLine = bLines[b].trim();
      if (!bLine) continue;
      var bParts = bLine.split(/\s+/);
      if (bParts.length >= 2) {
        var unit = bParts[bParts.length - 1];
        var timeRaw = bParts.slice(0, bParts.length - 1).join(" ");
        blameMap[unit] = parseBlameTimeMs(timeRaw);
      }
    }
  }

  var items = [];

  function addUnits(block, scope) {
    if (!block) return;
    var lines = block.split("\n");
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].trim().split("\t");
      if (parts.length < 3) continue;
      var unit = parts[0].trim();
      if (!unit || unit.indexOf("●") === 0) continue;
      var active = parts[1].trim();
      var sub = parts[2].trim();
      var ms = blameMap[unit] || 0;
      var impact = ms >= 1000 ? "High (" + ms + "ms)" : (ms >= 200 ? "Medium (" + ms + "ms)" : (ms > 0 ? "Low (" + ms + "ms)" : "-"));
      items.push({
        id: unit,
        name: unit.replace(/\.service$/, ""),
        unit: unit,
        scope: scope, // "user" or "system"
        state: active,
        subState: sub || active,
        enabled: active === "active",
        bootMs: ms,
        bootFormatted: ms + " ms",
        impact: ms >= 1000 ? "High" : (ms >= 200 ? "Medium" : "Low"),
        impactFormatted: impact,
        description: "systemctl " + (scope === "user" ? "--user " : "") + "status " + unit,
        targetPath: "",
        command: "systemctl " + (scope === "user" ? "--user " : "") + "status " + unit
      });
    }
  }

  addUnits(sliceSection(rawText, "===USER_UNITS_START===", "===USER_UNITS_END==="), "user");
  addUnits(sliceSection(rawText, "===SYS_UNITS_START===", "===SYS_UNITS_END==="), "system");

  var autoBlock = sliceSection(rawText, "===AUTOSTART_START===", "===AUTOSTART_END===");
  if (autoBlock) {
    var aLines = autoBlock.split("\n");
    for (var a = 0; a < aLines.length; a++) {
      var aLine = aLines[a].trim();
      if (!aLine) continue;
      if (aLine.indexOf("HYPR\t") === 0) {
        var rest = aLine.slice(5);
        var colon = rest.indexOf(":");
        if (colon > 0) {
          var lineNum = parseInt(rest.slice(0, colon), 10) || 0;
          var content = rest.slice(colon + 1).trim();
          var isDis = content.indexOf("#") === 0;
          var eqIdx = content.indexOf("=");
          var cmdStr = eqIdx !== -1 ? content.slice(eqIdx + 1).trim() : content;
          items.push({
            id: "hypr:" + lineNum,
            name: cmdStr.split(/\s+/)[0].split("/").pop() || ("autostart:" + lineNum),
            unit: String(lineNum),
            scope: "hyprland",
            state: isDis ? "disabled" : "enabled",
            enabled: !isDis,
            bootMs: 0,
            impactFormatted: "Startup",
            targetPath: "~/.config/hypr/autostart.conf:" + lineNum,
            command: cmdStr
          });
        }
      } else if (aLine.indexOf("XDG\t") === 0) {
        var xParts = aLine.slice(4).split("\t");
        var dPath = xParts[0] || "";
        var dName = xParts[1] || dPath.split("/").pop();
        var dExec = xParts[2] || "";
        var dHid = (xParts[3] || "").trim().toLowerCase() === "true";
        items.push({
          id: "xdg:" + dPath,
          name: dName,
          unit: dPath,
          scope: "xdg-autostart",
          state: dHid ? "disabled" : "enabled",
          enabled: !dHid,
          bootMs: 0,
          impactFormatted: "Desktop",
          targetPath: dPath,
          command: dExec
        });
      }
    }
  }

  return items;
}

function sortStartupItems(items, sortBy, direction) {
  if (!items || !Array.isArray(items)) return [];
  var isDesc = direction !== "asc";
  var copy = items.slice();
  copy.sort(function(a, b) {
    var vA, vB;
    if (sortBy === "impact") { vA = a.bootMs || 0; vB = b.bootMs || 0; }
    else if (sortBy === "scope") { vA = a.scope; vB = b.scope; }
    else if (sortBy === "state") { vA = a.state; vB = b.state; }
    else { vA = a.name.toLowerCase(); vB = b.name.toLowerCase(); }
    if (vA < vB) return isDesc ? 1 : -1;
    if (vA > vB) return isDesc ? -1 : 1;
    return 0;
  });
  return copy;
}

function buildServiceActionCommand(item, action, useSudo) {
  if (!item || !action) return null;
  var validActions = { "start": true, "stop": true, "restart": true, "enable": true, "disable": true };
  if (!validActions[action]) return null;

  if (item.scope === "user" && /^[a-zA-Z0-9@_.-]+$/.test(item.unit)) {
    return ["systemctl", "--user", action, item.unit];
  }
  if (item.scope === "system" && /^[a-zA-Z0-9@_.-]+$/.test(item.unit)) {
    return useSudo ? ["sudo", "-S", "-p", "", "systemctl", action, item.unit] : null;
  }
  if (item.scope === "hyprland") {
    var ln = parseInt(item.unit, 10);
    if (isNaN(ln) || ln <= 0) return null;
    if (action === "disable" || action === "stop") {
      return ["bash", "-c", 'sed -i "' + ln + 's/^exec-once/# disabled-by-omapp: exec-once/" "$HOME/.config/hypr/autostart.conf"'];
    }
    if (action === "enable" || action === "start") {
      return ["bash", "-c", 'sed -i "' + ln + 's/^#\\s*disabled-by-omapp:\\s*//" "$HOME/.config/hypr/autostart.conf"'];
    }
  }
  return null;
}

function buildServicesScanScript() { return buildStartupScanScript(); }
function parseServicesOutput(rawText) { return parseStartupOutput(rawText); }
function filterServices(items, category, query) {
  if (!items || !Array.isArray(items)) return [];
  var q = (query || "").toLowerCase().trim();
  return items.filter(function(s) {
    if (category === "user" && s.scope !== "user") return false;
    if (category === "system" && s.scope !== "system") return false;
    if (category === "running" && s.subState !== "running" && s.state !== "running") return false;
    if (category === "failed" && s.state !== "failed" && s.subState !== "failed") return false;
    if (category === "autostart" && s.scope !== "hyprland" && s.scope !== "xdg-autostart") return false;
    if (!q) return true;
    return s.name.toLowerCase().indexOf(q) !== -1 || String(s.id).toLowerCase().indexOf(q) !== -1;
  });
}
function sortServices(items, sortBy, direction) { return sortStartupItems(items, sortBy, direction); }

function buildServiceLogsScript(unitOrItem, scopeArg) {
  var u = (typeof unitOrItem === "object" && unitOrItem) ? unitOrItem.unit : String(unitOrItem || "");
  var sc = (typeof unitOrItem === "object" && unitOrItem) ? unitOrItem.scope : String(scopeArg || "user");
  if (!u || !/^[a-zA-Z0-9@_.-]+$/.test(u)) return null;
  if (sc === "user") {
    return ["journalctl", "--user", "-u", u, "-n", "30", "--no-pager", "-o", "short-iso"];
  }
  if (sc === "system") {
    return ["journalctl", "-u", u, "-n", "30", "--no-pager", "-o", "short-iso"];
  }
  return null;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    buildStartupScanScript: buildStartupScanScript,
    buildServicesScanScript: buildServicesScanScript,
    parseBlameTimeMs: parseBlameTimeMs,
    parseStartupOutput: parseStartupOutput,
    parseServicesOutput: parseServicesOutput,
    filterServices: filterServices,
    sortStartupItems: sortStartupItems,
    sortServices: sortServices,
    buildServiceActionCommand: buildServiceActionCommand,
    buildServiceLogsScript: buildServiceLogsScript
  };
}
