// TaskManager.js — Process monitoring, hybrid GPU (DRM fdinfo + NVIDIA) tracking, task termination, and executable locator for OMAPP

function buildProcessScanScript() {
  var script = [
    'echo "===PS_START==="',
    'ps -eo pid,user,%cpu,%mem,rss,comm --no-headers --sort=-%cpu 2>/dev/null',
    'echo "===PS_END==="',
    'echo "===GPU_START==="',
    'nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits 2>/dev/null || true',
    'echo "===GPU_END==="',
    'echo "===DRM_START==="',
    'drm_files=$(grep -l "^drm-client-id:" /proc/[0-9]*/fdinfo/* 2>/dev/null)',
    'if [ -n "$drm_files" ]; then',
    '  awk \'FNR==1 { if (cid != "") print pid "\\t" cid "\\t" vram "\\t" gtt "\\t" eng; split(FILENAME, a, "/"); pid=a[3]; cid=""; vram=0; gtt=0; eng=0 } /^drm-client-id:/ { cid=$2 } /^drm-memory-vram:/ { vram=$2 } /^drm-memory-gtt:/ { gtt=$2 } /^drm-engine-/ { eng+=$2 } END { if (cid != "") print pid "\\t" cid "\\t" vram "\\t" gtt "\\t" eng }\' $drm_files 2>/dev/null',
    'fi',
    'echo "===DRM_END==="'
  ].join("\n");

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

function parseProcessOutput(rawText, currentUser, prevGpuState, nowMs) {
  if (!rawText || typeof rawText !== "string") return [];

  var tsNow = (typeof nowMs === "number" && nowMs > 0) ? nowMs : Date.now();
  var psStart = rawText.indexOf("===PS_START===");
  var psEnd = rawText.indexOf("===PS_END===");
  var gpuStart = rawText.indexOf("===GPU_START===");
  var gpuEnd = rawText.indexOf("===GPU_END===");
  var drmStart = rawText.indexOf("===DRM_START===");
  var drmEnd = rawText.indexOf("===DRM_END===");

  // 1. Parse NVIDIA GPU memory if present (MiB per PID)
  var nvMemDict = {};
  if (gpuStart !== -1 && gpuEnd !== -1) {
    var gpuBlock = rawText.slice(gpuStart + 15, gpuEnd).trim();
    if (gpuBlock) {
      var gLines = gpuBlock.split("\n");
      for (var g = 0; g < gLines.length; g++) {
        var gLine = gLines[g].trim();
        if (!gLine) continue;
        var gParts = gLine.split(",");
        if (gParts.length >= 2) {
          var gPid = parseInt(gParts[0].trim(), 10);
          var gMem = parseInt(gParts[1].trim(), 10) || 0;
          if (gPid > 0) nvMemDict[gPid] = (nvMemDict[gPid] || 0) + gMem;
        }
      }
    }
  }

  // 2. Parse DRM fdinfo (AMD/Intel/Nouveau per-process VRAM KiB, GTT KiB, Engine ns)
  // Deduplicate by pid + ":" + clientId so duplicate FDs in a process aren't double-counted
  var seenClients = {};
  var drmDict = {};
  if (drmStart !== -1 && drmEnd !== -1) {
    var drmBlock = rawText.slice(drmStart + 15, drmEnd).trim();
    if (drmBlock) {
      var dLines = drmBlock.split("\n");
      for (var d = 0; d < dLines.length; d++) {
        var dLine = dLines[d].trim();
        if (!dLine) continue;
        var dParts = dLine.split(/\t|\s+/);
        if (dParts.length >= 5) {
          var dPid = parseInt(dParts[0], 10);
          var clientId = dParts[1];
          var vramKiB = parseInt(dParts[2], 10) || 0;
          var gttKiB = parseInt(dParts[3], 10) || 0;
          var engNs = parseFloat(dParts[4]) || 0;
          if (dPid > 0 && clientId) {
            var key = dPid + ":" + clientId;
            if (seenClients[key]) continue;
            seenClients[key] = true;
            if (!drmDict[dPid]) {
              drmDict[dPid] = { vramKiB: 0, gttKiB: 0, engNs: 0 };
            }
            drmDict[dPid].vramKiB += vramKiB;
            drmDict[dPid].gttKiB += gttKiB;
            drmDict[dPid].engNs += engNs;
          }
        }
      }
    }
  }

  // 3. Parse PS block
  var psText = rawText;
  if (psStart !== -1 && psEnd !== -1) {
    psText = rawText.slice(psStart + 15, psEnd);
  }

  var lines = psText.split("\n");
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

    var nvMiB = nvMemDict[pid] || 0;
    var drmInfo = drmDict[pid];
    var drmMiB = 0;
    var gpuPercent = 0.0;

    if (drmInfo) {
      // Use VRAM when > 1 MiB, otherwise include GTT for small APU surfaces
      var effectiveKiB = drmInfo.vramKiB >= 1024 ? drmInfo.vramKiB : (drmInfo.vramKiB + drmInfo.gttKiB);
      drmMiB = Math.round(effectiveKiB / 1024);

      if (prevGpuState && typeof prevGpuState === "object") {
        var prev = prevGpuState[pid];
        if (prev && tsNow > prev.tsMs && drmInfo.engNs >= prev.engNs) {
          var deltaWallNs = (tsNow - prev.tsMs) * 1000000;
          var deltaEngNs = drmInfo.engNs - prev.engNs;
          var pct = (deltaEngNs / deltaWallNs) * 100.0;
          if (pct > 100.0) pct = 100.0;
          if (pct < 0.0) pct = 0.0;
          gpuPercent = Math.round(pct * 10) / 10;
        }
        prevGpuState[pid] = { engNs: drmInfo.engNs, tsMs: tsNow };
      }
    }

    var gpuMemMiB = nvMiB + drmMiB;
    // Composite GPU score for sorting: active GPU % weighted above passive VRAM MiB
    var gpuScore = (gpuPercent * 10000) + gpuMemMiB;
    var gpuFormatted = "0.0%";
    if (gpuPercent > 0.0) {
      gpuFormatted = gpuPercent.toFixed(1) + "%";
    } else if (gpuMemMiB > 0) {
      gpuFormatted = gpuMemMiB + " MiB";
    }

    tasks.push({
      pid: pid,
      user: user,
      cpu: cpu,
      cpuFormatted: cpu.toFixed(1) + "%",
      mem: mem,
      memFormatted: mem.toFixed(1) + "%",
      rss: rssBytes,
      rssFormatted: rssFormatted,
      gpu: gpuScore,
      gpuPercent: gpuPercent,
      gpuMemMiB: gpuMemMiB,
      gpuFormatted: gpuFormatted,
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
    } else if (category === "heavy_gpu") {
      if ((t.gpuPercent || 0) <= 0 && (t.gpuMemMiB || 0) <= 0 && (t.gpu || 0) <= 0) return false;
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
    } else if (sortBy === "gpu") {
      valA = a.gpu;
      valB = b.gpu;
    } else if (sortBy === "pid") {
      valA = a.pid;
      valB = b.pid;
    } else if (sortBy === "user") {
      valA = a.user.toLowerCase();
      valB = b.user.toLowerCase();
    } else { // name
      valA = a.name.toLowerCase();
      valB = b.name.toLowerCase();
    }

    if (valA < valB) return isDesc ? 1 : -1;
    if (valA > valB) return isDesc ? -1 : 1;
    // Tie-breaker: CPU descending
    if (a.cpu !== b.cpu) return b.cpu - a.cpu;
    return a.pid - b.pid;
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
    '  pkg=$(pacman -Qoq "$exe" 2>/dev/null | head -n1 || echo "")',
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
