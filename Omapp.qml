import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "ui"
import "script/SafeOps.js" as SafeOps
import "script/SudoKeeper.js" as SudoKeeper
import "script/LeftoverHunter.js" as LeftoverHunter
import "script/Scanner.js" as Scanner
import "script/Sorter.js" as Sorter
import "script/TaskManager.js" as TaskManager
import "script/TaskControl.js" as TaskControl
import "script/StartupServices.js" as StartupServices
import "script/JanitorOps.js" as JanitorOps
import "script/StateStore.js" as StateStore
import "script/ModelSync.js" as ModelSync

Item {
  id: root

  property var shell: null; property var manifest: null; property bool opened: false
  property string home: Quickshell.env("HOME"); property string activeTab: "apps"; property var prefs: StateStore.defaultPrefs()

  property var rawItems: []; property var displayItems: []; property int selectedIndex: 0
  property string filterText: ""; property string activeCategory: "all"; property string activeSort: "size"; property string appSortDirection: "desc"
  property var selectedBatchMap: ({}); property int selectedBatchCount: 0

  property var rawTasks: []; property var displayTasks: []; property int selectedTaskIndex: 0; property int selectedTaskPid: -1
  property string taskCategory: "all"; property string taskSort: "cpu"; property string taskSortDirection: "desc"; property string taskFilterText: ""
  property var gpuStateMap: ({}); property var cpuHeaderState: ({ total: 0, idle: 0 })
  property var sysTelemetry: ({ cpuPercent: 0, gpuPercent: 0, memUsedGiB: 0, memTotalGiB: 0, tempC: 0 }); property var expandedGroups: ({})

  property var rawServices: []; property var displayServices: []; property int selectedServiceIndex: 0
  property string serviceCategory: "all"; property string serviceSort: "impact"; property string serviceSortDirection: "desc"; property string serviceFilterText: ""

  property bool sudoActive: false; property bool sudoModalOpen: false; property string sudoErrorMessage: ""
  property var runningPids: ({}); property var pendingSudoCallback: null
  property bool leftoverModalOpen: false; property var currentUninstallApp: null; property var foundLeftovers: []
  property string orphanList: ""; property var janitorStats: ({}); property var contextTarget: null
  property string janitorCleaningCategory: ""; property string janitorStatusMessage: ""; property bool janitorStatusError: false

  ListModel { id: appListModel }
  ListModel { id: taskListModel }
  ListModel { id: serviceListModel }

  function parseTabFromPayload(payloadJson) {
    if (!payloadJson || payloadJson === "{}") return "";
    try { var d = JSON.parse(payloadJson); if (d && d.tab) return String(d.tab); }
    catch (e) { if (payloadJson === "tasks" || payloadJson === "services" || payloadJson === "janitor" || payloadJson === "apps") return payloadJson; }
    return "";
  }

  function open(payloadJson) {
    root.opened = true;
    var req = parseTabFromPayload(payloadJson);
    if (req) root.activeTab = req;
  }

  function close() {
    root.opened = false; root.sudoModalOpen = false; root.leftoverModalOpen = false; leftoverModal.isOpen = false; ctxMenu.hide();
  }

  function toggle(payloadJson) {
    var req = parseTabFromPayload(payloadJson);
    if (root.opened) { if (req && req !== root.activeTab) open(payloadJson); else close(); }
    else open(payloadJson);
  }

  onOpenedChanged: {
    if (root.opened) {
      prefsLoadProc.running = true;
      if (root.shell && root.shell.appLibrary && typeof root.shell.appLibrary.refreshIcons === "function") root.shell.appLibrary.refreshIcons();
      root.checkSudoStatus(); root.refreshInventory(); root.refreshProcessStatus(); root.refreshTasks();
      if (root.activeTab === "services") root.refreshServices();
      if (root.activeTab === "janitor") root.refreshJanitorStats();
      initialGpuSampleTimer.restart();
      Qt.callLater(function() { if (header) header.focusSearch(); });
    } else close();
  }

  Timer { id: initialGpuSampleTimer; interval: 500; repeat: false; onTriggered: { if (root.opened) root.refreshTasks(); } }
  Timer { id: taskRefreshTimer; interval: 2000; repeat: true; running: root.opened; onTriggered: { if (root.activeTab === "tasks" && taskView && taskView.isUserScrolling()) return; root.refreshTasks(); } }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omapp-manager"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: Color.menu.scrim; MouseArea { anchors.fill: parent; onClicked: root.close() } }

    BorderSurface {
      id: centerCard
      anchors.centerIn: parent
      width: Math.min(parent.width - Style.space(40), Style.space(1160))
      height: Math.min(parent.height - Style.space(40), Style.space(760))
      radius: Style.cornerRadius
      color: Color.menu.background
      borderSpec: Border.localOrSurfaceSpec("menu", "border", Color.menu.border, Color.foreground, Math.max(1, Style.normalBorderWidth))

      MouseArea { anchors.fill: parent; onClicked: ctxMenu.hide() }

      Column {
        anchors.fill: parent; anchors.margins: Style.space(16); spacing: Style.space(10)

        OmappHeader {
          id: header; width: parent.width
          filterText: root.activeTab === "tasks" ? root.taskFilterText : (root.activeTab === "services" ? root.serviceFilterText : root.filterText)
          activeTab: root.activeTab
          activeCategory: root.activeTab === "tasks" ? root.taskCategory : (root.activeTab === "services" ? root.serviceCategory : root.activeCategory)
          itemCount: root.activeTab === "tasks" ? root.displayTasks.length : (root.activeTab === "services" ? root.displayServices.length : root.displayItems.length)
          sudoActive: root.sudoActive; groupTasks: !!root.prefs.groupTasks
          sysCpuPercent: root.sysTelemetry.cpuPercent || 0; sysGpuPercent: root.sysTelemetry.gpuPercent || 0
          sysMemUsedGiB: root.sysTelemetry.memUsedGiB || 0; sysMemTotalGiB: root.sysTelemetry.memTotalGiB || 0; sysTempC: root.sysTelemetry.tempC || 0

          onSearchChanged: function(text) {
            if (root.activeTab === "tasks") { root.taskFilterText = text; root.updateTaskDisplayList(); }
            else if (root.activeTab === "services") { root.serviceFilterText = text; root.updateServiceDisplayList(); }
            else { root.filterText = text; root.updateDisplayList(); }
          }
          onTabChanged: function(tab) {
            root.activeTab = tab;
            if (tab === "tasks") { root.refreshTasks(); initialGpuSampleTimer.restart(); }
            else if (tab === "services") root.refreshServices();
            else if (tab === "janitor") root.refreshJanitorStats();
            else root.updateDisplayList();
          }
          onCategorySelected: function(cat) {
            if (root.activeTab === "tasks") root.taskCategory = cat;
            else if (root.activeTab === "services") root.serviceCategory = cat;
            else root.activeCategory = cat;
            if (root.activeTab === "tasks") root.updateTaskDisplayList();
            else if (root.activeTab === "services") root.updateServiceDisplayList();
            else root.updateDisplayList();
          }
          onToggleGroupTasksRequested: { root.prefs.groupTasks = !root.prefs.groupTasks; root.savePreferences(); root.updateTaskDisplayList(); }
          onSudoClicked: { if (root.sudoActive) root.lockSudo(); else root.promptSudo("Unlock administrator privileges", null); }
        }

        Item {
          width: parent.width; height: parent.height - header.height - footerBar.height - Style.space(20)

          AppsView {
            id: appsView; anchors.fill: parent; visible: root.activeTab === "apps"
            shell: root.shell; appModel: appListModel; displayItems: root.displayItems; selectedIndex: root.selectedIndex
            activeSort: root.activeSort; sortDirection: root.appSortDirection; runningPids: root.runningPids
            selectedBatchMap: root.selectedBatchMap; selectedBatchCount: root.selectedBatchCount
            onRowSelected: function(idx) { root.selectedIndex = idx; }; onSortRequested: function(col) { root.toggleAppSort(col); }
            onToggleCheckRequested: function(pkg) { root.toggleBatchPkg(pkg); }
            onClearBatchRequested: { root.selectedBatchMap = {}; root.selectedBatchCount = 0; root.updateDisplayList(); }
            onBatchUninstallRequested: root.startBatchUninstall(); onUninstallRequested: function(app) { root.startDeepUninstall(app); }
            onKillRequested: function(app) { root.killAppProcess(app); }; onLaunchRequested: function(app) { if (app && app.exec) Util.execDetached(["bash", "-c", app.exec + " &"]); }
            onOpenConfigRequested: function(app) { if (app) Util.execDetached(["bash", "-c", 'mkdir -p "$HOME/.config/' + (app.pkg || app.name.toLowerCase()) + '"; xdg-open "$HOME/.config/' + (app.pkg || app.name.toLowerCase()) + '"']); }
            onOpenUrlRequested: function(url) { if (url) Util.execDetached(["xdg-open", url]); }; onTogglePinRequested: function(pkg) { root.toggleAppPin(pkg); }
            onDowngradeRequested: function(pkg, path) { root.downgradePackage(pkg, path); }
            onContextMenuRequested: function(rx, ry, app) {
              root.contextTarget = app; var pt = centerCard.mapFromItem(null, rx, ry);
              ctxMenu.showAt(pt.x, pt.y, app.name || app.pkg, ModelSync.buildAppContextActions(app));
            }
          }

          TaskManagerView {
            id: taskView; anchors.fill: parent; visible: root.activeTab === "tasks"
            shell: root.shell; taskModel: taskListModel; tasks: root.displayTasks; selectedIndex: root.selectedTaskIndex
            activeCategory: root.taskCategory; activeSort: root.taskSort; sortDirection: root.taskSortDirection
            filterText: root.taskFilterText; sudoActive: root.sudoActive
            onTaskSelected: function(idx, pid) { root.selectedTaskIndex = idx; root.selectedTaskPid = pid; }
            onSortRequested: function(mode, dir) { root.taskSort = mode; root.taskSortDirection = dir; root.updateTaskDisplayList(); }
            onKillRequested: function(pid, force) { root.runTaskCmd(TaskControl.buildKillCommand(pid, force, root.sudoActive)); }
            onFreezeRequested: function(pid, freeze) { root.runTaskCmd(TaskControl.buildFreezeCommand(pid, freeze, root.sudoActive)); }
            onReniceRequested: function(pid, prio) { root.runTaskCmd(TaskControl.buildReniceCommand(pid, prio, root.sudoActive)); }
            onAffinityRequested: function(pid, cpus) { root.runTaskCmd(TaskControl.buildAffinityCommand(pid, cpus, root.sudoActive)); }
            onOpenLocationRequested: function(pid) { root.runTaskCmd(TaskControl.buildOpenFileLocationCommand(pid)); }
            onInspectPackageRequested: function(pkg) { root.activeTab = "apps"; root.activeCategory = "all"; root.filterText = pkg; root.updateDisplayList(); }
            onTogglePinRequested: function(name) { root.toggleTaskPin(name); }; onToggleGroupExpandRequested: function(name) { root.expandedGroups[name] = !root.expandedGroups[name]; root.updateTaskDisplayList(); }
            onContextMenuRequested: function(rx, ry, tObj) {
              root.contextTarget = tObj; var pt = centerCard.mapFromItem(null, rx, ry);
              ctxMenu.showAt(pt.x, pt.y, tObj.name + " (PID " + tObj.pid + ")", ModelSync.buildTaskContextActions(tObj));
            }
          }

          StartupServicesView {
            id: servicesView; anchors.fill: parent; visible: root.activeTab === "services"
            serviceModel: serviceListModel; items: root.displayServices; selectedIndex: root.selectedServiceIndex
            activeSort: root.serviceSort; sortDirection: root.serviceSortDirection; sudoActive: root.sudoActive
            onItemSelected: function(idx) { root.selectedServiceIndex = idx; }
            onSortRequested: function(col, dir) { root.serviceSort = col; root.serviceSortDirection = dir; root.updateServiceDisplayList(); }
            onActionRequested: function(item, act) { root.triggerServiceAction(item, act); }
            onContextMenuRequested: function(rx, ry, sObj) {
              root.contextTarget = sObj; var pt = centerCard.mapFromItem(null, rx, ry);
              ctxMenu.showAt(pt.x, pt.y, sObj.name, ModelSync.buildServiceContextActions(sObj));
            }
          }

          SystemJanitorView {
            anchors.fill: parent; visible: root.activeTab === "janitor"; stats: root.janitorStats; cleaningCategory: root.janitorCleaningCategory; statusMessage: root.janitorStatusMessage; statusIsError: root.janitorStatusError
            onBackClicked: root.activeTab = "apps"; onRescanRequested: { root.janitorStatusMessage = "Rescanned storage footprints."; root.janitorStatusError = false; root.refreshJanitorStats(); }
            onCleanActionRequested: function(cat) { root.runJanitorClean(cat); }
            onScanOrphanDotfilesRequested: root.scanOrphanDotfiles(); onRestoreBackupRequested: function(name) { root.restoreBackupArchive(name); }
          }
        }

        KeybindFooterBar { id: footerBar; width: parent.width; activeTab: root.activeTab; selectedBatchCount: root.selectedBatchCount }
      }

      ContextMenuPopup { id: ctxMenu; onActionTriggered: function(actId) { root.handleContextAction(actId); } }

      SudoPromptModal {
        id: sudoModal; isOpen: root.sudoModalOpen; errorMessage: root.sudoErrorMessage
        onSubmitted: function(pwd) { sudoModal.isChecking = true; sudoAuthProc.pendingPassword = pwd; sudoAuthProc.running = true; }
        onCancelled: { root.sudoModalOpen = false; root.pendingSudoCallback = null; }
      }

      LeftoverReviewModal {
        id: leftoverModal; isOpen: root.leftoverModalOpen; home: root.home; appItem: root.currentUninstallApp; orphanListText: root.orphanList
        onConfirmedPurge: function(paths) { root.purgeLeftovers(paths); }
        onPruneOrphansRequested: { actionRunnerProc.command = SudoKeeper.buildOrphanPruneCommand(); actionRunnerProc.running = true; }
        onClosed: { root.leftoverModalOpen = false; leftoverModal.isOpen = false; root.refreshInventory(); }
      }
    }

    Item {
      focus: root.opened
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (ctxMenu.isOpen) { ctxMenu.hide(); event.accepted = true; return; }
          if (root.sudoModalOpen) { root.sudoModalOpen = false; event.accepted = true; return; }
          if (root.leftoverModalOpen) { root.leftoverModalOpen = false; leftoverModal.isOpen = false; event.accepted = true; return; }
          if (root.activeTab !== "apps") { root.activeTab = "apps"; event.accepted = true; return; }
          root.close(); event.accepted = true; return;
        }
        if (root.sudoModalOpen || root.leftoverModalOpen) return;
        if (event.key === Qt.Key_Slash) { header.focusSearch(); event.accepted = true; return; }
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) { header.tabChanged(["apps", "tasks", "services", "janitor"][event.key - Qt.Key_1]); event.accepted = true; return; }

        if (root.activeTab === "apps") {
          if (event.key === Qt.Key_Down || event.key === Qt.Key_J) { if (root.selectedIndex < root.displayItems.length - 1) { root.selectedIndex++; appsView.positionAt(root.selectedIndex); } event.accepted = true; }
          else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) { if (root.selectedIndex > 0) { root.selectedIndex--; appsView.positionAt(root.selectedIndex); } event.accepted = true; }
          else if (event.key === Qt.Key_Space) { var curA = root.displayItems[root.selectedIndex]; if (curA && !curA.isProtected) root.toggleBatchPkg(curA.pkg); event.accepted = true; }
          else if (event.key === Qt.Key_P) { var curP = root.displayItems[root.selectedIndex]; if (curP) root.toggleAppPin(curP.pkg); event.accepted = true; }
          else if (event.key === Qt.Key_Delete || event.key === Qt.Key_U) { var curU = root.displayItems[root.selectedIndex]; if (curU) root.startDeepUninstall(curU); event.accepted = true; }
        } else if (root.activeTab === "tasks") {
          var curT = root.displayTasks[root.selectedTaskIndex];
          if (event.key === Qt.Key_Down || event.key === Qt.Key_J) { if (root.selectedTaskIndex < root.displayTasks.length - 1) { root.selectedTaskIndex++; root.selectedTaskPid = root.displayTasks[root.selectedTaskIndex].pid; taskView.positionAt(root.selectedTaskIndex); } event.accepted = true; }
          else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) { if (root.selectedTaskIndex > 0) { root.selectedTaskIndex--; root.selectedTaskPid = root.displayTasks[root.selectedTaskIndex].pid; taskView.positionAt(root.selectedTaskIndex); } event.accepted = true; }
          else if (event.key === Qt.Key_G) { header.toggleGroupTasksRequested(); event.accepted = true; }
          else if (event.key === Qt.Key_P && curT) { root.toggleTaskPin(curT.name); event.accepted = true; }
          else if (event.key === Qt.Key_F && curT) { root.runTaskCmd(TaskControl.buildFreezeCommand(curT.pid, !curT.isFrozen, root.sudoActive)); event.accepted = true; }
          else if ((event.key === Qt.Key_Delete || event.key === Qt.Key_U) && curT) { root.runTaskCmd(TaskControl.buildKillCommand(curT.pid, false, root.sudoActive)); event.accepted = true; }
        } else if (root.activeTab === "janitor" && event.key === Qt.Key_R) {
          root.janitorStatusMessage = "Rescanned storage footprints."; root.janitorStatusError = false; root.refreshJanitorStats(); event.accepted = true;
        }
      }
    }
  }

  Process { id: prefsLoadProc; command: StateStore.buildLoadPrefsCommand(root.home); stdout: StdioCollector { waitForEnd: true; onStreamFinished: { root.prefs = StateStore.parsePrefs(text); root.updateDisplayList(); root.updateTaskDisplayList(); } } }
  Process { id: inventoryProc; command: Scanner.buildInventoryScanScript(); stdout: StdioCollector { waitForEnd: true; onStreamFinished: { root.rawItems = Scanner.parseInventory(text, SafeOps); root.updateDisplayList(); } } }
  Process { id: sudoStatusProc; command: ["sudo", "-n", "true"]; onExited: function(code) { root.sudoActive = (code === 0); } }
  Timer { id: sudoKeepaliveTimer; interval: 45000; repeat: true; running: root.sudoActive && root.opened; onTriggered: { if (!sudoKeepaliveProc.running) sudoKeepaliveProc.running = true; } }
  Process { id: sudoKeepaliveProc; command: ["sudo", "-n", "-v"]; onExited: function(code) { if (code !== 0) root.sudoActive = false; } }
  Process {
    id: sudoAuthProc; command: ["sudo", "-S", "-v"]; stdinEnabled: true; property string pendingPassword: ""
    onStarted: { write(pendingPassword + "\n"); pendingPassword = ""; }
    onExited: function(code) {
      sudoModal.isChecking = false;
      if (code === 0) { root.sudoActive = true; root.sudoModalOpen = false; if (root.pendingSudoCallback) { var cb = root.pendingSudoCallback; root.pendingSudoCallback = null; cb(); } }
      else { root.sudoErrorMessage = "Incorrect password."; sudoModal.initFocus(); }
    }
  }
  Process { id: procCheck; command: ["bash", "-c", "ps -eo comm,pid --no-headers 2>/dev/null"]; stdout: StdioCollector { waitForEnd: true; onStreamFinished: { var pids = {}; var lines = text.split("\n"); for (var i = 0; i < lines.length; i++) { var p = lines[i].trim().split(/\s+/); if (p.length >= 2) pids[p[0].toLowerCase()] = p[1]; } root.runningPids = pids; root.updateDisplayList(); } } }
  Process { id: taskScanProc; command: TaskManager.buildProcessScanScript(); stdout: StdioCollector { waitForEnd: true; onStreamFinished: { var u = Quickshell.env("USER") || ""; root.sysTelemetry = TaskManager.parseSystemHeaderStats(text, root.cpuHeaderState); root.rawTasks = TaskManager.parseProcessOutput(text, u, root.gpuStateMap, Date.now()); root.updateTaskDisplayList(); } } }
  Process { id: serviceScanProc; command: StartupServices.buildServicesScanScript(root.home); stdout: StdioCollector { waitForEnd: true; onStreamFinished: { root.rawServices = StartupServices.parseServicesOutput(text); root.updateServiceDisplayList(); } } }
  Process { id: janitorScanProc; command: JanitorOps.buildJanitorScanScript(root.home); stdout: StdioCollector { waitForEnd: true; onStreamFinished: { root.janitorStats = JanitorOps.parseJanitorStats(text); } } }
  Process {
    id: actionRunnerProc; stdout: StdioCollector { id: actOut; waitForEnd: true } stderr: StdioCollector { id: actErr; waitForEnd: true }
    onExited: function(code) {
      root.janitorCleaningCategory = ""; var out = actOut.text ? actOut.text.trim() : "";
      if (out.indexOf("CLEAN_OK:") !== -1) { root.janitorStatusMessage = out.split("CLEAN_OK:").pop().trim(); root.janitorStatusError = false; }
      else if (out.indexOf("CLEAN_ERR:") !== -1 || code !== 0) {
        var errStr = actErr.text ? actErr.text.trim() : "";
        root.janitorStatusMessage = out.indexOf("CLEAN_ERR:") !== -1 ? out.split("CLEAN_ERR:").pop().trim() : (errStr ? ("Action failed: " + errStr) : ("Action failed: Exit " + code));
        root.janitorStatusError = true;
      } else { root.janitorStatusMessage = "Operation completed successfully."; root.janitorStatusError = false; }
      root.refreshInventory(); root.refreshServices(); root.refreshJanitorStats();
    }
  }
  Process { id: uninstallProc; property var targetApp: null; stderr: StdioCollector { id: uninstErr; waitForEnd: true } onExited: function(code) { if (code === 0) { leftoverModal.phase = 2; root.runLeftoverScan(uninstallProc.targetApp); } else { leftoverModal.statusMessage = "Removal failed: " + uninstErr.text; } } }
  Process { id: leftoverScanProc; stdout: StdioCollector { waitForEnd: true; onStreamFinished: { var items = LeftoverHunter.parseScanOutput(text, root.home, SafeOps); root.foundLeftovers = items; leftoverModal.leftoverItems = items; leftoverModal.updateTotalSelected(); leftoverModal.phase = 3; } } }
  Process { id: leftoverPurgeProc; onExited: { leftoverModal.isPurging = false; leftoverModal.phase = 4; orphanCheckProc.running = true; } }
  Process { id: orphanCheckProc; command: ["bash", "-c", "pacman -Qtdq 2>/dev/null || echo NO_ORPHANS"]; stdout: StdioCollector { waitForEnd: true; onStreamFinished: { var t = text.trim(); root.orphanList = (t && t !== "NO_ORPHANS") ? t : ""; } } }

  function checkSudoStatus() { if (!sudoStatusProc.running) sudoStatusProc.running = true; }
  function lockSudo() { Util.execDetached(["sudo", "-k"]); root.sudoActive = false; root.janitorStatusMessage = "Administrator session locked."; root.janitorStatusError = false; }
  function refreshInventory() { if (!inventoryProc.running) inventoryProc.running = true; }; function refreshProcessStatus() { if (!procCheck.running) procCheck.running = true; }
  function refreshTasks() { if (!taskScanProc.running) taskScanProc.running = true; }; function refreshServices() { if (!serviceScanProc.running) serviceScanProc.running = true; }
  function refreshJanitorStats() { if (!janitorScanProc.running) janitorScanProc.running = true; }; function savePreferences() { var cmd = StateStore.buildSavePrefsCommand(root.prefs, root.home); if (cmd) Util.execDetached(cmd); }
  function promptSudo(msg, callback) { root.sudoErrorMessage = msg || ""; root.pendingSudoCallback = callback; root.sudoModalOpen = true; sudoModal.initFocus(); }

  function toggleAppSort(col) { root.appSortDirection = (root.activeSort === col) ? (root.appSortDirection === "desc" ? "asc" : "desc") : ((col === "name" || col === "category" || col === "version") ? "asc" : "desc"); root.activeSort = col; root.updateDisplayList(); }
  function toggleAppPin(pkg) { if (!pkg) return; if (!root.prefs.pinnedApps) root.prefs.pinnedApps = {}; if (root.prefs.pinnedApps[pkg]) delete root.prefs.pinnedApps[pkg]; else root.prefs.pinnedApps[pkg] = true; root.savePreferences(); root.updateDisplayList(); }
  function toggleTaskPin(name) { if (!name) return; if (!root.prefs.pinnedTasks) root.prefs.pinnedTasks = {}; if (root.prefs.pinnedTasks[name]) delete root.prefs.pinnedTasks[name]; else root.prefs.pinnedTasks[name] = true; root.savePreferences(); root.updateTaskDisplayList(); }
  function toggleBatchPkg(pkg) { if (!pkg) return; if (root.selectedBatchMap[pkg]) delete root.selectedBatchMap[pkg]; else root.selectedBatchMap[pkg] = true; root.selectedBatchCount = Object.keys(root.selectedBatchMap).length; root.updateDisplayList(); }

  function updateDisplayList() {
    var filtered = Sorter.filterItems(root.rawItems, root.activeCategory, root.filterText);
    var sorted = Sorter.sortItems(filtered, root.activeSort, root.appSortDirection, root.prefs.pinnedApps);
    root.displayItems = sorted;
    ModelSync.syncAppModel(appListModel, sorted, root.runningPids, root.prefs.pinnedApps, root.selectedBatchMap);
    if (root.selectedIndex >= sorted.length) root.selectedIndex = Math.max(0, sorted.length - 1);
  }
  function updateTaskDisplayList() {
    var u = Quickshell.env("USER") || "";
    var filtered = TaskManager.filterTasks(root.rawTasks, root.taskFilterText, root.taskCategory, u);
    var baseList = root.prefs.groupTasks ? TaskManager.groupTasksByApp(filtered, root.expandedGroups) : filtered;
    var sorted = TaskManager.sortTasks(baseList, root.taskSort, root.taskSortDirection, root.prefs.pinnedTasks);
    root.displayTasks = sorted;
    ModelSync.syncTaskModel(taskListModel, sorted, root.prefs.pinnedTasks);
    if (root.selectedTaskPid > 0) { for (var i = 0; i < sorted.length; i++) { if (sorted[i].pid === root.selectedTaskPid) { root.selectedTaskIndex = i; return; } } }
    if (root.selectedTaskIndex >= sorted.length) root.selectedTaskIndex = Math.max(0, sorted.length - 1);
  }
  function updateServiceDisplayList() {
    var filtered = StartupServices.filterServices(root.rawServices, root.serviceCategory, root.serviceFilterText);
    var sorted = StartupServices.sortServices(filtered, root.serviceSort, root.serviceSortDirection);
    root.displayServices = sorted;
    ModelSync.syncServiceModel(serviceListModel, sorted);
    if (root.selectedServiceIndex >= sorted.length) root.selectedServiceIndex = Math.max(0, sorted.length - 1);
  }

  function runTaskCmd(cmd) { if (cmd) { Util.execDetached(cmd); Qt.callLater(function() { root.refreshTasks(); }); } }
  function killAppProcess(app) { if (!app) return; var t = app.exec ? app.exec.split(/\s+/)[0].split("/").pop() : app.pkg; Util.execDetached(["pkill", "-f", t]); Qt.callLater(function() { root.refreshProcessStatus(); }); }

  function startDeepUninstall(app) {
    if (!app || app.isProtected) return;
    if (!root.sudoActive && app.category !== "webapp" && app.category !== "appimage" && app.category !== "flatpak") { root.promptSudo("Sudo required to uninstall " + app.pkg, function() { root.startDeepUninstall(app); }); return; }
    root.currentUninstallApp = app; leftoverModal.phase = 1; leftoverModal.statusMessage = "Removing " + app.pkg + "..."; root.leftoverModalOpen = true; leftoverModal.isOpen = true; uninstallProc.targetApp = app;
    if (app.category === "webapp") uninstallProc.command = ["bash", "-c", "rm -f " + SafeOps.shellEscape(root.home + "/.local/share/applications/" + app.desktopFile)];
    else if (app.category === "appimage") uninstallProc.command = ["rm", "-f", app.exec];
    else uninstallProc.command = SudoKeeper.buildUninstallCommand(app.pkg, app.category);
    uninstallProc.running = true;
  }
  function startBatchUninstall() {
    var pkgs = Object.keys(root.selectedBatchMap); if (pkgs.length === 0) return;
    if (!root.sudoActive) { root.promptSudo("Sudo required for batch uninstall", function() { root.startBatchUninstall(); }); return; }
    var cmd = SudoKeeper.buildBatchUninstallCommand(pkgs);
    if (cmd) { root.selectedBatchMap = {}; root.selectedBatchCount = 0; actionRunnerProc.command = cmd; actionRunnerProc.running = true; }
  }
  function downgradePackage(pkg, path) {
    if (!root.sudoActive) { root.promptSudo("Sudo required to downgrade " + pkg, function() { root.downgradePackage(pkg, path); }); return; }
    var cmd = SudoKeeper.buildDowngradeCommand(path); if (cmd) { actionRunnerProc.command = cmd; actionRunnerProc.running = true; }
  }
  function runLeftoverScan(app) { var sc = LeftoverHunter.buildScanScript(app, root.home, SafeOps); if (!sc) { leftoverModal.phase = 3; return; } leftoverScanProc.command = sc.argv; leftoverScanProc.running = true; }
  function scanOrphanDotfiles() { var sc = LeftoverHunter.buildOrphanDotfilesScanScript(root.home, SafeOps); if (!sc) return; root.currentUninstallApp = null; leftoverModal.phase = 2; leftoverModal.statusMessage = "Scanning ~/.cache and ~/.config for orphaned directories..."; root.leftoverModalOpen = true; leftoverModal.isOpen = true; leftoverScanProc.command = sc; leftoverScanProc.running = true; }
  function purgeLeftovers(paths) {
    if (!paths || paths.length === 0) { leftoverModal.phase = 4; orphanCheckProc.running = true; return; }
    leftoverModal.isPurging = true;
    var b = SafeOps.buildBackupCommand(paths, root.currentUninstallApp ? root.currentUninstallApp.pkg : "orphans", root.home);
    var p = SafeOps.buildPurgeCommand(paths, root.home);
    leftoverPurgeProc.command = ["bash", "-c", (b && p) ? (b.command + " && " + p.command) : (p ? p.command : "true")]; leftoverPurgeProc.running = true;
  }
  function triggerServiceAction(item, act) {
    if (!item) return;
    if (item.scope === "system" && !root.sudoActive) { root.promptSudo("Sudo required for system service", function() { root.triggerServiceAction(item, act); }); return; }
    var cmd = StartupServices.buildServiceActionCommand(item, act, root.sudoActive, root.home);
    if (cmd) { actionRunnerProc.command = cmd; actionRunnerProc.running = true; }
  }
  function runJanitorClean(cat) {
    if ((cat === "orphans" || cat === "pacman" || cat === "journal") && !root.sudoActive) { root.promptSudo("Sudo required for system cleanup", function() { root.runJanitorClean(cat); }); return; }
    root.janitorCleaningCategory = cat; root.janitorStatusMessage = "Cleaning " + cat + "..."; root.janitorStatusError = false;
    actionRunnerProc.command = (cat === "orphans") ? SudoKeeper.buildOrphanPruneCommand() : ((cat === "pacman") ? SudoKeeper.buildCacheCleanCommand() : JanitorOps.buildCleanCommand(cat));
    if (actionRunnerProc.command) actionRunnerProc.running = true;
  }
  function restoreBackupArchive(name) { var cmd = SafeOps.buildRestoreBackupCommand(root.home + "/.local/share/omapp/backups/" + name, root.home); if (cmd) { root.janitorStatusMessage = "Restoring backup " + name + "..."; root.janitorStatusError = false; actionRunnerProc.command = cmd; actionRunnerProc.running = true; } }
  function handleContextAction(actId) {
    var t = root.contextTarget; if (!t) return;
    if (root.activeTab === "apps") {
      if (actId === "launch" && t.exec) Util.execDetached(["bash", "-c", t.exec + " &"]);
      else if (actId === "pin") root.toggleAppPin(t.pkg);
      else if (actId === "batch") root.toggleBatchPkg(t.pkg);
      else if (actId === "config") Util.execDetached(["xdg-open", root.home + "/.config"]);
      else if (actId === "uninstall") root.startDeepUninstall(t);
    } else if (root.activeTab === "tasks") {
      if (actId === "pin") root.toggleTaskPin(t.name);
      else if (actId === "freeze") root.runTaskCmd(TaskControl.buildFreezeCommand(t.pid, !t.isFrozen, root.sudoActive));
      else if (actId === "renice_high" || actId === "renice_low") root.runTaskCmd(TaskControl.buildReniceCommand(t.pid, actId === "renice_high" ? -10 : 10, root.sudoActive));
      else if (actId === "folder") root.runTaskCmd(TaskControl.buildOpenFileLocationCommand(t.pid));
      else if (actId === "kill" || actId === "force_kill") root.runTaskCmd(TaskControl.buildKillCommand(t.pid, actId === "force_kill", root.sudoActive));
    } else if (root.activeTab === "services") root.triggerServiceAction(t, actId);
  }
}
