// Sorter.js — Category filtering (#12, #15), text searching, column-header sorting, and pinned priority (#30)

function filterItems(items, category, query) {
  if (!items || !Array.isArray(items)) return [];
  var cat = (category || "all").toLowerCase();
  var q = (query || "").trim().toLowerCase();

  return items.filter(function(item) {
    if (cat === "desktop") {
      if (!item.isDesktop || item.isWebApp) return false;
    } else if (cat === "system") {
      if (item.category !== "system") return false;
    } else if (cat === "aur") {
      if (!item.isAur && item.category !== "aur") return false;
    } else if (cat === "webapp") {
      if (!item.isWebApp && item.category !== "webapp") return false;
    } else if (cat === "flatpak") {
      if (item.category !== "flatpak" && item.category !== "appimage") return false;
    } else if (cat === "large") {
      if ((item.size || 0) < 100 * 1024 * 1024) return false;
    } else if (cat === "unused") {
      if (!item.isUnused) return false;
    }

    if (q.length > 0) {
      var nameMatch = item.name && item.name.toLowerCase().indexOf(q) !== -1;
      var pkgMatch = item.pkg && item.pkg.toLowerCase().indexOf(q) !== -1;
      var descMatch = item.description && item.description.toLowerCase().indexOf(q) !== -1;
      var execMatch = item.exec && item.exec.toLowerCase().indexOf(q) !== -1;
      if (!nameMatch && !pkgMatch && !descMatch && !execMatch) {
        return false;
      }
    }

    return true;
  });
}

function sortItems(items, sortBy, sortOrder, pinnedMap) {
  if (!items || !Array.isArray(items)) return [];
  var mode = sortBy || "size";
  var isAsc = sortOrder === "asc";
  var pins = (pinnedMap && typeof pinnedMap === "object") ? pinnedMap : {};
  var copy = items.slice(0);

  copy.sort(function(a, b) {
    // Pinned items (#30) always float to top
    var aPin = !!(pins[a.pkg] || pins[a.id] || a.pinned);
    var bPin = !!(pins[b.pkg] || pins[b.id] || b.pinned);
    if (aPin !== bPin) return aPin ? -1 : 1;

    var diff = 0;
    if (mode === "size") {
      diff = (a.size || 0) - (b.size || 0);
    } else if (mode === "userdata") {
      diff = (a.userDataBytes || 0) - (b.userDataBytes || 0);
    } else if (mode === "total") {
      diff = (a.totalFootprintBytes || a.size || 0) - (b.totalFootprintBytes || b.size || 0);
    } else if (mode === "name") {
      var aName = (a.name || a.pkg || "").toLowerCase();
      var bName = (b.name || b.pkg || "").toLowerCase();
      diff = aName.localeCompare(bName);
    } else if (mode === "category") {
      var aCat = (a.category || "").toLowerCase();
      var bCat = (b.category || "").toLowerCase();
      diff = aCat.localeCompare(bCat);
    } else if (mode === "version") {
      var aVer = (a.version || "").toLowerCase();
      var bVer = (b.version || "").toLowerCase();
      diff = aVer.localeCompare(bVer);
    } else if (mode === "date") {
      var aDate = a.installDate ? new Date(a.installDate).getTime() : 0;
      var bDate = b.installDate ? new Date(b.installDate).getTime() : 0;
      diff = aDate - bDate;
    } else if (mode === "update") {
      var aUp = a.buildDate ? new Date(a.buildDate).getTime() : 0;
      var bUp = b.buildDate ? new Date(b.buildDate).getTime() : 0;
      diff = aUp - bUp;
    }

    if (mode === "size" || mode === "userdata" || mode === "total" || mode === "date" || mode === "update") {
      return isAsc ? diff : -diff;
    }

    return isAsc ? diff : (sortOrder === "desc" ? -diff : diff);
  });

  return copy;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    filterItems: filterItems,
    sortItems: sortItems
  };
}
