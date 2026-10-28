import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "script/TaskManager.js" as TaskManager

Item {
  id: taskViewRoot

  property var taskModel: null
  property var tasks: []
  property int selectedIndex: 0
  property var shell: null
  property string currentUser: Quickshell.env("USER") || ""
  property string activeCategory: "all"
  property string activeSort: "cpu" // "cpu", "mem", "gpu", "pid", "name"
  property string sortDirection: "desc" // "desc", "asc"
  property string filterText: ""
  property bool sudoActive: false

  property var inspectedTask: (tasks.length > 0 && selectedIndex >= 0 && selectedIndex < tasks.length)
    ? tasks[selectedIndex] : null
  property int currentInspectedPid: -1
  property var inspectedDetails: ({ exe: "", cwd: "", cmd: "", pkg: "" })
  property bool isDetailsLoading: false

  signal taskSelected(int index, int pid)
  signal killRequested(int pid, bool force)
  signal openLocationRequested(int pid)
  signal inspectPackageRequested(string pkg)
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

  onInspectedTaskChanged: {
    if (inspectedTask) {
      if (inspectedTask.pid !== taskViewRoot.currentInspectedPid) {
        taskViewRoot.currentInspectedPid = inspectedTask.pid;
        taskViewRoot.isDetailsLoading = true;
        detailsProc.command = TaskManager.buildGetProcessDetailsScript(inspectedTask.pid);
        detailsProc.running = true;
      }
    } else {
      taskViewRoot.currentInspectedPid = -1;
      taskViewRoot.inspectedDetails = { exe: "", cwd: "", cmd: "", pkg: "" };
      taskViewRoot.isDetailsLoading = false;
    }
  }

  Process {
    id: detailsProc
    stdout: StdioCollector {
      id: detailsOut
      waitForEnd: true
      onStreamFinished: {
        taskViewRoot.inspectedDetails = TaskManager.parseProcessDetails(text);
        taskViewRoot.isDetailsLoading = false;
      }
    }
  }

  Row {
    anchors.fill: parent
    spacing: Style.space(14)

    // Left Pane: Windows Task Manager Style Process Table
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

        // Windows Task Manager Style Clickable Column Header Bar
        BorderSurface {
          width: parent.width
          height: Style.space(30)
          radius: Style.cornerRadius
          color: Style.hoverFill
          borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(6)

            // 1. Process Name Column Header
            Item {
              height: parent.height
              width: Math.max(Style.space(120), parent.width - Style.space(308))

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "Process Name" + (taskViewRoot.activeSort === "name" ? (taskViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : "")
                color: taskViewRoot.activeSort === "name" ? Color.accent : (nameHeaderMouse.containsMouse ? Color.menu.text : Color.muted)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              MouseArea {
                id: nameHeaderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: taskViewRoot.toggleSort("name")
              }
            }

            // 2. PID Column Header
            Item {
              height: parent.height
              width: Style.space(58)

              Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "PID" + (taskViewRoot.activeSort === "pid" ? (taskViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : "")
                color: taskViewRoot.activeSort === "pid" ? Color.accent : (pidHeaderMouse.containsMouse ? Color.menu.text : Color.muted)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              MouseArea {
                id: pidHeaderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: taskViewRoot.toggleSort("pid")
              }
            }

            // 3. CPU Column Header
            Item {
              height: parent.height
              width: Style.space(68)

              Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "CPU" + (taskViewRoot.activeSort === "cpu" ? (taskViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : "")
                color: taskViewRoot.activeSort === "cpu" ? Color.accent : (cpuHeaderMouse.containsMouse ? Color.menu.text : Color.muted)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              MouseArea {
                id: cpuHeaderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: taskViewRoot.toggleSort("cpu")
              }
            }

            // 4. GPU Column Header
            Item {
              height: parent.height
              width: Style.space(76)

              Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "GPU" + (taskViewRoot.activeSort === "gpu" ? (taskViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : "")
                color: taskViewRoot.activeSort === "gpu" ? Color.accent : (gpuHeaderMouse.containsMouse ? Color.menu.text : Color.muted)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              MouseArea {
                id: gpuHeaderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: taskViewRoot.toggleSort("gpu")
              }
            }

            // 5. RAM Column Header
            Item {
              height: parent.height
              width: Style.space(82)

              Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "RAM" + ((taskViewRoot.activeSort === "mem" || taskViewRoot.activeSort === "ram") ? (taskViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : "")
                color: (taskViewRoot.activeSort === "mem" || taskViewRoot.activeSort === "ram") ? Color.accent : (memHeaderMouse.containsMouse ? Color.menu.text : Color.muted)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              MouseArea {
                id: memHeaderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: taskViewRoot.toggleSort("mem")
              }
            }
          }
        }

        // Process ListView bound to persistent ListModel for zero-jitter touchpad scrolling
        ListView {
          id: taskListView
          width: parent.width
          height: parent.height - Style.space(34)
          model: taskViewRoot.taskModel
          currentIndex: taskViewRoot.selectedIndex
          spacing: Style.space(2)
          pixelAligned: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          flickDeceleration: 1500
          maximumFlickVelocity: 2500
          highlightMoveDuration: 0
          clip: true

          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

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
            required property bool isMine

            readonly property bool isRowSelected: index === taskViewRoot.selectedIndex

            width: ListView.view ? ListView.view.width : Style.space(400)
            height: Style.space(34)
            foreground: Color.menu.text
            accent: Color.accent
            current: isRowSelected
            hasCursor: taskRowMouse.containsMouse

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(6)

              // 1. Process Name + User Icon
              Row {
                height: parent.height
                width: Math.max(Style.space(120), parent.width - Style.space(308))
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: taskRow.cpu > 5.0 ? "󰓅" : (taskRow.isMine ? "󰀄" : "󰒋")
                  color: taskRow.cpu > 5.0 ? Color.urgent : (taskRow.isMine ? Color.accent : Color.muted)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  width: parent.width - Style.space(22)
                  text: taskRow.name
                  color: taskRow.isRowSelected ? Color.accent : Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: taskRow.isRowSelected
                  elide: Text.ElideRight
                }
              }

              // 2. PID Column
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(58)
                textFormat: Text.PlainText
                text: String(taskRow.pid)
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignRight
              }

              // 3. CPU % Column (Heatmap cell using theme tokens)
              BorderSurface {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(68)
                height: Style.space(22)
                radius: Style.cornerRadius
                color: {
                  if (taskRow.cpu >= 20.0) return Util.alpha(Color.urgent, Style.selectedFillAlpha);
                  if (taskRow.cpu >= 5.0) return Util.alpha(Color.accent, Style.hoverFillAlpha);
                  return "transparent";
                }

                Text {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: taskRow.cpuFormatted
                  color: {
                    if (taskRow.cpu >= 20.0) return Color.urgent;
                    if (taskRow.cpu >= 5.0) return Color.accent;
                    return Color.menu.text;
                  }
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: taskRow.cpu >= 5.0
                }
              }

              // 4. GPU Column (Hybrid DRM + NVIDIA)
              BorderSurface {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(76)
                height: Style.space(22)
                radius: Style.cornerRadius
                color: taskRow.gpuPercent >= 5.0
                  ? Util.alpha(Color.accent, Style.hoverFillAlpha)
                  : "transparent"

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

              // 5. RAM Column
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(82)
                textFormat: Text.PlainText
                text: taskRow.rssFormatted
                color: taskRow.rss >= 500 * 1024 * 1024 ? Color.accent : Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: taskRow.rss >= 500 * 1024 * 1024
                horizontalAlignment: Text.AlignRight
              }
            }

            MouseArea {
              id: taskRowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                taskViewRoot.taskSelected(taskRow.index, taskRow.pid);
              }
            }
          }

          Item {
            anchors.fill: parent
            visible: taskViewRoot.tasks.length === 0

            Column {
              anchors.centerIn: parent
              spacing: Style.space(8)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.PlainText
                text: "󰍛"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.display
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.PlainText
                text: "No matching processes found"
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }
          }
        }
      }
    }

    // Right Pane: Process Inspector & Action Controls
    BorderSurface {
      width: parent.width * 0.40 - Style.space(14)
      height: parent.height
      radius: Style.cornerRadius
      color: Style.normalFill
      borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)
      clip: true

      Item {
        anchors.fill: parent
        visible: !taskViewRoot.inspectedTask

        Column {
          anchors.centerIn: parent
          spacing: Style.space(10)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: "󰍛"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.display
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: "Select a process to inspect & manage"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }
      }

      Flickable {
        anchors.fill: parent
        anchors.margins: Style.space(16)
        visible: !!taskViewRoot.inspectedTask
        contentHeight: pContentCol.implicitHeight
        pixelAligned: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: pContentCol
          width: parent.width
          spacing: Style.space(14)

          // Process Header
          Row {
            width: parent.width
            spacing: Style.space(12)

            BorderSurface {
              width: Style.space(44)
              height: Style.space(44)
              radius: Style.cornerRadius
              color: Style.hoverFill
              borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: taskViewRoot.inspectedTask && taskViewRoot.inspectedTask.cpu > 5.0 ? "󰓅" : "󰒋"
                color: taskViewRoot.inspectedTask && taskViewRoot.inspectedTask.cpu > 5.0 ? Color.urgent : Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.iconLarge
              }
            }

            Column {
              width: parent.width - Style.space(56)
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: taskViewRoot.inspectedTask ? taskViewRoot.inspectedTask.name : ""
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: taskViewRoot.inspectedTask
                  ? ("PID " + taskViewRoot.inspectedTask.pid + " • User: " + taskViewRoot.inspectedTask.user)
                  : ""
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
          }

          // Action Buttons using native qs.Ui.Button
          Flow {
            width: parent.width
            spacing: Style.space(8)

            Button {
              bordered: true
              iconText: "󰅙"
              text: "End Task"
              foreground: Color.urgent
              accent: Color.urgent
              background: Util.alpha(Color.urgent, Style.normalFillAlpha)
              onClicked: {
                if (taskViewRoot.inspectedTask) {
                  taskViewRoot.killRequested(taskViewRoot.inspectedTask.pid, false);
                }
              }
            }

            Button {
              bordered: true
              iconText: "󰚌"
              text: "Force Kill"
              foreground: Color.urgent
              accent: Color.urgent
              onClicked: {
                if (taskViewRoot.inspectedTask) {
                  taskViewRoot.killRequested(taskViewRoot.inspectedTask.pid, true);
                }
              }
            }

            Button {
              bordered: true
              iconText: "󰉋"
              text: "Open File Location"
              foreground: Color.menu.text
              accent: Color.accent
              onClicked: {
                if (taskViewRoot.inspectedTask) {
                  taskViewRoot.openLocationRequested(taskViewRoot.inspectedTask.pid);
                }
              }
            }

            Button {
              visible: !!taskViewRoot.inspectedDetails.pkg
              bordered: true
              iconText: "󰏖"
              text: "Package: " + taskViewRoot.inspectedDetails.pkg
              foreground: Color.accent
              accent: Color.accent
              onClicked: {
                taskViewRoot.inspectPackageRequested(taskViewRoot.inspectedDetails.pkg);
              }
            }
          }

          // 3-Column Resource Telemetry Card (CPU | GPU | RAM)
          BorderSurface {
            width: parent.width
            height: Style.space(62)
            radius: Style.cornerRadius
            color: Style.hoverFill
            borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(10)

              Column {
                width: parent.width / 3
                spacing: Style.space(2)
                Text {
                  textFormat: Text.PlainText
                  text: "CPU"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
                Text {
                  textFormat: Text.PlainText
                  text: taskViewRoot.inspectedTask ? taskViewRoot.inspectedTask.cpuFormatted : "0.0%"
                  color: taskViewRoot.inspectedTask && taskViewRoot.inspectedTask.cpu >= 20.0 ? Color.urgent : Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
              }

              Column {
                width: parent.width / 3
                spacing: Style.space(2)
                Text {
                  textFormat: Text.PlainText
                  text: "GPU / VRAM"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
                Text {
                  textFormat: Text.PlainText
                  text: {
                    if (!taskViewRoot.inspectedTask) return "0.0%";
                    var t = taskViewRoot.inspectedTask;
                    if (t.gpuPercent > 0 && t.gpuMemMiB > 0) return t.gpuPercent.toFixed(1) + "% · " + t.gpuMemMiB + "M";
                    return t.gpuFormatted;
                  }
                  color: taskViewRoot.inspectedTask && (taskViewRoot.inspectedTask.gpuPercent > 0 || taskViewRoot.inspectedTask.gpuMemMiB > 0)
                    ? Color.accent : Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width - Style.space(4)
                }
              }

              Column {
                width: parent.width / 3
                spacing: Style.space(2)
                Text {
                  textFormat: Text.PlainText
                  text: "Memory (RSS)"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
                Text {
                  textFormat: Text.PlainText
                  text: taskViewRoot.inspectedTask ? taskViewRoot.inspectedTask.rssFormatted : "0 B"
                  color: Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
              }
            }
          }

          PanelSeparator {
            foreground: Color.menu.text
          }

          // Process Details Table
          Column {
            width: parent.width
            spacing: Style.space(8)

            Row {
              width: parent.width
              Text { textFormat: Text.PlainText; width: Style.space(110); text: "Executable"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
              Text {
                textFormat: Text.PlainText
                width: parent.width - Style.space(110)
                text: taskViewRoot.isDetailsLoading ? "Loading..." : (taskViewRoot.inspectedDetails.exe || "Kernel thread / No binary")
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideMiddle
              }
            }

            Row {
              width: parent.width
              Text { textFormat: Text.PlainText; width: Style.space(110); text: "Package"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
              Text {
                textFormat: Text.PlainText
                width: parent.width - Style.space(110)
                text: taskViewRoot.isDetailsLoading ? "Checking..." : (taskViewRoot.inspectedDetails.pkg || "Unmanaged binary / daemon")
                color: taskViewRoot.inspectedDetails.pkg ? Color.accent : Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: !!taskViewRoot.inspectedDetails.pkg
                elide: Text.ElideRight
              }
            }

            Row {
              width: parent.width
              Text { textFormat: Text.PlainText; width: Style.space(110); text: "Working Dir"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
              Text {
                textFormat: Text.PlainText
                width: parent.width - Style.space(110)
                text: taskViewRoot.isDetailsLoading ? "-" : (taskViewRoot.inspectedDetails.cwd || "-")
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideMiddle
              }
            }

            Row {
              width: parent.width
              Text { textFormat: Text.PlainText; width: Style.space(110); text: "Command Line"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
              Text {
                textFormat: Text.PlainText
                width: parent.width - Style.space(110)
                text: taskViewRoot.isDetailsLoading ? "-" : (taskViewRoot.inspectedDetails.cmd || "-")
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WrapAnywhere
              }
            }
          }
        }
      }
    }
  }

  function isUserScrolling() {
    return taskListView.moving || taskListView.flicking || taskListView.dragging;
  }

  function positionAt(idx) {
    if (idx >= 0 && idx < taskListView.count) {
      taskListView.positionViewAtIndex(idx, ListView.Contain);
    }
  }
}
