// TaskManager.js — Process monitoring, task termination, and executable locator for OMAPP

function buildProcessScanScript() {
  var script = 'ps -eo pid,user,%cpu,%mem,rss,comm --no-headers --sort=-%cpu 2>/dev/null';
  return ["bash", "-c", script];
}

function formatBytes(bytes) {
  if (bytes === 0) return "0 B";
  var k = 1024;
  var sizes = ["B", "KiB", "MiB", "GiB", "TiB"];
  var i = Math.floor(Math.log(bytes) / Math.log(k));
  if (i < 0) i = 0;
  if (i >= sizes.length) i = sizes.length - 1;
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i];
}

function parseProcessOutput(rawText, currentUser) {
  if (!rawText || typeof rawText !== "string") return [];
  var lines = rawText.split("\n");
  var tasks = [];

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (!line) continue;

    // Format: PID USER %CPU %MEM RSS COMM
    var parts = line.split(/\s+/);
    if (parts.length < 6) continue;

    var pid = parseInt(parts[0], 10);
    if (isNaN(pid) || pid <= 0) continue;

    var user = parts[1];
    var cpu = parseFloat(parts[2]) || 0.0;
    var mem = parseFloat(parts[3]) || 0.0;
    var rssKiB = parseInt(parts[4], 10) || 0;
    var comm = parts.slice(5).join(" ");

    var rssBytes = rssKiB * 1024;
    var rssFormatted = formatBytes(rssBytes);
    var isMine = currentUser ? (user === currentUser) : true;

    tasks.push({
      pid: pid,
      user: user,
      cpu: cpu,
      cpuFormatted: cpu.toFixed(1) + "%",
      mem: mem,
      memFormatted: mem.toFixed(1) + "%",
      rss: rssBytes,
      rssFormatted: rssFormatted,
      name: comm,
      isMine: isMine
    });
  }

  return tasks;
}

function filterTasks(tasks, query, category, currentUser) {
  if (!tasks || !Array.isArray(tasks)) return [];
  var q = (query || "").toLowerCase().trim();

  return tasks.filter(function(t) {
    // 1. Category filter
    if (category === "user") {
      if (currentUser && t.user !== currentUser) return false;
    } else if (category === "system") {
      if (currentUser && t.user === currentUser) return false;
    } else if (category === "heavy_cpu") {
      if (t.cpu < 1.0) return false;
    } else if (category === "heavy_ram") {
      if (t.rss < 100 * 1024 * 1024) return false; // >= 100 MiB
    }

    // 2. Query filter
    if (!q) return true;
    if (String(t.pid).indexOf(q) !== -1) return true;
    if (t.name.toLowerCase().indexOf(q) !== -1) return true;
    if (t.user.toLowerCase().indexOf(q) !== -1) return true;
    return false;
  });
}

function sortTasks(tasks, sortBy, direction) {
  if (!tasks || !Array.isArray(tasks)) return [];
  var isDesc = (direction !== "asc");
  var copy = tasks.slice();

  copy.sort(function(a, b) {
    var valA, valB;
    if (sortBy === "cpu") {
      valA = a.cpu;
      valB = b.cpu;
    } else if (sortBy === "mem" || sortBy === "ram") {
      valA = a.rss;
      valB = b.rss;
    } else if (sortBy === "pid") {
      valA = a.pid;
      valB = b.pid;
    } else { // name
      valA = a.name.toLowerCase();
      valB = b.name.toLowerCase();
    }

    if (valA < valB) return isDesc ? 1 : -1;
    if (valA > valB) return isDesc ? -1 : 1;
    return 0;
  });

  return copy;
}

function buildKillCommand(pid, force, useSudo) {
  var p = parseInt(pid, 10);
  if (isNaN(p) || p <= 1) return null; // Protect PID 1 (systemd)

  var sig = force ? "-9" : "-15";
  if (useSudo) {
    return ["sudo", "-n", "kill", sig, String(p)];
  }
  return ["kill", sig, String(p)];
}

function buildOpenFileLocationCommand(pid) {
  var p = parseInt(pid, 10);
  if (isNaN(p) || p <= 0) return null;

  var script = [
    'exe=$(readlink -f "/proc/' + p + '/exe" 2>/dev/null)',
    'if [ -n "$exe" ] && [ -e "$exe" ]; then',
    '  dir=$(dirname "$exe")',
    '  xdg-open "$dir" >/dev/null 2>&1 &',
    'elif [ -d "/proc/' + p + '/cwd" ]; then',
    '  dir=$(readlink -f "/proc/' + p + '/cwd" 2>/dev/null)',
    '  [ -n "$dir" ] && xdg-open "$dir" >/dev/null 2>&1 &',
    'fi'
  ].join("\n");

  return ["bash", "-c", script];
}

function buildGetProcessDetailsScript(pid) {
  var p = parseInt(pid, 10);
  if (isNaN(p) || p <= 0) return null;

  var script = [
    'pid="' + p + '"',
    'exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null || echo "")',
    'cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null || echo "")',
    'cmdline=$(tr "\\0" " " < "/proc/$pid/cmdline" 2>/dev/null || echo "")',
    'pkg=""',
    'if [ -n "$exe" ] && [ -f "$exe" ]; then',
    '  pkg=$(pacman -Qo "$exe" 2>/dev/null | awk \'{print $NF}\' || echo "")',
    'fi',
    'echo -e "EXE\\t$exe"',
    'echo -e "CWD\\t$cwd"',
    'echo -e "CMD\\t$cmdline"',
    'echo -e "PKG\\t$pkg"'
  ].join("\n");

  return ["bash", "-c", script];
}

function parseProcessDetails(rawText) {
  var res = { exe: "", cwd: "", cmd: "", pkg: "" };
  if (!rawText || typeof rawText !== "string") return res;

  var lines = rawText.split("\n");
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (line.indexOf("EXE\t") === 0) res.exe = line.slice(4).trim();
    else if (line.indexOf("CWD\t") === 0) res.cwd = line.slice(4).trim();
    else if (line.indexOf("CMD\t") === 0) res.cmd = line.slice(4).trim();
    else if (line.indexOf("PKG\t") === 0) res.pkg = line.slice(4).trim();
  }
  return res;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    buildProcessScanScript: buildProcessScanScript,
    parseProcessOutput: parseProcessOutput,
    filterTasks: filterTasks,
    sortTasks: sortTasks,
    buildKillCommand: buildKillCommand,
    buildOpenFileLocationCommand: buildOpenFileLocationCommand,
    buildGetProcessDetailsScript: buildGetProcessDetailsScript,
    parseProcessDetails: parseProcessDetails,
    formatBytes: formatBytes
  };
}
