// JanitorOps.js — Expanded System Janitor (#21-#25) & Backup Restore (#16)

function buildJanitorScanScript() {
  var script = [
    'orphans=$(pacman -Qtdq 2>/dev/null | wc -l)',
    'packb=$(du -sk /var/cache/pacman/pkg 2>/dev/null | awk \'{s+=$1} END {print s+0}\')',
    'yaykb=$(du -sk "$HOME/.cache/yay" "$HOME/.cache/paru" 2>/dev/null | awk \'{s+=$1} END {print s+0}\')',
    'jrnlsz=$(journalctl --disk-usage 2>/dev/null | grep -oE "[0-9.]+[KMGTP]?B?" | head -n1 || echo "0 B")',
    'devkb=$(du -sk "$HOME/.npm/_cacache" "$HOME/.npm/_logs" "$HOME/.npm/_npx" "$HOME/.cache/pip" "$HOME/.cargo/registry/cache" "$HOME/.cache/go-build" "$HOME/.gradle/caches" 2>/dev/null | awk \'{s+=$1} END {print s+0}\')',
    'brwkb=$(du -sk "$HOME/.cache/BraveSoftware" "$HOME/.cache/chromium" "$HOME/.config/discord/Cache" "$HOME/.config/discord/GPUCache" "$HOME/.config/Spotify/Browser/Cache" "$HOME/.config/Code/Cache" "$HOME/.config/Code/CachedData" 2>/dev/null | awk \'{s+=$1} END {print s+0}\')',
    'dckr=$(if command -v docker >/dev/null 2>&1; then docker system df --format "{{.Type}}: {{.Reclaimable}}" 2>/dev/null | head -n 2 | tr "\\n" " "; else echo "Not running"; fi)',
    'symlinks=$(find "$HOME/.config" "$HOME/.local/share" -maxdepth 2 -xtype l 2>/dev/null | wc -l)',
    'pacnew=$(find /etc -maxdepth 2 \\( -name "*.pacnew" -o -name "*.pacsave" \\) 2>/dev/null | wc -l)',
    'daemons=0',
    'for pid in $(pgrep -x gpg-agent -x scdaemon 2>/dev/null); do',
    '  if tr "\\0" " " < "/proc/$pid/cmdline" 2>/dev/null | grep -qE -- "--homedir.*\\.cache"; then',
    '    daemons=$((daemons + 1))',
    '  fi',
    'done',
    'for pid in $(pgrep -x protonvpn -x protonvpn-cli -x proton-vpn 2>/dev/null); do',
    '  daemons=$((daemons + 1))',
    'done',
    'for pid in $(pgrep -x python -x python3 2>/dev/null); do',
    '  if tr "\\0" " " < "/proc/$pid/cmdline" 2>/dev/null | grep -qE -- "protonvpn|proton_vpn"; then',
    '    daemons=$((daemons + 1))',
    '  fi',
    'done',
    'if [ -d "$HOME/.cache/Proton" ] || [ -d "$HOME/.config/Proton" ]; then',
    '  if ! pacman -Qq proton-vpn-gtk-app protonvpn-cli protonvpn >/dev/null 2>&1; then',
    '    daemons=$((daemons + 1))',
    '  fi',
    'fi',
    'echo -e "STATS\\t$orphans\\t$packb\\t$yaykb\\t$jrnlsz\\t$devkb\\t$brwkb\\t$dckr\\t$symlinks\\t$pacnew\\t$daemons"',
    'echo "===BACKUPS_START==="',
    'for b in "$HOME/.local/share/omapp/backups"/*.tar.gz; do',
    '  [ -f "$b" ] || continue',
    '  bsz=$(stat -c "%s" "$b" 2>/dev/null || echo 0)',
    '  bmt=$(stat -c "%y" "$b" 2>/dev/null | cut -d. -f1 || echo "")',
    '  echo -e "$b\\t$bsz\\t$bmt"',
    'done',
    'echo "===BACKUPS_END==="'
  ].join("\n");

  return ["bash", "-c", script];
}

