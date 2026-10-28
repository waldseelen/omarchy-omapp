// Unit tests for SudoKeeper.js
const assert = require("assert");
const SudoKeeper = require("../script/SudoKeeper.js");

console.log("Testing SudoKeeper...");

assert.deepStrictEqual(SudoKeeper.getStatusCheckCommand(), ["sudo", "-n", "true"]);
assert.deepStrictEqual(SudoKeeper.getAuthCommand(), ["sudo", "-S", "-p", "", "-v"]);

const scriptWithPid = SudoKeeper.getKeepaliveScript(1234);
assert.ok(scriptWithPid.includes("kill -0 1234"));
assert.ok(scriptWithPid.includes("sudo -n -v"));

const scriptFallback = SudoKeeper.getKeepaliveScript(0);
assert.ok(scriptFallback.includes("while true; do"));

const validUninstall = SudoKeeper.buildUninstallCommand("bat");
assert.deepStrictEqual(validUninstall, ["sudo", "-S", "-p", "", "pacman", "-Rns", "--noconfirm", "bat"]);

const invalidUninstall = SudoKeeper.buildUninstallCommand("bat; rm -rf /");
assert.strictEqual(invalidUninstall, null);

const orphanCmd = SudoKeeper.buildOrphanCleanCommand();
assert.strictEqual(orphanCmd[0], "sudo");
assert.ok(orphanCmd[6].includes("pacman -Qtdq"));

console.log("SudoKeeper tests passed! ✅");
