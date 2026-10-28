// TaskManager.js — Process monitoring, hybrid GPU, live Disk I/O (#5), system telemetry (#2), process grouping (#1), and pinned sorting (#30)

function buildProcessScanScript() {
  var script = [
    'echo "===SYS_START==="',
    'head -n 1 /proc/stat 2>/dev/null',
    'grep -E "^(MemTotal|MemAvailable):" /proc/meminfo 2>/dev/null',
    'cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -n 2',
    'cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | sort -nr | head -n 1',
    'echo "===SYS_END==="',
    'echo "===PS_START==="',
    'ps -eo pid,user,%cpu,%mem,rss,stat,ni,comm --no-headers --sort=-%cpu 2>/dev/null',
    'echo "===PS_END==="',
    'echo "===GPU_START==="',
    'nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits 2>/dev/null || true',
    'echo "===GPU_END==="',
    'echo "===DRM_START==="',
    'drm_files=$(grep -l "^drm-client-id:" /proc/[0-9]*/fdinfo/* 2>/dev/null)',
    'if [ -n "$drm_files" ]; then',
    '  awk \'FNR==1 { if (cid != "") print pid "\\t" cid "\\t" vram "\\t" gtt "\\t" eng; split(FILENAME, a, "/"); pid=a[3]; cid=""; vram=0; gtt=0; eng=0 } /^drm-client-id:/ { cid=$2 } /^drm-memory-vram:/ { vram=$2 } /^drm-memory-gtt:/ { gtt=$2 } /^drm-engine-/ { eng+=$2 } END { if (cid != "") print pid "\\t" cid "\\t" vram "\\t" gtt "\\t" eng }\' $drm_files 2>/dev/null',
    'fi',
    'echo "===DRM_END==="',
    'echo "===IO_START==="',
    'awk \'FNR==1 { if (pid != "") print pid "\\t" rb "\\t" wb; split(FILENAME, a, "/"); pid=a[3]; rb=0; wb=0 } /^read_bytes:/ { rb=$2 } /^write_bytes:/ { wb=$2 } END { if (pid != "") print pid "\\t" rb "\\t" wb }\' /proc/[0-9]*/io 2>/dev/null || true',
    'echo "===IO_END==="'
  ].join("\n");

  return ["bash", "-c", script];
}

function formatBytes(bytes) {
  if (!bytes || bytes <= 0) return "0 B";
  var k = 1024;
  var sizes = ["B", "KiB", "MiB", "GiB", "TiB"];
  var i = Math.floor(Math.log(bytes) / Math.log(k));
  if (i < 0) i = 0;
  if (i >= sizes.length) i = sizes.length - 1;
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i];
}

function sliceBlock(raw, startTag, endTag) {
  var s = raw.indexOf(startTag);
  var e = raw.indexOf(endTag);
  if (s === -1 || e === -1 || e <= s) return "";
  return raw.slice(s + startTag.length, e).trim();
}

function parseSystemHeaderStats(rawText, prevCpuObj) {
  var res = { cpuPercent: 0.0, memUsedGiB: 0.0, memTotalGiB: 0.0, memPercent: 0.0, gpuPercent: 0.0, tempC: 0 };
  if (!rawText || typeof rawText !== "string") return res;
  var block = sliceBlock(rawText, "===SYS_START===", "===SYS_END===");
  if (!block) return res;

  var lines = block.split("\n");
  var memTotalKiB = 0;
  var memAvailKiB = 0;
  var maxGpu = 0;

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (!line) continue;
    if (line.indexOf("cpu ") === 0) {
      var parts = line.split(/\s+/);
      var total = 0;
      for (var c = 1; c < parts.length; c++) total += (parseInt(parts[c], 10) || 0);
      var idle = (parseInt(parts[4], 10) || 0) + (parseInt(parts[5], 10) || 0);
      if (prevCpuObj && typeof prevCpuObj === "object") {
        if (prevCpuObj.total > 0 && total > prevCpuObj.total) {
          var dTotal = total - prevCpuObj.total;
          var dIdle = idle - prevCpuObj.idle;
          var pct = ((dTotal - dIdle) / dTotal) * 100.0;
          res.cpuPercent = Math.max(0, Math.min(100, Math.round(pct * 10) / 10));
        }
        prevCpuObj.total = total;
        prevCpuObj.idle = idle;
      }
    } else if (line.indexOf("MemTotal:") === 0) {
      memTotalKiB = parseInt(line.replace(/[^0-9]/g, ""), 10) || 0;
    } else if (line.indexOf("MemAvailable:") === 0) {
      memAvailKiB = parseInt(line.replace(/[^0-9]/g, ""), 10) || 0;
    } else {
      var num = parseInt(line, 10);
      if (!isNaN(num)) {
        if (num >= 15000) {
          res.tempC = Math.round(num / 1000);
        } else if (num >= 0 && num <= 100) {
          if (num > maxGpu) maxGpu = num;
        }
      }
    }
  }

  if (memTotalKiB > 0) {
    var usedKiB = Math.max(0, memTotalKiB - memAvailKiB);
    res.memTotalGiB = Math.round((memTotalKiB / (1024 * 1024)) * 10) / 10;
    res.memUsedGiB = Math.round((usedKiB / (1024 * 1024)) * 10) / 10;
    res.memPercent = Math.round((usedKiB / memTotalKiB) * 100);
  }
  res.gpuPercent = maxGpu;
  return res;
}