function formatKiB(kib) {
  var kVal = parseInt(kib, 10) || 0;
  // Empty directory metadata on ext4/btrfs is 4–16 KiB; treat <= 16 KiB as 0 B
  if (kVal <= 16) return "0 B";
  var bytes = kVal * 1024;
  var units = ["B", "KiB", "MiB", "GiB"];
  var i = Math.min(units.length - 1, Math.floor(Math.log(bytes) / Math.log(1024)));
  return (bytes / Math.pow(1024, i)).toFixed(1) + " " + units[i];
}

function parseSizeOrKiB(val) {
  if (!val) return "0 B";
  var s = String(val).trim();
  if (/^\d+$/.test(s)) return formatKiB(s);
  return s;
}

function parseJanitorStats(rawText) {
  var res = {
    orphanText: "0 unneeded packages",
    orphans: "0 unneeded packages",
    pacmanCache: "0 B",
    pacman: "0 B",
    yayCache: "0 B",
    yay: "0 B",
    journalSize: "0 B",
    journal: "0 B",
    devCacheSize: "0 B",
    dev: "0 B",
    browserCacheSize: "0 B",
    browser: "0 B",
    dockerStatus: "Clean / Inactive",
    docker: "Clean / Inactive",
    symlinks: 0,
    pacnew: 0,
    brokenSymlinksText: "0 broken links",
    daemons: "Clean / None",
    daemonsCount: 0,
    backups: []
  };
  if (!rawText || typeof rawText !== "string") return res;

  var lines = rawText.split("\n");
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (line.indexOf("STATS\t") === 0) {
      var p = line.split("\t");
      res.orphanText = (p[1] || "0") + " unneeded packages";
      res.orphans = (p[1] || "0") + " packages";
      res.pacmanCache = parseSizeOrKiB(p[2]);
      res.pacman = res.pacmanCache;
      res.yayCache = parseSizeOrKiB(p[3]);
      res.yay = res.yayCache;
      res.journalSize = p[4] || "0 B";
      res.journal = res.journalSize;
      res.devCacheSize = formatKiB(p[5]);
      res.dev = res.devCacheSize;
      res.browserCacheSize = formatKiB(p[6]);
      res.browser = res.browserCacheSize;
      res.dockerStatus = (p[7] && p[7].trim()) ? p[7].trim() : "Clean / Inactive";
      res.docker = res.dockerStatus;
      res.symlinks = parseInt(p[8], 10) || 0;
      res.pacnew = parseInt(p[9], 10) || 0;
      res.brokenSymlinksText = res.symlinks + " broken symlinks · " + res.pacnew + " .pacnew";
      var dCount = parseInt(p[10], 10) || 0;
      res.daemonsCount = dCount;
      res.daemons = dCount > 0 ? (dCount + (dCount === 1 ? " lingering daemon" : " lingering daemons")) : "Clean / None";
    }
  }

  var bStart = rawText.indexOf("===BACKUPS_START===");
  var bEnd = rawText.indexOf("===BACKUPS_END===");
  if (bStart !== -1 && bEnd !== -1 && bEnd > bStart) {
    var bBlock = rawText.slice(bStart + 19, bEnd).trim();
    if (bBlock) {
      var bLines = bBlock.split("\n");
      for (var b = 0; b < bLines.length; b++) {
        var bp = bLines[b].trim().split("\t");
        if (bp.length >= 2 && bp[0]) {
          var bytes = parseInt(bp[1], 10) || 0;
          var szFmt = formatKiB(Math.max(20, Math.round(bytes / 1024)));
          res.backups.push({
            path: bp[0],
            name: bp[0].split("/").pop(),
            size: szFmt,
            sizeFormatted: szFmt,
            date: bp[2] || ""
          });
        }
      }
    }
  }

  return res;
}

function buildCleanYayCommand() {
  return [
    "bash", "-c",
    'rm -rf "$HOME/.cache/yay" "$HOME/.cache/paru" 2>/dev/null; mkdir -p "$HOME/.cache/yay"; echo "CLEAN_OK:Purged AUR build cache"'
  ];
}

function buildCleanJournalCommand() {
  return [
    "sudo", "-S", "-p", "", "bash", "-c",
    'journalctl --vacuum-size=100M 2>&1 && echo "CLEAN_OK:Vacuumed systemd journal to <=100M"'
  ];
}

