// Unit tests for LeftoverHunter.js
const assert = require("assert");
const LeftoverHunter = require("../script/LeftoverHunter.js");
const mockHome = "/home/hp";

console.log("Testing LeftoverHunter...");

// Test candidate slug generation
const slugs = LeftoverHunter.generateCandidateSlugs({
  pkg: "visual-studio-code-bin",
  exec: "/usr/bin/code --unity-launch",
  name: "Visual Studio Code",
  desktopFile: "code.desktop"
});

assert.ok(slugs.includes("visual-studio-code"));
assert.ok(slugs.includes("code"));
assert.ok(slugs.includes("visualstudiocode"));

// Test scan script builder
const scan = LeftoverHunter.buildScanScript({ pkg: "obsidian", name: "Obsidian" }, mockHome);
assert.ok(scan.argv);
assert.strictEqual(scan.argv[0], "bash");
assert.ok(scan.argv[2].includes("obsidian"));

// Test output parsing
const mockOutput = [
  "/home/hp/.config/obsidian\t117068689",
  "/home/hp/.cache/obsidian\t2048",
  "/home/hp/.config/autostart/obsidian.desktop\t512",
  "/home/hp\t9999999", // Unsafe, must be filtered!
  "/etc/obsidian\t1000" // Unsafe, must be filtered!
].join("\n");

const items = LeftoverHunter.parseScanOutput(mockOutput, mockHome);
assert.strictEqual(items.length, 3);
assert.strictEqual(items[0].relative, ".config/obsidian");
assert.strictEqual(items[0].category, "config");
assert.strictEqual(items[0].size, 117068689);
assert.strictEqual(items[0].selected, true);

assert.strictEqual(items[1].category, "cache");
assert.strictEqual(items[2].category, "autostart");

console.log("LeftoverHunter tests passed! ✅");