function parseProcessOutput(rawText, currentUser, prevGpuState, nowMs) {
  if (!rawText || typeof rawText !== "string") return [];

  var tsNow = (typeof nowMs === "number" && nowMs > 0) ? nowMs : Date.now();
  var gpuBlock = sliceBlock(rawText, "===GPU_START===", "===GPU_END===");
  var drmBlock = sliceBlock(rawText, "===DRM_START===", "===DRM_END===");
  var ioBlock = sliceBlock(rawText, "===IO_START===", "===IO_END===");
  var psText = sliceBlock(rawText, "===PS_START===", "===PS_END===") || rawText;

  var nvMemDict = {};
  if (gpuBlock) {
    var gLines = gpuBlock.split("\n");
    for (var g = 0; g < gLines.length; g++) {
      var gParts = gLines[g].trim().split(",");
      if (gParts.length >= 2) {
        var gPid = parseInt(gParts[0].trim(), 10);
        var gMem = parseInt(gParts[1].trim(), 10) || 0;
        if (gPid > 0) nvMemDict[gPid] = (nvMemDict[gPid] || 0) + gMem;
      }
    }
  }

  var seenClients = {};
  var drmDict = {};
  if (drmBlock) {
    var dLines = drmBlock.split("\n");
    for (var d = 0; d < dLines.length; d++) {
      var dParts = dLines[d].trim().split(/\t|\s+/);
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
          if (!drmDict[dPid]) drmDict[dPid] = { vramKiB: 0, gttKiB: 0, engNs: 0 };
          drmDict[dPid].vramKiB += vramKiB;
          drmDict[dPid].gttKiB += gttKiB;
          drmDict[dPid].engNs += engNs;
        }
      }
    }
  }

  var ioDict = {};
  if (ioBlock) {
    var ioLines = ioBlock.split("\n");
    for (var k = 0; k < ioLines.length; k++) {
      var ioParts = ioLines[k].trim().split(/\t|\s+/);
      if (ioParts.length >= 3) {
        var ioPid = parseInt(ioParts[0], 10);
        var rb = parseFloat(ioParts[1]) || 0;
        var wb = parseFloat(ioParts[2]) || 0;
        if (ioPid > 0) ioDict[ioPid] = rb + wb;
      }
    }
  }

  var lines = psText.split("\n");
  var tasks = [];

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (!line) continue;

    var parts = line.split(/\s+/);
    if (parts.length < 6) continue;

    var pid = parseInt(parts[0], 10);
    if (isNaN(pid) || pid <= 0) continue;

    var user = parts[1];
    var cpu = parseFloat(parts[2]) || 0.0;
    var mem = parseFloat(parts[3]) || 0.0;
    var rssKiB = parseInt(parts[4], 10) || 0;

    // Support both 6-column legacy PS format and 8-column extended format (stat + nice)
    var statCode = "S";
    var niceVal = 0;
    var comm = "";
    if (parts.length >= 8 && /^[RSDZTWtXxKPsNl+<]+$/.test(parts[5]) && /^-?\d+$/.test(parts[6])) {
      statCode = parts[5];
      niceVal = parseInt(parts[6], 10) || 0;
      comm = parts.slice(7).join(" ");
    } else {
      comm = parts.slice(5).join(" ");
    }

    var rssBytes = rssKiB * 1024;
    var isMine = currentUser ? (user === currentUser) : true;
    var isFrozen = statCode.charAt(0) === "T";

    var nvMiB = nvMemDict[pid] || 0;
    var drmInfo = drmDict[pid];
    var drmMiB = 0;
    var gpuPercent = 0.0;

    if (drmInfo) {
      var effectiveKiB = drmInfo.vramKiB >= 1024 ? drmInfo.vramKiB : (drmInfo.vramKiB + drmInfo.gttKiB);
      drmMiB = Math.round(effectiveKiB / 1024);
      if (prevGpuState && typeof prevGpuState === "object") {
        var prev = prevGpuState[pid];
        if (prev && tsNow > prev.tsMs && drmInfo.engNs >= prev.engNs) {
          var deltaWallNs = (tsNow - prev.tsMs) * 1000000;
          var deltaEngNs = drmInfo.engNs - prev.engNs;
          var pct = (deltaEngNs / deltaWallNs) * 100.0;
          gpuPercent = Math.round(Math.max(0, Math.min(100, pct)) * 10) / 10;
        }
        prevGpuState[pid] = {
          engNs: drmInfo.engNs,
          ioBytes: ioDict[pid] || 0,
          tsMs: tsNow
        };
      }
    }

    var diskBps = 0;
    if (ioDict[pid] !== undefined && prevGpuState && typeof prevGpuState === "object") {
      var prevIo = prevGpuState["io_" + pid];
      if (prevIo && tsNow > prevIo.tsMs && ioDict[pid] >= prevIo.bytes) {
        var deltaSec = (tsNow - prevIo.tsMs) / 1000.0;
        diskBps = Math.round((ioDict[pid] - prevIo.bytes) / deltaSec);
      }
      prevGpuState["io_" + pid] = { bytes: ioDict[pid], tsMs: tsNow };
    }

    var gpuMemMiB = nvMiB + drmMiB;
    var gpuScore = (gpuPercent * 10000) + gpuMemMiB;
    var gpuFormatted = "0.0%";
    if (gpuPercent > 0.0) gpuFormatted = gpuPercent.toFixed(1) + "%";
    else if (gpuMemMiB > 0) gpuFormatted = gpuMemMiB + " MiB";

    tasks.push({
      pid: pid,
      user: user,
      cpu: cpu,
      cpuFormatted: cpu.toFixed(1) + "%",
      mem: mem,
      memFormatted: mem.toFixed(1) + "%",
      rss: rssBytes,
      rssFormatted: formatBytes(rssBytes),
      gpu: gpuScore,
      gpuPercent: gpuPercent,
      gpuMemMiB: gpuMemMiB,
      gpuFormatted: gpuFormatted,
      diskBps: diskBps,
      diskFormatted: diskBps > 0 ? (formatBytes(diskBps) + "/s") : "0 B/s",
      state: statCode,
      isFrozen: isFrozen,
      nice: niceVal,
      name: comm,
      isMine: isMine,
      groupCount: 1
    });
  }

  return tasks;
}