function buildCleanDevCachesCommand() {
  return [
    "bash", "-c",
    'rm -rf "$HOME/.npm/_cacache" "$HOME/.npm/_logs" "$HOME/.npm/_npx" "$HOME/.cache/pip" "$HOME/.cargo/registry/cache" "$HOME/.cache/go-build" "$HOME/.gradle/caches" 2>/dev/null; echo "CLEAN_OK:Cleaned developer caches (npm, pip, cargo, go, gradle)"'
  ];
}

function buildCleanBrowserCachesCommand() {
  return [
    "bash", "-c",
    'rm -rf "$HOME/.cache/BraveSoftware" "$HOME/.cache/chromium" "$HOME/.config/discord/Cache" "$HOME/.config/discord/GPUCache" "$HOME/.config/Spotify/Browser/Cache" "$HOME/.config/Code/Cache" "$HOME/.config/Code/CachedData" 2>/dev/null; echo "CLEAN_OK:Cleaned transient browser & Electron GPU caches"'
  ];
}

function buildCleanDockerCommand() {
  return [
    "bash", "-c",
    'if command -v docker >/dev/null 2>&1; then docker system prune -f >/dev/null 2>&1 && echo "CLEAN_OK:Pruned unused Docker containers & build cache" || echo "CLEAN_ERR:Docker daemon not running"; else echo "CLEAN_OK:Docker not installed"; fi'
  ];
}

function buildCleanBrokenSymlinksCommand() {
  return [
    "bash", "-c",
    'cnt=$(find "$HOME/.config" "$HOME/.local/share" -maxdepth 2 -xtype l 2>/dev/null | wc -l); find "$HOME/.config" "$HOME/.local/share" -maxdepth 2 -xtype l -delete 2>/dev/null; echo "CLEAN_OK:Removed $cnt broken symlinks"'
  ];
}

function buildCleanGhostDaemonsCommand() {
  var script = [
    'for pid in $(pgrep -x gpg-agent -x scdaemon 2>/dev/null); do',
    '  if tr "\\0" " " < "/proc/$pid/cmdline" 2>/dev/null | grep -qE -- "--homedir.*\\.cache"; then',
    '    kill -9 "$pid" 2>/dev/null || true',
    '  fi',
    'done',
    'pkill -9 -x protonvpn -x protonvpn-cli -x proton-vpn 2>/dev/null || true',
    'for pid in $(pgrep -x python -x python3 2>/dev/null); do',
    '  if tr "\\0" " " < "/proc/$pid/cmdline" 2>/dev/null | grep -qE -- "protonvpn|proton_vpn"; then',
    '    kill -9 "$pid" 2>/dev/null || true',
    '  fi',
    'done',
    'if ! pacman -Qq proton-vpn-gtk-app protonvpn-cli protonvpn >/dev/null 2>&1; then',
    '  rm -rf "$HOME/.cache/Proton" "$HOME/.config/Proton" 2>/dev/null || true',
    'fi',
    'echo "CLEAN_OK:Terminated lingering VPN & cache daemons"'
  ].join("\n");
  return ["bash", "-c", script];
}

function buildCleanCommand(cat) {
  if (cat === "yay") return buildCleanYayCommand();
  if (cat === "journal") return buildCleanJournalCommand();
  if (cat === "dev") return buildCleanDevCachesCommand();
  if (cat === "browser") return buildCleanBrowserCachesCommand();
  if (cat === "docker") return buildCleanDockerCommand();
  if (cat === "symlinks") return buildCleanBrokenSymlinksCommand();
  if (cat === "daemons") return buildCleanGhostDaemonsCommand();
  return null;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    buildJanitorScanScript: buildJanitorScanScript,
    parseJanitorStats: parseJanitorStats,
    buildCleanYayCommand: buildCleanYayCommand,
    buildCleanJournalCommand: buildCleanJournalCommand,
    buildCleanDevCachesCommand: buildCleanDevCachesCommand,
    buildCleanBrowserCachesCommand: buildCleanBrowserCachesCommand,
    buildCleanDockerCommand: buildCleanDockerCommand,
    buildCleanBrokenSymlinksCommand: buildCleanBrokenSymlinksCommand,
    buildCleanGhostDaemonsCommand: buildCleanGhostDaemonsCommand,
    buildCleanCommand: buildCleanCommand
  };
}
