// ModelSync.js — Non-destructive in-place ListModel synchronization & context menu builders for Omapp.qml

function syncAppModel(model, sorted, runningPids, pinnedApps, batchMap) {
  if (!model || !Array.isArray(sorted)) return;
  if (model.count > sorted.length) {
    model.remove(sorted.length, model.count - sorted.length);
  }
  var pids = runningPids || {};
  var pins = pinnedApps || {};
  var batch = batchMap || {};

  for (var i = 0; i < sorted.length; i++) {
    var item = sorted[i];
    var isRun = !!pids[item.pkg] || !!(item.name && pids[item.name.toLowerCase()]);
    var isPin = !!pins[item.pkg];
    item.pinned = isPin;
    var rowObj = {
      name: String(item.name || item.pkg || ""),
      pkg: String(item.pkg || ""),
      version: String(item.version || ""),
      icon: String(item.icon || "application-x-executable"),
      category: String(item.category || "desktop"),
      sizeFormatted: String(item.sizeFormatted || "0 B"),
      userDataFormatted: String(item.userDataFormatted || "0 B"),
      running: isRun,
      pinned: isPin,
      isProtected: Boolean(item.isProtected),
      isUnused: Boolean(item.isUnused),
      checked: Boolean(batch[item.pkg])
    };
    if (i < model.count) model.set(i, rowObj);
    else model.append(rowObj);
  }
}

function syncTaskModel(model, sorted, pinnedTasks) {
  if (!model || !Array.isArray(sorted)) return;
  if (model.count > sorted.length) {
    model.remove(sorted.length, model.count - sorted.length);
  }
  var pins = pinnedTasks || {};

  for (var i = 0; i < sorted.length; i++) {
    var t = sorted[i];
    var isPin = !!(pins[t.name] || pins[String(t.pid)]);
    t.pinned = isPin;
    var rowObj = {
      pid: Number(t.pid || 0),
      name: String(t.name || ""),
      user: String(t.user || ""),
      cpu: Number(t.cpu || 0),
      cpuFormatted: String(t.cpuFormatted || "0.0%"),
      gpu: Number(t.gpu || 0),
      gpuPercent: Number(t.gpuPercent || 0),
      gpuMemMiB: Number(t.gpuMemMiB || 0),
      gpuFormatted: String(t.gpuFormatted || "0.0%"),
      rss: Number(t.rss || 0),
      rssFormatted: String(t.rssFormatted || "0 B"),
      diskBps: Number(t.diskBps || 0),
      diskFormatted: String(t.diskFormatted || "0 B/s"),
      isMine: Boolean(t.isMine),
      isFrozen: Boolean(t.isFrozen),
      pinned: isPin,
      groupCount: Number(t.groupCount || 1)
    };
    if (i < model.count) model.set(i, rowObj);
    else model.append(rowObj);
  }
}

function syncServiceModel(model, sorted) {
  if (!model || !Array.isArray(sorted)) return;
  if (model.count > sorted.length) {
    model.remove(sorted.length, model.count - sorted.length);
  }
  for (var i = 0; i < sorted.length; i++) {
    var s = sorted[i];
    var rowObj = {
      unitId: String(s.id || ""),
      name: String(s.name || ""),
      scope: String(s.scope || "user"),
      state: String(s.state || ""),
      subState: String(s.subState || ""),
      bootMs: Number(s.bootMs || 0),
      bootFormatted: String(s.bootFormatted || "0 ms"),
      impact: String(s.impact || "Low")
    };
    if (i < model.count) model.set(i, rowObj);
    else model.append(rowObj);
  }
}

function buildAppContextActions(app) {
  if (!app) return [];
  var acts = [
    { id: "pin", icon: "󰐃", label: app.pinned ? "Unpin Application" : "Pin to Top" },
    { id: "config", icon: "󰉋", label: "Open ~/.config Folder" }
  ];
  if (app.isDesktop) acts.unshift({ id: "launch", icon: "󰐊", label: "Launch Application" });
  if (!app.isProtected) {
    acts.push({ id: "batch", icon: "☑", label: "Toggle Batch Selection" });
    acts.push({ id: "uninstall", icon: "󰩺", label: "Deep Uninstall", danger: true });
  }
  return acts;
}

function buildTaskContextActions(task) {
  if (!task) return [];
  return [
    { id: "pin", icon: "󰐃", label: task.pinned ? "Unpin Process" : "Pin to Top" },
    { id: "freeze", icon: "󰏤", label: task.isFrozen ? "Resume Process (SIGCONT)" : "Freeze Process (SIGSTOP)" },
    { id: "renice_high", icon: "󰓅", label: "Priority: High (-10)" },
    { id: "renice_low", icon: "󰾆", label: "Priority: Low (+10)" },
    { id: "folder", icon: "󰉋", label: "Open Executable Location" },
    { id: "kill", icon: "󰅙", label: "End Task (SIGTERM)", danger: true },
    { id: "force_kill", icon: "󰚌", label: "Force Kill (SIGKILL)", danger: true }
  ];
}

function buildServiceContextActions(srv) {
  if (!srv) return [];
  if (srv.scope === "xdg-autostart") {
    return [{ id: srv.state === "enabled" ? "disable" : "enable", icon: "󰒓", label: srv.state === "enabled" ? "Disable Autostart" : "Enable Autostart" }];
  }
  return [
    { id: "start", icon: "󰐊", label: "Start Unit" },
    { id: "restart", icon: "󰜉", label: "Restart Unit" },
    { id: "stop", icon: "󰅙", label: "Stop Unit", danger: true },
    { id: "enable", icon: "✓", label: "Enable at Boot" },
    { id: "disable", icon: "✕", label: "Disable at Boot", danger: true }
  ];
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    syncAppModel: syncAppModel,
    syncTaskModel: syncTaskModel,
    syncServiceModel: syncServiceModel,
    buildAppContextActions: buildAppContextActions,
    buildTaskContextActions: buildTaskContextActions,
    buildServiceContextActions: buildServiceContextActions
  };
}