function groupTasksByApp(tasks, expandedGroups) {
  if (!tasks || !Array.isArray(tasks)) return [];
  var groups = {};
  var order = [];

  for (var i = 0; i < tasks.length; i++) {
    var t = tasks[i];
    var key = t.name;
    if (!groups[key]) {
      groups[key] = {
        pid: t.pid, user: t.user, cpu: 0, mem: 0, rss: 0, gpuPercent: 0, gpuMemMiB: 0, diskBps: 0,
        state: t.state, isFrozen: t.isFrozen, nice: t.nice, name: t.name, isMine: t.isMine, groupCount: 0, children: []
      };
      order.push(key);
    }
    var g = groups[key];
    g.cpu += t.cpu;
    g.mem += t.mem;
    g.rss += t.rss;
    g.gpuPercent = Math.min(100, g.gpuPercent + t.gpuPercent);
    g.gpuMemMiB += t.gpuMemMiB;
    g.diskBps += t.diskBps;
    g.groupCount++;
    g.children.push(t);
  }

  var result = [];
  var exp = (expandedGroups && typeof expandedGroups === "object") ? expandedGroups : {};
  for (var k = 0; k < order.length; k++) {
    var grp = groups[order[k]];
    grp.cpu = Math.round(grp.cpu * 10) / 10;
    grp.cpuFormatted = grp.cpu.toFixed(1) + "%";
    grp.rssFormatted = formatBytes(grp.rss);
    grp.gpu = (grp.gpuPercent * 10000) + grp.gpuMemMiB;
    grp.gpuFormatted = grp.gpuPercent > 0 ? (grp.gpuPercent.toFixed(1) + "%") : (grp.gpuMemMiB > 0 ? (grp.gpuMemMiB + " MiB") : "0.0%");
    grp.diskFormatted = grp.diskBps > 0 ? (formatBytes(grp.diskBps) + "/s") : "0 B/s";
    result.push(grp);
    if (grp.groupCount > 1 && exp[grp.name]) {
      for (var c = 0; c < grp.children.length; c++) {
        var child = Object.assign({}, grp.children[c], { isChild: true });
        result.push(child);
      }
    }
  }
  return result;
}

