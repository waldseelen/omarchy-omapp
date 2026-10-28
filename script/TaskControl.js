// TaskControl.js — Process actions, priority/renice (#3), CPU affinity (#3), freeze/resume (#4), ports (#10), and logs (#9)

function sliceBlock(raw, startTag, endTag) {
  var s = raw.indexOf(startTag);
  var e = raw.indexOf(endTag);
  if (s === -1 || e === -1 || e <= s) return "";
  return raw.slice(s + startTag.length, e).trim();
}

function buildKillCommand(pid, force, useSudo) {
  var p = parseInt(pid, 10);
  if (isNaN(p) || p <= 1) return null;
  var sig = force ? "-9" : "-15";
  return useSudo ? ["sudo", "-S", "-p", "", "kill", sig, String(p)] : ["kill", sig, String(p)];
}

function buildFreezeCommand(pid, freeze, useSudo) {
  var p = parseInt(pid, 10);
  if (isNaN(p) || p <= 1) return null;
  var sig = freeze ? "-STOP" : "-CONT";
  return useSudo ? ["sudo", "-S", "-p", "", "kill", sig, String(p)] : ["kill", sig, String(p)];
}

function buildReniceCommand(pid, niceValue, useSudo) {
  var p = parseInt(pid, 10);
  var n = parseInt(niceValue, 10);
  if (isNaN(p) || p <= 1 || isNaN(n)) return null;
  if (n < -20) n = -20;
  if (n > 19) n = 19;
  if (useSudo || n < 0) {
    return ["sudo", "-S", "-p", "", "renice", "-n", String(n), "-p", String(p)];
  }
  return ["renice", "-n", String(n), "-p", String(p)];
}

function buildAffinityCommand(pid, cpuSpec, useSudo) {
  var p = parseInt(pid, 10);
  if (isNaN(p) || p <= 1 || !cpuSpec || typeof cpuSpec !== "string") return null;
  var cleanSpec = cpuSpec.trim();
  if (!/^[0-9,-]+$/.test(cleanSpec)) return null;
  if (useSudo) {
    return ["sudo", "-S", "-p", "", "taskset", "-pc", cleanSpec, String(p)];
  }
  return ["taskset", "-pc", cleanSpec, String(p)];
}

function buildOpenFileLocationCommand(pid) {
  var p = parseInt(pid, 10);
  if (isNaN(p) || p <= 0) return null;
  var script = [
    'exe=$(readlink -f "/proc/' + p + '/exe" 2>/dev/null)',
    'if [ -n "$exe" ] && [ -e "$exe" ]; then xdg-open "$(dirname "$exe")" >/dev/null 2>&1 &',
    'elif [ -d "/proc/' + p + '/cwd" ]; then dir=$(readlink -f "/proc/' + p + '/cwd" 2>/dev/null); [ -n "$dir" ] && xdg-open "$dir" >/dev/null 2>&1 & fi'
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
    'if [ -n "$exe" ] && [ -f "$exe" ]; then pkg=$(pacman -Qoq "$exe" 2>/dev/null | head -n1 || echo ""); fi',
    'ports=$(ss -tulnp 2>/dev/null | grep "pid=$pid," | awk \'{print $1 " " $5}\' | tr "\\n" "," | sed "s/,$//")',
    'aff=$(taskset -pc "$pid" 2>/dev/null | awk -F": " \'{print $2}\' || echo "")',
    'echo -e "EXE\\t$exe"',
    'echo -e "CWD\\t$cwd"',
    'echo -e "CMD\\t$cmdline"',
    'echo -e "PKG\\t$pkg"',
    'echo -e "PORTS\\t$ports"',
    'echo -e "AFF\\t$aff"',
    'echo "===LOGS_START==="',
    'journalctl _PID="$pid" -n 20 --no-pager -o short-iso 2>/dev/null || true',
    'echo "===LOGS_END==="'
  ].join("\n");
  return ["bash", "-c", script];
}

function parseProcessDetails(rawText) {
  var res = { exe: "", cwd: "", cmd: "", pkg: "", ports: "", affinity: "", logs: "" };
  if (!rawText || typeof rawText !== "string") return res;
  res.logs = sliceBlock(rawText, "===LOGS_START===", "===LOGS_END===");
  var lines = rawText.split("\n");
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (line.indexOf("EXE\t") === 0) res.exe = line.slice(4).trim();
    else if (line.indexOf("CWD\t") === 0) res.cwd = line.slice(4).trim();
    else if (line.indexOf("CMD\t") === 0) res.cmd = line.slice(4).trim();
    else if (line.indexOf("PKG\t") === 0) res.pkg = line.slice(4).trim();
    else if (line.indexOf("PORTS\t") === 0) res.ports = line.slice(6).trim();
    else if (line.indexOf("AFF\t") === 0) res.affinity = line.slice(4).trim();
  }
  return res;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    buildKillCommand: buildKillCommand,
    buildFreezeCommand: buildFreezeCommand,
    buildReniceCommand: buildReniceCommand,
    buildAffinityCommand: buildAffinityCommand,
    buildOpenFileLocationCommand: buildOpenFileLocationCommand,
    buildGetProcessDetailsScript: buildGetProcessDetailsScript,
    parseProcessDetails: parseProcessDetails
  };
}
