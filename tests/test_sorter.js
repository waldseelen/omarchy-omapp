// Unit tests for Sorter.js
const assert = require("assert");
const Sorter = require("../script/Sorter.js");

console.log("Testing Sorter...");

const mockItems = [
  { id: "1", name: "Zotero", pkg: "zotero", category: "desktop", isDesktop: true, isWebApp: false, size: 200 * 1024 * 1024, description: "Research tool" },
  { id: "2", name: "Alacritty", pkg: "alacritty", category: "desktop", isDesktop: true, isWebApp: false, size: 10 * 1024 * 1024, description: "Terminal emulator" },
  { id: "3", name: "bat", pkg: "bat", category: "system", isDesktop: false, isWebApp: false, size: 5 * 1024 * 1024, description: "Cat clone" },
  { id: "4", name: "Discord Web", pkg: "discord", category: "webapp", isDesktop: true, isWebApp: true, size: 1024, description: "Web app" }
];

// Test category filter
const desktopOnly = Sorter.filterItems(mockItems, "desktop", "");
assert.strictEqual(desktopOnly.length, 2);

const systemOnly = Sorter.filterItems(mockItems, "system", "");
assert.strictEqual(systemOnly.length, 1);
assert.strictEqual(systemOnly[0].pkg, "bat");

const webappOnly = Sorter.filterItems(mockItems, "webapp", "");
assert.strictEqual(webappOnly.length, 1);

const largeOnly = Sorter.filterItems(mockItems, "large", "");
assert.strictEqual(largeOnly.length, 1);
assert.strictEqual(largeOnly[0].name, "Zotero");

// Test query search
const searchResult = Sorter.filterItems(mockItems, "all", "clone");
assert.strictEqual(searchResult.length, 1);
assert.strictEqual(searchResult[0].pkg, "bat");

// Test sort by size (descending)
const sortedBySize = Sorter.sortItems(mockItems, "size", "desc");
assert.strictEqual(sortedBySize[0].name, "Zotero");
assert.strictEqual(sortedBySize[sortedBySize.length - 1].name, "Discord Web");

// Test sort by name (ascending & descending)
const sortedByName = Sorter.sortItems(mockItems, "name", "asc");
assert.strictEqual(sortedByName[0].name, "Alacritty");
assert.strictEqual(sortedByName[sortedByName.length - 1].name, "Zotero");

const sortedByNameDesc = Sorter.sortItems(mockItems, "name", "desc");
assert.strictEqual(sortedByNameDesc[0].name, "Zotero");
assert.strictEqual(sortedByNameDesc[sortedByNameDesc.length - 1].name, "Alacritty");

// Test sort by category (ascending & descending)
const sortedByCatAsc = Sorter.sortItems(mockItems, "category", "asc");
assert.strictEqual(sortedByCatAsc[0].category, "desktop");
assert.strictEqual(sortedByCatAsc[sortedByCatAsc.length - 1].category, "webapp");

const sortedByCatDesc = Sorter.sortItems(mockItems, "category", "desc");
assert.strictEqual(sortedByCatDesc[0].category, "webapp");

console.log("Sorter tests passed! ✅");
