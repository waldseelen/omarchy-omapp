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

// Test orphan dotfiles scanner includes prefix, /usr/bin, .desktop Exec/WMClass, Flatpak/AppImage, and gaming/runtime guards
const orphanScan = LeftoverHunter.buildOrphanDotfilesScanScript(mockHome);
assert.strictEqual(orphanScan[0], "bash");
assert.ok(orphanScan[2].includes('/usr/bin/*'));
assert.ok(orphanScan[2].includes('StartupWMClass'));
assert.ok(orphanScan[2].includes('flatpak'));
assert.ok(orphanScan[2].includes('first="${p%%-*}"'));
assert.ok(orphanScan[2].includes('heroic'));
assert.ok(orphanScan[2].includes('legendary'));
assert.ok(orphanScan[2].includes('bn_prefix="${bn%%[-_]*}"'));
assert.ok(orphanScan[2].includes('ORPHAN'));

// Test that ORPHAN scan defaults ~/.config items to selected: false while ~/.cache items remain selected: true
const orphanParsed = LeftoverHunter.parseScanOutput([
  "/home/hp/.config/oldapp\t10240\tORPHAN",
  "/home/hp/.cache/oldapp\t20480\tORPHAN"
].join("\n"), mockHome);
assert.strictEqual(orphanParsed.length, 2);
assert.strictEqual(orphanParsed[0].category, "config");
assert.strictEqual(orphanParsed[0].selected, false);
assert.strictEqual(orphanParsed[1].category, "cache");
assert.strictEqual(orphanParsed[1].selected, true);

console.log("LeftoverHunter tests passed! ✅");
