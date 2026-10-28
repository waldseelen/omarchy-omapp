// StateStore.js — Persistent preferences for pinned apps/tasks (#30) and resizable column widths (#28)

function defaultPreferences() {
  return {
    pinnedApps: {},
    pinnedTasks: {},
    groupTasks: false,
    appColWidths: { type: 62, version: 68, userdata: 66, size: 68 },
    taskColWidths: { pid: 52, cpu: 58, gpu: 64, disk: 68, ram: 68 }
  };
}

function defaultPrefs() {
  return defaultPreferences();
}

function parsePreferences(rawJson) {
  var defs = defaultPreferences();
  if (!rawJson || typeof rawJson !== "string") return defs;
  try {
    var parsed = JSON.parse(rawJson);
    if (!parsed || typeof parsed !== "object") return defs;
    if (parsed.pinnedApps && typeof parsed.pinnedApps === "object") defs.pinnedApps = parsed.pinnedApps;
    if (parsed.pinnedTasks && typeof parsed.pinnedTasks === "object") defs.pinnedTasks = parsed.pinnedTasks;
    if (typeof parsed.groupTasks === "boolean") defs.groupTasks = parsed.groupTasks;
    if (parsed.appColWidths && typeof parsed.appColWidths === "object") {
      Object.assign(defs.appColWidths, parsed.appColWidths);
    }
    if (parsed.taskColWidths && typeof parsed.taskColWidths === "object") {
      Object.assign(defs.taskColWidths, parsed.taskColWidths);
    }
  } catch (e) {}
  return defs;
}

function parsePrefs(rawJson) {
  return parsePreferences(rawJson);
}

function togglePinMap(mapObj, key) {
  var next = Object.assign({}, mapObj || {});
  if (!key) return next;
  if (next[key]) delete next[key];
  else next[key] = true;
  return next;
}

function buildLoadPrefsCommand(home) {
  var h = home || "$HOME";
  return ["bash", "-c", 'cat "' + h.replace(/"/g, "") + '/.local/state/omapp/preferences.json" 2>/dev/null || echo "{}"'];
}

function buildSavePreferencesCommand(prefsObj, home) {
  if (!home || typeof home !== "string") return null;
  var jsonStr = JSON.stringify(prefsObj || defaultPreferences());
  var safeJson = "'" + jsonStr.replace(/'/g, "'\\''") + "'";
  var stateDir = "'" + home.replace(/'/g, "'\\''") + "/.local/state/omapp'";
  return ["bash", "-c", "mkdir -p " + stateDir + " && printf '%s\\n' " + safeJson + " > " + stateDir + "/preferences.json"];
}

function buildSavePrefsCommand(prefsObj, home) {
  return buildSavePreferencesCommand(prefsObj, home);
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    defaultPreferences: defaultPreferences,
    defaultPrefs: defaultPrefs,
    parsePreferences: parsePreferences,
    parsePrefs: parsePrefs,
    togglePinMap: togglePinMap,
    buildLoadPrefsCommand: buildLoadPrefsCommand,
    buildSavePreferencesCommand: buildSavePreferencesCommand,
    buildSavePrefsCommand: buildSavePrefsCommand
  };
}
