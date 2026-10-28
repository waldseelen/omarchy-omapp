import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "ui"

Item {
  id: taskViewRoot

  property var taskModel: null
  property var tasks: []
  property int selectedIndex: 0
  property var shell: null
  property string activeCategory: "all"
  property string activeSort: "cpu" // "cpu", "mem", "gpu", "disk", "pid", "name"
  property string sortDirection: "desc"
  property string filterText: ""
  property bool sudoActive: false
  property var colWidths: ({ pid: 52, cpu: 58, gpu: 64, ram: 68, disk: 68 })

  property var inspectedTask: (tasks.length > 0 && selectedIndex >= 0 && selectedIndex < tasks.length)
    ? tasks[selectedIndex] : null

  signal taskSelected(int index, int pid)
  signal killRequested(int pid, bool force)
  signal freezeRequested(int pid, bool freeze)
  signal reniceRequested(int pid, int priority)
  signal affinityRequested(int pid, string cpuList)
  signal openLocationRequested(int pid)
  signal inspectPackageRequested(string pkg)
  signal togglePinRequested(string name)
  signal toggleGroupExpandRequested(string appName)
  signal contextMenuRequested(real x, real y, var taskObj)
  signal refreshRequested()
  signal sortRequested(string mode, string direction)

  function toggleSort(column) {
    var nextDir = "desc";
    if (taskViewRoot.activeSort === column) {
      nextDir = (taskViewRoot.sortDirection === "desc") ? "asc" : "desc";
    } else {
      nextDir = (column === "name") ? "asc" : "desc";
    }
    taskViewRoot.activeSort = column;
    taskViewRoot.sortDirection = nextDir;
    taskViewRoot.sortRequested(column, nextDir);
  }

  Row {
    anchors.fill: parent
    spacing: Style.space(14)

    // Left Pane: Process Table with Clickable Column Headers
    BorderSurface {
      width: parent.width * 0.60
      height: parent.height
      radius: Style.cornerRadius
      color: Style.normalFill
      borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)
      clip: true

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(6)
        spacing: Style.space(4)

        BorderSurface {
          width: parent.width
          height: Style.space(30)
          radius: Style.cornerRadius
          color: Style.hoverFill
          borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(5)

            // 1. Process Name
            Item {
              height: parent.height
              width: Math.max(
                Style.space(100),
                parent.width - (taskViewRoot.colWidths.pid + taskViewRoot.colWidths.cpu + taskViewRoot.colWidths.gpu + taskViewRoot.colWidths.ram + taskViewRoot.colWidths.disk + Style.space(42))
              )
              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "Process Name" + (taskViewRoot.activeSort === "name" ? (taskViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : "")
                color: taskViewRoot.activeSort === "name" ? Color.accent : Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: taskViewRoot.toggleSort("name") }
            }

            // 2. PID
            Item {
              height: parent.height; width: taskViewRoot.colWidths.pid
              Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "PID" + (taskViewRoot.activeSort === "pid" ? (taskViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : ""); color: taskViewRoot.activeSort === "pid" ? Color.accent : Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: taskViewRoot.toggleSort("pid") }
            }
            // 3. CPU
            Item {
              height: parent.height; width: taskViewRoot.colWidths.cpu
              Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "CPU" + (taskViewRoot.activeSort === "cpu" ? (taskViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : ""); color: taskViewRoot.activeSort === "cpu" ? Color.accent : Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: taskViewRoot.toggleSort("cpu") }
            }
            // 4. GPU
            Item {
              height: parent.height; width: taskViewRoot.colWidths.gpu
              Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "GPU" + (taskViewRoot.activeSort === "gpu" ? (taskViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : ""); color: taskViewRoot.activeSort === "gpu" ? Color.accent : Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: taskViewRoot.toggleSort("gpu") }
            }
            // 5. RAM
            Item {
              height: parent.height; width: taskViewRoot.colWidths.ram
              Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "RAM" + ((taskViewRoot.activeSort === "mem" || taskViewRoot.activeSort === "ram") ? (taskViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : ""); color: (taskViewRoot.activeSort === "mem" || taskViewRoot.activeSort === "ram") ? Color.accent : Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: taskViewRoot.toggleSort("mem") }
            }
            // 6. Disk I/O (#5)
            Item {
              height: parent.height; width: taskViewRoot.colWidths.disk
              Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "Disk" + (taskViewRoot.activeSort === "disk" ? (taskViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : ""); color: taskViewRoot.activeSort === "disk" ? Color.accent : Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: taskViewRoot.toggleSort("disk") }
            }
          }
        }

        ListView {
          id: taskListView
          width: parent.width
          height: parent.height - Style.space(34)
          model: taskViewRoot.taskModel
          currentIndex: taskViewRoot.selectedIndex
          spacing: Style.space(2)
          pixelAligned: false
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          flickDeceleration: 750
          maximumFlickVelocity: 6000
          highlightMoveDuration: 0
          clip: true

          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
              scrollActiveTimer.restart();
              var dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y * 1.8 : (event.angleDelta.y / 120 * Style.space(50));
              if (dy !== 0) {
                var maxY = Math.max(0, taskListView.contentHeight - taskListView.height);
                taskListView.contentY = Math.max(0, Math.min(maxY, taskListView.contentY - dy));
                event.accepted = true;
              }
            }
          }

          delegate: CursorSurface {
            id: taskRow
            required property int index
            required property int pid
            required property string name
            required property string user
            required property real cpu
            required property string cpuFormatted
            required property real gpu
            required property real gpuPercent
            required property int gpuMemMiB
            required property string gpuFormatted
            required property real rss
            required property string rssFormatted
            required property real diskBps
            required property string diskFormatted
            required property bool isMine
            required property bool isFrozen
            required property bool pinned
            required property int groupCount

            readonly property bool isRowSelected: index === taskViewRoot.selectedIndex

            width: ListView.view ? ListView.view.width : Style.space(400)
            height: Style.space(34)
            foreground: Color.menu.text
            accent: Color.accent
            current: isRowSelected
            hasCursor: taskRowMouse.containsMouse

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(5)

              // 1. Process Name + Group/Pin/Frozen Badges
              Row {
                height: parent.height
                width: Math.max(
                  Style.space(100),
                  parent.width - (taskViewRoot.colWidths.pid + taskViewRoot.colWidths.cpu + taskViewRoot.colWidths.gpu + taskViewRoot.colWidths.ram + taskViewRoot.colWidths.disk + Style.space(42))
                )
                spacing: Style.space(6)

                Text {
                  visible: taskRow.pinned
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "󰐃"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: taskRow.isFrozen ? "󰜗" : (taskRow.cpu > 5.0 ? "󰓅" : (taskRow.isMine ? "󰀄" : "󰒋"))
                  color: taskRow.isFrozen ? Color.accent : (taskRow.cpu > 5.0 ? Color.urgent : (taskRow.isMine ? Color.accent : Color.muted))
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  width: parent.width - Style.space(36)
                  text: taskRow.name + (taskRow.groupCount > 1 ? " (" + taskRow.groupCount + ")" : "")
                  color: taskRow.isRowSelected ? Color.accent : Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: taskRow.isRowSelected || taskRow.groupCount > 1
                  elide: Text.ElideRight
                }
              }

              // 2. PID
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: taskViewRoot.colWidths.pid
                textFormat: Text.PlainText
                text: String(taskRow.pid)
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignRight
              }

              // 3. CPU
              BorderSurface {
                anchors.verticalCenter: parent.verticalCenter
                width: taskViewRoot.colWidths.cpu
                height: Style.space(22)
                radius: Style.cornerRadius
                color: taskRow.cpu >= 20.0 ? Util.alpha(Color.urgent, Style.selectedFillAlpha) : (taskRow.cpu >= 5.0 ? Util.alpha(Color.accent, Style.hoverFillAlpha) : "transparent")

                Text {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: taskRow.cpuFormatted
                  color: taskRow.cpu >= 20.0 ? Color.urgent : (taskRow.cpu >= 5.0 ? Color.accent : Color.menu.text)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: taskRow.cpu >= 5.0
                }
              }

              // 4. GPU
              BorderSurface {
                anchors.verticalCenter: parent.verticalCenter
                width: taskViewRoot.colWidths.gpu
                height: Style.space(22)
                radius: Style.cornerRadius
                color: taskRow.gpuPercent >= 5.0 ? Util.alpha(Color.accent, Style.hoverFillAlpha) : "transparent"

                Text {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: taskRow.gpuFormatted
                  color: (taskRow.gpuPercent > 0 || taskRow.gpuMemMiB > 0) ? Color.accent : Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: taskRow.gpuPercent > 0
                }
              }

              // 5. RAM
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: taskViewRoot.colWidths.ram
                textFormat: Text.PlainText
                text: taskRow.rssFormatted
                color: taskRow.rss >= 500 * 1024 * 1024 ? Color.accent : Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: taskRow.rss >= 500 * 1024 * 1024
                horizontalAlignment: Text.AlignRight
              }

              // 6. Disk I/O (#5)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: taskViewRoot.colWidths.disk
                textFormat: Text.PlainText
                text: taskRow.diskFormatted
                color: taskRow.diskBps > 0 ? Color.accent : Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignRight
              }
            }

            MouseArea {
              id: taskRowMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              cursorShape: Qt.PointingHandCursor
              onClicked: function(mouse) {
                taskViewRoot.taskSelected(taskRow.index, taskRow.pid);
                if (mouse.button === Qt.RightButton) {
                  var gp = taskRow.mapToItem(null, mouse.x, mouse.y);
                  var tObj = taskViewRoot.tasks[taskRow.index];
                  if (tObj) taskViewRoot.contextMenuRequested(gp.x, gp.y, tObj);
                }
              }
              onDoubleClicked: {
                if (taskRow.groupCount > 1) taskViewRoot.toggleGroupExpandRequested(taskRow.name);
              }
            }
          }
        }
      }
    }

    // Right Pane: Extracted TaskInspector
    TaskInspector {
      width: parent.width * 0.40 - Style.space(14)
      height: parent.height
      inspectedTask: taskViewRoot.inspectedTask
      sudoActive: taskViewRoot.sudoActive

      onKillRequested: function(pid, force) { taskViewRoot.killRequested(pid, force); }
      onFreezeRequested: function(pid, freeze) { taskViewRoot.freezeRequested(pid, freeze); }
      onReniceRequested: function(pid, prio) { taskViewRoot.reniceRequested(pid, prio); }
      onAffinityRequested: function(pid, cpus) { taskViewRoot.affinityRequested(pid, cpus); }
      onOpenLocationRequested: function(pid) { taskViewRoot.openLocationRequested(pid); }
      onInspectPackageRequested: function(pkg) { taskViewRoot.inspectPackageRequested(pkg); }
      onTogglePinRequested: function(name) { taskViewRoot.togglePinRequested(name); }
    }
  }

  Timer {
    id: scrollActiveTimer
    interval: 1200
    repeat: false
  }

  function isUserScrolling() {
    return taskListView.moving || taskListView.flicking || taskListView.dragging || scrollActiveTimer.running;
  }

  function positionAt(idx) {
    if (idx >= 0 && idx < taskListView.count) {
      taskListView.positionViewAtIndex(idx, ListView.Contain);
    }
  }
}
