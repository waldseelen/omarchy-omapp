import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "script/SafeOps.js" as SafeOps
import "script/SudoKeeper.js" as SudoKeeper
import "script/LeftoverHunter.js" as LeftoverHunter
import "script/Scanner.js" as Scanner
import "script/Sorter.js" as Sorter

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property string home: Quickshell.env("HOME")

  // Inventory & Filter State
  property var rawItems: []
  property var displayItems: []
  property int selectedIndex: 0
  property string filterText: ""
  property string activeCategory: "all"
  property string activeSort: "size"
  property bool isJanitorView: false

  // Sudo & Process State
  property bool sudoActive: false
  property bool sudoModalOpen: false
  property string sudoErrorMessage: ""
  property var runningPids: ({})

  // Deep Uninstall & Leftover State
  property bool leftoverModalOpen: false
  property var currentUninstallApp: null
  property var foundLeftovers: []
  property string orphanList: ""

  // Janitor Statistics
  property string janitorOrphanText: "0 orphans"
  property string janitorPacmanCache: "Checking..."
  property string janitorYayCache: "Checking..."

  function open(payloadJson) {
    root.opened = true;
    if (root.shell && root.shell.appLibrary && typeof root.shell.appLibrary.refreshIcons === "function") {
      root.shell.appLibrary.refreshIcons();
    }
    root.checkSudoStatus();
    root.refreshInventory();
    root.refreshProcessStatus();
    Qt.callLater(function() {
      if (header) header.focusSearch();
    });
  }

  function close() {
    root.opened = false;
    root.sudoModalOpen = false;
    root.leftoverModalOpen = false;
  }

  function toggle() {
    if (root.opened) {
      close();
    } else {
      open();
    }
  }

  onOpenedChanged: {
    if (root.opened) {
      root.checkSudoStatus();
      root.refreshInventory();
      root.refreshProcessStatus();
      Qt.callLater(function() {
        if (header) header.focusSearch();
      });
    } else {
      root.sudoModalOpen = false;
      root.leftoverModalOpen = false;
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omapp-manager"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // Background Dimmer
    Rectangle {
      anchors.fill: parent
      color: Util.alpha("#000000", 0.55)

      MouseArea {
        anchors.fill: parent
        onClicked: root.opened = false
      }
    }

    // Central Card Container
    Rectangle {
      id: centerCard
      anchors.centerIn: parent
      width: Math.min(parent.width - Style.space(48), Style.space(1100))
      height: Math.min(parent.height - Style.space(48), Style.space(720))
      radius: Style.cornerRadius
      color: Color.menu.background || "#18181b"
      border.width: 1
      border.color: Util.alpha(Color.menu.border, 0.45)

      MouseArea {
        anchors.fill: parent
        onClicked: {} // Catch clicks inside modal card
      }

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(18)
        spacing: Style.space(12)

        // Header component
        OmappHeader {
          id: header
          width: parent.width
          filterText: root.filterText
          activeCategory: root.activeCategory
          activeSort: root.activeSort
          itemCount: root.displayItems.length
          sudoActive: root.sudoActive
          isJanitorView: root.isJanitorView

          onSearchChanged: function(text) {
            root.filterText = text;
            root.updateDisplayList();
          }

          onCategorySelected: function(cat) {
            root.activeCategory = cat;
            root.updateDisplayList();
          }

          onSortChanged: function(mode) {
            root.activeSort = mode;
            root.updateDisplayList();
          }

          onSudoClicked: {
            root.sudoErrorMessage = "";
            root.sudoModalOpen = true;
            sudoModal.initFocus();
          }

          onJanitorToggled: {
            root.isJanitorView = !root.isJanitorView;
            if (root.isJanitorView) {
              root.refreshJanitorStats();
            }
          }
        }

        // Main View Area: Apps Split View OR Janitor View
        Item {
          width: parent.width
          height: parent.height - header.height - Style.space(12)

          // 1. Applications Split View (App List + Inspector)
          Row {
            anchors.fill: parent
            spacing: Style.space(14)
            visible: !root.isJanitorView

            // Left Pane: Scrollable List of Apps
            Rectangle {
              width: parent.width * 0.58
              height: parent.height
              radius: Style.cornerRadius
              color: Util.alpha(Color.menu.selectedBackground, 0.08)
              border.width: 1
              border.color: Util.alpha(Color.menu.border, 0.3)
              clip: true

              ListView {
                id: appListView
                anchors.fill: parent
                anchors.margins: Style.space(6)
                model: root.displayItems
                currentIndex: root.selectedIndex
                spacing: Style.space(4)
                boundsBehavior: Flickable.StopAtBounds

                delegate: AppGridRow {
                  shell: root.shell
                  isSelected: index === root.selectedIndex
                  appName: modelData.name
                  appPkg: modelData.pkg
                  appVersion: modelData.version
                  appIcon: modelData.icon
                  appCategory: modelData.category
                  appSize: modelData.sizeFormatted
                  appRunning: !!root.runningPids[modelData.pkg] || !!root.runningPids[modelData.name.toLowerCase()]

                  onClicked: {
                    root.selectedIndex = index;
                  }
                }

                // Empty list state
                Item {
                  anchors.fill: parent
                  visible: root.displayItems.length === 0

                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(10)

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: "🔍"
                      font.pixelSize: Style.space(32)
                      opacity: 0.5
                    }

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: "No applications found"
                      color: Util.alpha(Color.menu.text, 0.5)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body ? Style.font.body : 13
                    }
                  }
                }
              }
            }

            // Right Pane: App Inspector Drawer
            AppInspector {
              id: inspector
              shell: root.shell
              width: parent.width * 0.42 - Style.space(14)
              height: parent.height
              appItem: (root.displayItems.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.displayItems.length)
                ? root.displayItems[root.selectedIndex] : null
              isRunning: appItem ? (!!root.runningPids[appItem.pkg] || !!root.runningPids[appItem.name.toLowerCase()]) : false
              runningPid: appItem ? (root.runningPids[appItem.pkg] || root.runningPids[appItem.name.toLowerCase()] || "") : ""

              onUninstallRequested: function(app) {
                root.startDeepUninstall(app);
              }

              onKillRequested: function(app) {
                root.killAppProcess(app);
              }

              onLaunchRequested: function(app) {
                root.launchApp(app);
              }

              onOpenConfigRequested: function(app) {
                root.openAppConfig(app);
              }

              onOpenUrlRequested: function(url) {
                root.openUrl(url);
              }
            }
          }

          // 2. System Janitor View
          SystemJanitorView {
            anchors.fill: parent
            visible: root.isJanitorView
            orphanCountText: root.janitorOrphanText
            pacmanCacheSize: root.janitorPacmanCache
            aurCacheSize: root.janitorYayCache

            onBackClicked: root.isJanitorView = false

            onCleanOrphansRequested: {
              if (!root.sudoActive) {
                root.sudoErrorMessage = "Sudo required to prune orphan packages";
                root.sudoModalOpen = true;
                return;
              }
              orphanPruneProc.running = true;
            }

            onCleanPacmanCacheRequested: {
              if (!root.sudoActive) {
                root.sudoErrorMessage = "Sudo required to trim pacman cache";
                root.sudoModalOpen = true;
                return;
              }
              pacmanCacheCleanProc.running = true;
            }

            onCleanAurCacheRequested: {
              aurCacheCleanProc.running = true;
            }
          }
        }
      }

      // Modals
      SudoPromptModal {
        id: sudoModal
        isOpen: root.sudoModalOpen
        errorMessage: root.sudoErrorMessage

        onSubmitted: function(password) {
          root.authenticateSudo(password);
        }

        onCancelled: {
          root.sudoModalOpen = false;
        }
      }

      LeftoverReviewModal {
        id: leftoverModal
        isOpen: root.leftoverModalOpen
        appItem: root.currentUninstallApp
        orphanListText: root.orphanList

        onConfirmedPurge: function(selectedPaths) {
          root.purgeLeftovers(selectedPaths);
        }

        onPruneOrphansRequested: {
          orphanPruneProc.running = true;
        }

        onClosed: {
          root.leftoverModalOpen = false;
          root.refreshInventory();
        }
      }
    }

    // Global Key Handling inside Panel
    Item {
      id: keyHandler
      focus: true

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (root.sudoModalOpen) {
            root.sudoModalOpen = false;
            event.accepted = true;
          } else if (root.leftoverModalOpen) {
            root.leftoverModalOpen = false;
            root.refreshInventory();
            event.accepted = true;
          } else if (root.isJanitorView) {
            root.isJanitorView = false;
            event.accepted = true;
          } else {
            root.opened = false;
            event.accepted = true;
          }
          return;
        }

        // App navigation keys
        if (!root.sudoModalOpen && !root.leftoverModalOpen && !root.isJanitorView) {
          if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && event.modifiers === Qt.NoModifier)) {
            if (root.selectedIndex < root.displayItems.length - 1) {
              root.selectedIndex++;
              appListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            }
            event.accepted = true;
          } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && event.modifiers === Qt.NoModifier)) {
            if (root.selectedIndex > 0) {
              root.selectedIndex--;
              appListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            }
            event.accepted = true;
          } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_U) {
            var cur = root.displayItems[root.selectedIndex];
            if (cur) root.startDeepUninstall(cur);
            event.accepted = true;
          } else if (event.key === Qt.Key_Slash) {
            header.focusSearch();
            event.accepted = true;
          }
        }
      }
    }
  }

  // -------------------------------------------------------------
  // Process Declarations & Background Workers
  // -------------------------------------------------------------

  // 1. Inventory Scanner Process
  Process {
    id: inventoryProc
    command: Scanner.buildInventoryScanScript()
    stdout: StdioCollector {
      id: inventoryOutput
      waitForEnd: true
    }
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        var items = Scanner.parseInventory(inventoryOutput.text, SafeOps);
        root.rawItems = items;
        root.updateDisplayList();
      }
    }
  }

  // 2. Sudo Status Check Process
  Process {
    id: sudoStatusProc
    command: SudoKeeper.getStatusCheckCommand()
    onExited: function(exitCode, exitStatus) {
      root.sudoActive = (exitCode === 0);
      if (root.sudoActive && !sudoKeepaliveProc.running) {
        sudoKeepaliveProc.running = true;
      }
    }
  }

  // 3. Sudo Authentication via Stdin Process
  Process {
    id: sudoAuthProc
    command: SudoKeeper.getAuthCommand()
    property string pendingPassword: ""
    onExited: function(exitCode, exitStatus) {
      sudoModal.isChecking = false;
      if (exitCode === 0) {
        root.sudoActive = true;
        root.sudoModalOpen = false;
        root.sudoErrorMessage = "";
        if (!sudoKeepaliveProc.running) {
          sudoKeepaliveProc.running = true;
        }
      } else {
        root.sudoErrorMessage = "Authentication failed. Incorrect password.";
      }
    }
  }

  // 4. Sudo Keepalive Background Process
  Process {
    id: sudoKeepaliveProc
    command: ["bash", "-c", SudoKeeper.getKeepaliveScript(0)]
  }

  // 5. Running Process Detector
  Process {
    id: procCheck
    command: ["bash", "-c", "ps -eo comm,pid --no-headers 2>/dev/null"]
    stdout: StdioCollector {
      id: procCheckOutput
      waitForEnd: true
    }
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        var lines = procCheckOutput.text.split("\n");
        var pids = {};
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim();
          if (!line) continue;
          var parts = line.split(/\s+/);
          if (parts.length >= 2) {
            var comm = parts[0].toLowerCase();
            var pid = parts[1];
            pids[comm] = pid;
          }
        }
        root.runningPids = pids;
      }
    }
  }

  // 6. Package Uninstall Process
  Process {
    id: uninstallProc
    property var targetApp: null
    stdout: StdioCollector { id: uninstallOut; waitForEnd: true }
    stderr: StdioCollector { id: uninstallErr; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        leftoverModal.phase = 2;
        leftoverModal.statusMessage = "Scanning for residual configs and caches...";
        root.runLeftoverScan(uninstallProc.targetApp);
      } else {
        leftoverModal.statusMessage = "Package removal failed: " + (uninstallErr.text || "Check sudo permissions");
      }
    }
  }

  // 7. Leftover Scan Process
  Process {
    id: leftoverScanProc
    property var targetApp: null
    stdout: StdioCollector { id: leftoverScanOut; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      var items = LeftoverHunter.parseScanOutput(leftoverScanOut.text, root.home, SafeOps);
      root.foundLeftovers = items;
      leftoverModal.leftoverItems = items;
      leftoverModal.updateTotalSelected();
      leftoverModal.phase = 3;
    }
  }

  // 8. Leftover Purge Process (Backup then rm -rf)
  Process {
    id: leftoverPurgeProc
    onExited: function(exitCode, exitStatus) {
      leftoverModal.isPurging = false;
      leftoverModal.phase = 4;
      root.checkOrphanPackages();
    }
  }

  // 9. Orphan Checker Process
  Process {
    id: orphanCheckProc
    command: ["bash", "-c", "pacman -Qtdq 2>/dev/null || true"]
    stdout: StdioCollector { id: orphanOut; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      var text = orphanOut.text.trim();
      root.orphanList = text || "NO_ORPHANS";
      leftoverModal.orphanListText = text || "NO_ORPHANS";
      var count = text ? text.split("\n").length : 0;
      root.janitorOrphanText = count + " orphan packages";
    }
  }

  // 10. Orphan Prune Process
  Process {
    id: orphanPruneProc
    command: SudoKeeper.buildOrphanCleanCommand()
    onExited: function(exitCode, exitStatus) {
      root.orphanList = "NO_ORPHANS";
      leftoverModal.orphanListText = "NO_ORPHANS";
      root.janitorOrphanText = "0 orphan packages";
    }
  }

  // 11. Pacman Cache Clean Process
  Process {
    id: pacmanCacheCleanProc
    command: SudoKeeper.buildCacheCleanCommand()
    onExited: function(exitCode, exitStatus) {
      root.refreshJanitorStats();
    }
  }

  // 12. AUR Yay Cache Clean Process
  Process {
    id: aurCacheCleanProc
    command: ["bash", "-c", "rm -rf ~/.cache/yay/* 2>/dev/null"]
    onExited: function(exitCode, exitStatus) {
      root.refreshJanitorStats();
    }
  }

  // 13. Janitor Stats Query Process
  Process {
    id: janitorStatsProc
    command: [
      "bash", "-c",
      'orphans=$(pacman -Qtdq 2>/dev/null | wc -l); ' +
      'pac_sz=$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1); ' +
      'aur_sz=$(du -sh ~/.cache/yay 2>/dev/null | cut -f1); ' +
      'echo -e "$orphans\\t${pac_sz:-0 B}\\t${aur_sz:-0 B}"'
    ]
    stdout: StdioCollector { id: janitorStatsOut; waitForEnd: true }
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        var parts = janitorStatsOut.text.trim().split("\t");
        root.janitorOrphanText = (parts[0] || "0") + " orphan packages";
        root.janitorPacmanCache = parts[1] || "0 B";
        root.janitorYayCache = parts[2] || "0 B";
      }
    }
  }

  // -------------------------------------------------------------
  // Helper Functions
  // -------------------------------------------------------------

  function refreshInventory() {
    if (!inventoryProc.running) {
      inventoryProc.running = true;
    }
  }

  function checkSudoStatus() {
    if (!sudoStatusProc.running) {
      sudoStatusProc.running = true;
    }
  }

  function refreshProcessStatus() {
    if (!procCheck.running) {
      procCheck.running = true;
    }
  }

  function refreshJanitorStats() {
    if (!janitorStatsProc.running) {
      janitorStatsProc.running = true;
    }
  }

  function updateDisplayList() {
    var filtered = Sorter.filterItems(root.rawItems, root.activeCategory, root.filterText);
    var sorted = Sorter.sortItems(filtered, root.activeSort, "desc");
    root.displayItems = sorted;
    if (root.selectedIndex >= sorted.length) {
      root.selectedIndex = Math.max(0, sorted.length - 1);
    }
  }

  function authenticateSudo(pwd) {
    sudoModal.isChecking = true;
    // Pipe password directly into stdin of sudo -S -v
    sudoAuthProc.command = ["bash", "-c", 'printf "%s\\n" "$1" | sudo -S -v', "sudo-auth", pwd];
    sudoAuthProc.running = true;
  }

  function startDeepUninstall(app) {
    if (!app) return;
    if (!root.sudoActive && app.category !== "webapp") {
      root.sudoErrorMessage = "Authentication required to uninstall " + app.pkg;
      root.sudoModalOpen = true;
      return;
    }

    root.currentUninstallApp = app;
    root.foundLeftovers = [];
    leftoverModal.phase = 1;
    leftoverModal.statusMessage = "Removing " + app.pkg + " via pacman...";
    leftoverModal.isOpen = true;

    if (app.category === "webapp" || !app.pkg) {
      // Local web app or standalone desktop file: delete desktop file directly
      var deskCmd = "rm -f " + SafeOps.shellEscape(app.desktopFile ? (root.home + "/.local/share/applications/" + app.desktopFile) : "");
      uninstallProc.command = ["bash", "-c", deskCmd];
    } else {
      var cmd = SudoKeeper.buildUninstallCommand(app.pkg);
      if (!cmd) {
        leftoverModal.statusMessage = "Invalid package name: " + app.pkg;
        return;
      }
      uninstallProc.command = cmd;
    }

    uninstallProc.targetApp = app;
    uninstallProc.running = true;
  }

  function runLeftoverScan(app) {
    var scriptObj = LeftoverHunter.buildScanScript(app, root.home, SafeOps);
    if (!scriptObj) {
      leftoverModal.phase = 3;
      return;
    }
    leftoverScanProc.command = scriptObj.argv;
    leftoverScanProc.targetApp = app;
    leftoverScanProc.running = true;
  }

  function purgeLeftovers(paths) {
    if (!paths || paths.length === 0) {
      leftoverModal.phase = 4;
      root.checkOrphanPackages();
      return;
    }

    leftoverModal.isPurging = true;

    // 1. Build backup command
    var backup = SafeOps.buildBackupCommand(paths, root.currentUninstallApp ? root.currentUninstallApp.pkg : "app", root.home);
    // 2. Build permanent purge command
    var purge = SafeOps.buildPurgeCommand(paths, root.home);

    var compositeCmd = "";
    if (backup && purge) {
      compositeCmd = backup.command + " && " + purge.command;
    } else if (purge) {
      compositeCmd = purge.command;
    }

    if (compositeCmd) {
      leftoverPurgeProc.command = ["bash", "-c", compositeCmd];
      leftoverPurgeProc.running = true;
    } else {
      leftoverModal.isPurging = false;
      leftoverModal.phase = 4;
    }
  }

  function checkOrphanPackages() {
    if (!orphanCheckProc.running) {
      orphanCheckProc.running = true;
    }
  }

  function killAppProcess(app) {
    if (!app) return;
    var target = app.exec ? app.exec.split(/\s+/)[0].split("/").pop() : app.pkg;
    Util.execDetached(["pkill", "-f", target]);
    Qt.callLater(function() { root.refreshProcessStatus(); });
  }

  function launchApp(app) {
    if (!app) return;
    if (app.exec) {
      Util.execDetached(["bash", "-c", app.exec + " &"]);
    }
  }

  function openAppConfig(app) {
    if (!app) return;
    var targetDir = root.home + "/.config/" + (app.pkg || app.name.toLowerCase());
    Util.execDetached(["bash", "-c", 'mkdir -p "' + targetDir + '"; xdg-open "' + targetDir + '"']);
  }

  function openUrl(url) {
    if (url) {
      Util.execDetached(["xdg-open", url]);
    }
  }
}
