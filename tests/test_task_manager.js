// test_task_manager.js — Unit test for TaskManager logic
const assert = require("assert");
const TaskManager = require("../script/TaskManager.js");

console.log("Testing TaskManager...");

// 1. Process output parsing
const samplePsOutput = [
  "===PS_START===",
  "   1017 hp        9.1  9.4 1476544 MainThread",
  "  13336 hp        4.5  2.2  345888 brave",
  "   3778 root      4.1  3.5  548760 systemd-journal",
  "      1 root      0.0  0.1   12000 systemd",
  "===PS_END===",
  "===GPU_START===",
  "13336, 120",
  "===GPU_END==="
].join("\n");

const tasks = TaskManager.parseProcessOutput(samplePsOutput, "hp");
assert.strictEqual(tasks.length, 4, "Should parse 4 processes");
assert.strictEqual(tasks[0].pid, 1017);
assert.strictEqual(tasks[0].name, "MainThread");
assert.strictEqual(tasks[0].user, "hp");
assert.strictEqual(tasks[0].cpu, 9.1);
assert.strictEqual(tasks[0].isMine, true);
assert.strictEqual(tasks[2].isMine, false);

// Check GPU mapping (NVIDIA + DRM fdinfo + delta GPU %)
assert.strictEqual(tasks[1].pid, 13336);
assert.strictEqual(tasks[1].gpuMemMiB, 120);
assert.strictEqual(tasks[1].gpuFormatted, "120 MiB");

// 1b. DRM fdinfo GPU % and VRAM parsing with two snapshots
const gpuState = {};
const snap1 = [
  "===PS_START===",
  "  1017 hp        9.1  9.4 1476544 MainThread",
  "  1133 hp        2.0  1.5  218000 Hyprland",
  "===PS_END===",
  "===DRM_START===",
  "1017\t5\t146052\t119780\t1000000000",
  "1017\t5\t146052\t119780\t1000000000", // duplicate fd for same drm-client-id 5 must deduplicate
  "1133\t12\t12\t2048\t500000000",
  "===DRM_END==="
].join("\n");

const snap2 = [
  "===PS_START===",
  "  1017 hp        9.1  9.4 1476544 MainThread",
  "  1133 hp        2.0  1.5  218000 Hyprland",
  "===PS_END===",
  "===DRM_START===",
  "1017\t5\t146052\t119780\t1500000000", // +500ms engine time over 2000ms wall time = 25.0% GPU
  "1133\t12\t12\t2048\t520000000",       // +20ms engine time over 2000ms wall time = 1.0% GPU
  "===DRM_END==="
].join("\n");

TaskManager.parseProcessOutput(snap1, "hp", gpuState, 1000);
const drmTasks = TaskManager.parseProcessOutput(snap2, "hp", gpuState, 3000);
assert.strictEqual(drmTasks[0].gpuPercent, 25.0, "MainThread should have 25.0% GPU usage");
assert.strictEqual(drmTasks[0].gpuFormatted, "25.0%");
assert.strictEqual(drmTasks[0].gpuMemMiB, 143, "MainThread VRAM KiB should convert to ~143 MiB");
assert.strictEqual(drmTasks[1].gpuPercent, 1.0, "Hyprland should have 1.0% GPU usage");

const sortedDrmByGpu = TaskManager.sortTasks(drmTasks, "gpu", "desc");
assert.strictEqual(sortedDrmByGpu[0].pid, 1017);
const sortedDrmByGpuAsc = TaskManager.sortTasks(drmTasks, "gpu", "asc");
assert.strictEqual(sortedDrmByGpuAsc[0].pid, 1133);

// 2. Filter tasks
const userTasks = TaskManager.filterTasks(tasks, "", "user", "hp");
assert.strictEqual(userTasks.length, 2, "Should find 2 user tasks for hp");

const braveTasks = TaskManager.filterTasks(tasks, "brave", "all", "hp");
assert.strictEqual(braveTasks.length, 1);
assert.strictEqual(braveTasks[0].pid, 13336);