function filterTasks(tasks, query, category, currentUser) {
  if (!tasks || !Array.isArray(tasks)) return [];
  var q = (query || "").toLowerCase().trim();

  return tasks.filter(function(t) {
    if (category === "user") {
      if (currentUser && t.user !== currentUser) return false;
    } else if (category === "system") {
      if (currentUser && t.user === currentUser) return false;
    } else if (category === "heavy_cpu") {
      if (t.cpu < 1.0) return false;
    } else if (category === "heavy_ram") {
      if (t.rss < 100 * 1024 * 1024) return false;
    } else if (category === "heavy_gpu") {
      if ((t.gpuPercent || 0) <= 0 && (t.gpuMemMiB || 0) <= 0 && (t.gpu || 0) <= 0) return false;
    }

    if (!q) return true;
    if (String(t.pid).indexOf(q) !== -1) return true;
    if (t.name.toLowerCase().indexOf(q) !== -1) return true;
    if (t.user.toLowerCase().indexOf(q) !== -1) return true;
    return false;
  });
}

function sortTasks(tasks, sortBy, direction, pinnedMap) {
  if (!tasks || !Array.isArray(tasks)) return [];
  var isDesc = (direction !== "asc");
  var pins = (pinnedMap && typeof pinnedMap === "object") ? pinnedMap : {};
  var copy = tasks.slice();

  copy.sort(function(a, b) {
    var aPin = !!(pins[a.name] || pins[String(a.pid)] || a.pinned);
    var bPin = !!(pins[b.name] || pins[String(b.pid)] || b.pinned);
    if (aPin !== bPin) return aPin ? -1 : 1;

    var valA, valB;
    if (sortBy === "cpu") { valA = a.cpu; valB = b.cpu; }
    else if (sortBy === "mem" || sortBy === "ram") { valA = a.rss; valB = b.rss; }
    else if (sortBy === "gpu") { valA = a.gpu; valB = b.gpu; }
    else if (sortBy === "disk") { valA = a.diskBps || 0; valB = b.diskBps || 0; }
    else if (sortBy === "pid") { valA = a.pid; valB = b.pid; }
    else if (sortBy === "user") { valA = a.user.toLowerCase(); valB = b.user.toLowerCase(); }
    else { valA = a.name.toLowerCase(); valB = b.name.toLowerCase(); }

    if (valA < valB) return isDesc ? 1 : -1;
    if (valA > valB) return isDesc ? -1 : 1;
    if (a.cpu !== b.cpu) return b.cpu - a.cpu;
    return a.pid - b.pid;
  });

  return copy;
}

function buildKillCommand(pid, force, useSudo) {
  var p = parseInt(pid, 10);
  if (isNaN(p) || p <= 1) return null;
  var sig = force ? "-9" : "-15";
  return useSudo ? ["sudo", "-S", "-p", "", "kill", sig, String(p)] : ["kill", sig, String(p)];
}

if (typeof module !== 'undefined' && module.exports) {
  var tc = {};
  try { tc = require("./TaskControl.js"); } catch (e) {}
  module.exports = {
    buildProcessScanScript: buildProcessScanScript,
    parseSystemHeaderStats: parseSystemHeaderStats,
    parseProcessOutput: parseProcessOutput,
    groupTasksByApp: groupTasksByApp,
    filterTasks: filterTasks,
    sortTasks: sortTasks,
    buildKillCommand: buildKillCommand,
    buildOpenFileLocationCommand: tc.buildOpenFileLocationCommand,
    buildGetProcessDetailsScript: tc.buildGetProcessDetailsScript,
    parseProcessDetails: tc.parseProcessDetails,
    formatBytes: formatBytes
  };
}
