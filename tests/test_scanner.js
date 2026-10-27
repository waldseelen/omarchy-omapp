// Unit tests for Scanner.js
const assert = require("assert");
const Scanner = require("../script/Scanner.js");

console.log("Testing Scanner...");

const mockPacmanBlock = [
  "Name            : bat",
  "Version         : 0.26.1-3",
  "Description     : Cat clone with syntax highlighting",
  "Installed Size  : 5.10 MiB",
  "Install Date    : Mon 19 Oct 2026 06:18:35 AM +03",
  "Build Date      : Sun 20 Sep 2026 04:19:49 PM +03",
  "Packager        : George Hu",
  "URL             : https://github.com/sharkdp/bat",
  "Licenses        : Apache-2.0",
  "Depends On      : glibc libgit2",
  "Required By     : None",
  "",
  "Name            : ripgrep",
  "Version         : 14.1.1-1",
  "Description     : Fast search tool",
  "Installed Size  : 4.20 MiB",
  "Install Date    : Mon 19 Oct 2026 06:18:35 AM +03",
  "Build Date      : Sun 20 Sep 2026 04:19:49 PM +03",
  "Packager        : Arch Packager",
  "URL             : https://github.com/BurntSushi/ripgrep",
  "Licenses        : MIT",
  "Depends On      : glibc",
  "Required By     : None"
].join("\n");

const pkgs = Scanner.parsePacmanBlock(mockPacmanBlock);
assert.ok(pkgs.bat);
assert.strictEqual(pkgs.bat.Name, "bat");
assert.strictEqual(pkgs.bat.Version, "0.26.1-3");
assert.strictEqual(pkgs.bat["Installed Size"], "5.10 MiB");

const mockFullOutput = [
  "===AUR_START===",
  "my-aur-tool",
  "===AUR_END===",
  "===DESKTOP_START===",
  "/usr/share/applications/bat-gui.desktop\tBat GUI\tbat-icon\tbat --gui\tUtility;\tA gui for bat",
  "===DESKTOP_END===",
  "===PACMAN_START===",
  mockPacmanBlock,
  "===PACMAN_END==="
].join("\n");

const unified = Scanner.parseInventory(mockFullOutput);
assert.strictEqual(unified.length, 2);

// bat had a desktop entry -> category: desktop
const batItem = unified.find(i => i.pkg === "bat");
assert.ok(batItem);
assert.strictEqual(batItem.category, "desktop");
assert.strictEqual(batItem.size, 5347738);

// ripgrep had NO desktop entry -> category: system
const rgItem = unified.find(i => i.pkg === "ripgrep");
assert.ok(rgItem);
assert.strictEqual(rgItem.category, "system");
assert.strictEqual(rgItem.size, 4404019);

console.log("Scanner tests passed! ✅");