// 3. Sort tasks
const sortedByMem = TaskManager.sortTasks(tasks, "mem", "desc");
assert.strictEqual(sortedByMem[0].pid, 1017, "Highest memory should be first");

const sortedByGpu = TaskManager.sortTasks(tasks, "gpu", "desc");
assert.strictEqual(sortedByGpu[0].pid, 13336, "Highest GPU memory should be first");

// 4. Kill command generation
const killTerm = TaskManager.buildKillCommand(13336, false, false);
assert.deepStrictEqual(killTerm, ["kill", "-15", "13336"]);

const killForceSudo = TaskManager.buildKillCommand(3778, true, true);
assert.deepStrictEqual(killForceSudo, ["sudo", "-S", "-p", "", "kill", "-9", "3778"]);

// Protection for PID 1
assert.strictEqual(TaskManager.buildKillCommand(1, true, true), null, "PID 1 must be protected");

// 5. Open file location command
const openLocCmd = TaskManager.buildOpenFileLocationCommand(13336);
assert(openLocCmd[2].includes("/proc/13336/exe"), "Command should inspect /proc/13336/exe");

// 6. Process details parsing
const sampleDetails = [
  "EXE\t/usr/lib/brave-bin/brave",
  "CWD\t/home/hp",
  "CMD\tbrave --enable-features=UseOzonePlatform",
  "PKG\tbrave-bin"
].join("\n");

const details = TaskManager.parseProcessDetails(sampleDetails);
assert.strictEqual(details.exe, "/usr/lib/brave-bin/brave");
assert.strictEqual(details.pkg, "brave-bin");
assert.strictEqual(details.cwd, "/home/hp");

// 7. Process Grouping (#1) & Pinned Sorting (#30) & System Header Telemetry (#2)
const grouped = TaskManager.groupTasksByApp([
  { pid: 100, name: "brave", user: "hp", cpu: 4.0, mem: 1.0, rss: 1000, gpuPercent: 2.0, gpuMemMiB: 50, diskBps: 1024, state: "S", isFrozen: false, nice: 0, isMine: true },
  { pid: 101, name: "brave", user: "hp", cpu: 6.0, mem: 2.0, rss: 2000, gpuPercent: 3.0, gpuMemMiB: 30, diskBps: 2048, state: "S", isFrozen: false, nice: 0, isMine: true },
  { pid: 200, name: "ghostty", user: "hp", cpu: 1.0, mem: 0.5, rss: 500, gpuPercent: 0, gpuMemMiB: 10, diskBps: 0, state: "S", isFrozen: false, nice: 0, isMine: true }
], { brave: true });
assert.strictEqual(grouped.length, 4, "Should have 1 brave group + 2 expanded brave children + 1 ghostty");
assert.strictEqual(grouped[0].groupCount, 2);
assert.strictEqual(grouped[0].cpu, 10.0);
assert.strictEqual(grouped[0].gpuMemMiB, 80);

const pinnedSorted = TaskManager.sortTasks(tasks, "cpu", "desc", { systemd: true });
assert.strictEqual(pinnedSorted[0].name, "systemd", "Pinned process must float to top");

const cpuPrev = { total: 0, idle: 0 };
TaskManager.parseSystemHeaderStats("===SYS_START===\ncpu  1000 0 500 8500 0 0 0 0 0 0\nMemTotal: 16384000 kB\nMemAvailable: 8192000 kB\n18\n54000\n===SYS_END===", cpuPrev);
const sys2 = TaskManager.parseSystemHeaderStats("===SYS_START===\ncpu  1200 0 600 9200 0 0 0 0 0 0\nMemTotal: 16384000 kB\nMemAvailable: 8192000 kB\n24\n58000\n===SYS_END===", cpuPrev);
assert.strictEqual(sys2.cpuPercent, 30.0);
assert.strictEqual(sys2.memPercent, 50);
assert.strictEqual(sys2.gpuPercent, 24);
assert.strictEqual(sys2.tempC, 58);

console.log("TaskManager tests passed! ✅");
