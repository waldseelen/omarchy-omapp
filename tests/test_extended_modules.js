// Unit tests for TaskControl.js, StartupServices.js, JanitorOps.js, and StateStore.js
const assert = require("assert");
const TaskControl = require("../script/TaskControl.js");
const StartupServices = require("../script/StartupServices.js");
const JanitorOps = require("../script/JanitorOps.js");
const StateStore = require("../script/StateStore.js");

console.log("Testing TaskControl, StartupServices, JanitorOps, StateStore...");

// 1. TaskControl (#3 & #4)
assert.deepStrictEqual(TaskControl.buildFreezeCommand(1234, true, false), ["kill", "-STOP", "1234"]);
assert.deepStrictEqual(TaskControl.buildFreezeCommand(1234, false, true), ["sudo", "-n", "kill", "-CONT", "1234"]);
assert.strictEqual(TaskControl.buildFreezeCommand(1, true, true), null);

assert.deepStrictEqual(TaskControl.buildReniceCommand(1234, -10, false), ["sudo", "-n", "renice", "-n", "-10", "-p", "1234"]);
assert.deepStrictEqual(TaskControl.buildReniceCommand(1234, 10, false), ["renice", "-n", "10", "-p", "1234"]);
assert.deepStrictEqual(TaskControl.buildAffinityCommand(1234, "0-3", false), ["taskset", "-pc", "0-3", "1234"]);
assert.strictEqual(TaskControl.buildAffinityCommand(1234, "invalid;rm", false), null);

// 2. StartupServices (#6, #7, #8)
assert.strictEqual(StartupServices.parseBlameTimeMs("1.250s"), 1250);
assert.strictEqual(StartupServices.parseBlameTimeMs("340ms"), 340);
assert.strictEqual(StartupServices.parseBlameTimeMs("1min 2.000s"), 62000);

const mockStartupRaw = [
  "===USER_UNITS_START===",
  "pipewire.service\tactive\trunning",
  "===USER_UNITS_END===",
  "===SYS_UNITS_START===",
  "bluetooth.service\tactive\trunning",
  "===SYS_UNITS_END===",
  "===BLAME_START===",
  "1.420s bluetooth.service",
  "120ms pipewire.service",
  "===BLAME_END===",
  "===AUTOSTART_START===",
  "HYPR\t12:exec-once = waybar",
  "===AUTOSTART_END==="
].join("\n");

const startupItems = StartupServices.parseStartupOutput(mockStartupRaw);
assert.strictEqual(startupItems.length, 3);
const bt = startupItems.find(i => i.unit === "bluetooth.service");
assert.strictEqual(bt.bootMs, 1420);
assert.ok(bt.impactFormatted.startsWith("High"));

const sortedStartup = StartupServices.sortStartupItems(startupItems, "impact", "desc");
assert.strictEqual(sortedStartup[0].unit, "bluetooth.service");

assert.deepStrictEqual(
  StartupServices.buildServiceActionCommand(bt, "restart", true),
  ["sudo", "-n", "systemctl", "restart", "bluetooth.service"]
);

// 3. JanitorOps (#16, #21-#25)
const mockJanitorRaw = [
  "STATS\t4\t1.2G\t450M\t320.5M\t204800\t512000\tImages: 1.4GB\t2\t1",
  "===BACKUPS_START===",
  "/home/hp/.local/share/omapp/backups/obsidian-20261028.tar.gz\t1048576\t2026-10-28 12:00:00",
  "===BACKUPS_END==="
].join("\n");

const jStats = JanitorOps.parseJanitorStats(mockJanitorRaw);
assert.strictEqual(jStats.orphanText, "4 unneeded packages");
assert.strictEqual(jStats.pacmanCache, "1.2G");
assert.strictEqual(jStats.journalSize, "320.5M");
assert.strictEqual(jStats.backups.length, 1);
assert.strictEqual(jStats.backups[0].name, "obsidian-20261028.tar.gz");
assert.strictEqual(jStats.backups[0].size, jStats.backups[0].sizeFormatted);
assert.strictEqual(JanitorOps.parseJanitorStats("STATS\t0\t12\t8\t0B\t4\t8\t\t0\t0").yay, "0 B");
assert.ok(JanitorOps.buildCleanCommand("yay")[2].indexOf("CLEAN_OK:") !== -1);
assert.ok(JanitorOps.buildCleanCommand("dev")[2].indexOf("_npx") !== -1);

// 4. StateStore (#28 & #30)
let pinMap = {};
pinMap = StateStore.togglePinMap(pinMap, "brave");
assert.strictEqual(pinMap.brave, true);
pinMap = StateStore.togglePinMap(pinMap, "brave");
assert.strictEqual(pinMap.brave, undefined);

const prefs = StateStore.parsePreferences('{"groupTasks":true,"pinnedApps":{"bat":true}}');
assert.strictEqual(prefs.groupTasks, true);
assert.strictEqual(prefs.pinnedApps.bat, true);

console.log("TaskControl, StartupServices, JanitorOps, StateStore tests passed! ✅");
