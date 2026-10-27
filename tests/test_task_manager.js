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

// Check GPU mapping
assert.strictEqual(tasks[1].pid, 13336);
assert.strictEqual(tasks[1].gpu, 120);
assert.strictEqual(tasks[1].gpuFormatted, "120 MiB");

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
assert.deepStrictEqual(killForceSudo, ["sudo", "-n", "kill", "-9", "3778"]);

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

console.log("TaskManager tests passed! ✅");
