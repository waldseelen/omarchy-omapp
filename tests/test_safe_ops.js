// Unit tests for SafeOps.js
const assert = require("assert");
const SafeOps = require("../script/SafeOps.js");

const mockHome = "/home/hp";

console.log("Testing SafeOps...");

// Test path normalization
assert.strictEqual(SafeOps.normalizePath("/home/hp//.config/"), "/home/hp/.config");
assert.strictEqual(SafeOps.normalizePath("/"), "/");

// Test relative path helper
assert.strictEqual(SafeOps.getRelativePath("/home/hp/.config/app", mockHome), ".config/app");
assert.strictEqual(SafeOps.getRelativePath("/usr/bin/app", mockHome), null);

// Test validation - System Blacklist
assert.strictEqual(SafeOps.validateLeftoverPath("/", mockHome).valid, false);
assert.strictEqual(SafeOps.validateLeftoverPath("/etc", mockHome).valid, false);
assert.strictEqual(SafeOps.validateLeftoverPath("/usr/bin", mockHome).valid, false);

// Test validation - Traversal Attack
assert.strictEqual(SafeOps.validateLeftoverPath("/home/hp/.config/../.bashrc", mockHome).valid, false);

// Test validation - User Home Root & Protected Directories
assert.strictEqual(SafeOps.validateLeftoverPath("/home/hp", mockHome).valid, false);
assert.strictEqual(SafeOps.validateLeftoverPath("/home/hp/.config", mockHome).valid, false);
assert.strictEqual(SafeOps.validateLeftoverPath("/home/hp/.local", mockHome).valid, false);
assert.strictEqual(SafeOps.validateLeftoverPath("/home/hp/.cache", mockHome).valid, false);
assert.strictEqual(SafeOps.validateLeftoverPath("/home/hp/.config/hypr", mockHome).valid, false);
assert.strictEqual(SafeOps.validateLeftoverPath("/home/hp/.config/omarchy", mockHome).valid, false);
assert.strictEqual(SafeOps.validateLeftoverPath("/home/hp/.bashrc", mockHome).valid, false);

// Test validation - Valid Leftover Paths
const validConfig = SafeOps.validateLeftoverPath("/home/hp/.config/obsidian", mockHome);
assert.strictEqual(validConfig.valid, true);
assert.strictEqual(validConfig.relative, ".config/obsidian");

const validCache = SafeOps.validateLeftoverPath("/home/hp/.cache/google-chrome", mockHome);
assert.strictEqual(validCache.valid, true);

const validDotdir = SafeOps.validateLeftoverPath("/home/hp/.vscode", mockHome);
assert.strictEqual(validDotdir.valid, true);

// Test formatBytes
assert.strictEqual(SafeOps.formatBytes(0), "0 B");
assert.strictEqual(SafeOps.formatBytes(1024), "1.0 KiB");
assert.strictEqual(SafeOps.formatBytes(1048576), "1.0 MiB");
assert.strictEqual(SafeOps.formatBytes(1073741824), "1.0 GiB");

// Test parsePacmanSize
assert.strictEqual(SafeOps.parsePacmanSize("5.10 MiB"), 5347738);
assert.strictEqual(SafeOps.parsePacmanSize("602.93 KiB"), 617400);
assert.strictEqual(SafeOps.parsePacmanSize("1.50 GiB"), 1610612736);

// Test buildBackupCommand
const backup = SafeOps.buildBackupCommand(["/home/hp/.config/obsidian", "/etc/passwd"], "obsidian", mockHome);
assert.strictEqual(backup.validPaths.length, 1);
assert.strictEqual(backup.validPaths[0], "/home/hp/.config/obsidian");
assert.ok(backup.command.includes("tar -czf"));
assert.ok(backup.command.includes("obsidian-"));

// Test buildPurgeCommand
const purge = SafeOps.buildPurgeCommand(["/home/hp/.config/obsidian", "/home/hp"], mockHome);
assert.strictEqual(purge.validPaths.length, 1);
assert.strictEqual(purge.command, "rm -rf -- '/home/hp/.config/obsidian'");

console.log("SafeOps tests passed! ✅");
