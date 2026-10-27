import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "script/TaskManager.js" as TaskManager

Rectangle {
  id: taskViewRoot

  property var tasks: []
  property int selectedIndex: 0
  property var shell: null
  property string currentUser: Quickshell.env("USER") || ""
  property string activeCategory: "all"
  property string activeSort: "cpu" // "cpu", "mem", "gpu", "pid", "user", "name"
  property string sortDirection: "desc" // "desc", "asc"
  property string filterText: ""
  property bool sudoActive: false

  // Inspected task details with stable PID tracking (Prevents flickering "Loading...")
  property var inspectedTask: (tasks.length > 0 && selectedIndex >= 0 && selectedIndex < tasks.length)
    ? tasks[selectedIndex] : null
  property int currentInspectedPid: -1
  property var inspectedDetails: ({ exe: "", cwd: "", cmd: "", pkg: "" })
  property bool isDetailsLoading: false

  signal killRequested(int pid, bool force)
  signal openLocationRequested(int pid)
  signal inspectPackageRequested(string pkg)
  signal refreshRequested()
  signal sortRequested(string mode, string direction)

  radius: Style.cornerRadius
  color: "transparent"

  function toggleSort(column) {
    var nextDir = "desc";
    if (taskViewRoot.activeSort === column) {
      nextDir = (taskViewRoot.sortDirection === "desc") ? "asc" : "desc";
    } else {
      nextDir = (column === "name" || column === "user") ? "asc" : "desc";
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

    // Left Pane: Windows-style Interactive Process Table
    Rectangle {
      width: parent.width * 0.58
      height: parent.height
      radius: Style.cornerRadius
      color: Util.alpha(Color.menu.selectedBackground, 0.08)
      border.width: 1
      border.color: Util.alpha(Color.menu.border, 0.3)
      clip: true

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(6)
        spacing: Style.space(2)

        // Column Headers (Windows Task Manager Style with integrated sorting)
        Rectangle {
          width: parent.width
          height: Style.space(28)
          radius: Style.space(4)
          color: Util.alpha(Color.menu.selectedBackground, 0.15)
          border.width: 1
          border.color: Util.alpha(Color.menu.border, 0.2)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(6)

            // 1. Process Name Column Header
            Rectangle {
              height: parent.height
              width: parent.width - Style.space(340) // Flexible width
              color: nameHeaderMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.25) : "transparent"
              radius: Style.space(4)

              Row {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Text {
                  text: "Process Name"
                  color: taskViewRoot.activeSort === "name" ? Color.accent : Util.alpha(Color.menu.text, 0.7)
                  font.family: Style.font.family
                  font.pixelSize: Style.space(11)
                  font.weight: taskViewRoot.activeSort === "name" ? Font.Bold : Font.DemiBold
                }

                Text {
                  visible: taskViewRoot.activeSort === "name"
                  text: taskViewRoot.sortDirection === "asc" ? "▲" : "▼"
                  color: Color.accent
                  font.pixelSize: Style.space(9)
                }
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
            Rectangle {
              height: parent.height
              width: Style.space(55)
              color: pidHeaderMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.25) : "transparent"
              radius: Style.space(4)

              Row {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Text {
                  text: "PID"
                  color: taskViewRoot.activeSort === "pid" ? Color.accent : Util.alpha(Color.menu.text, 0.7)
                  font.family: Style.font.family
                  font.pixelSize: Style.space(11)
                  font.weight: taskViewRoot.activeSort === "pid" ? Font.Bold : Font.DemiBold
                }

                Text {
                  visible: taskViewRoot.activeSort === "pid"
                  text: taskViewRoot.sortDirection === "asc" ? "▲" : "▼"
                  color: Color.accent
                  font.pixelSize: Style.space(9)
                }
              }

              MouseArea {
                id: pidHeaderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: taskViewRoot.toggleSort("pid")
              }
            }

            // 3. User Column Header
            Rectangle {
              height: parent.height
              width: Style.space(55)
              color: userHeaderMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.25) : "transparent"
              radius: Style.space(4)

              Row {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Text {
                  text: "User"
                  color: taskViewRoot.activeSort === "user" ? Color.accent : Util.alpha(Color.menu.text, 0.7)
                  font.family: Style.font.family
                  font.pixelSize: Style.space(11)
                  font.weight: taskViewRoot.activeSort === "user" ? Font.Bold : Font.DemiBold
                }

                Text {
                  visible: taskViewRoot.activeSort === "user"
                  text: taskViewRoot.sortDirection === "asc" ? "▲" : "▼"
                  color: Color.accent
                  font.pixelSize: Style.space(9)
                }
              }

              MouseArea {
                id: userHeaderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: taskViewRoot.toggleSort("user")
              }
            }

            // 4. CPU Column Header
            Rectangle {
              height: parent.height
              width: Style.space(65)
              color: cpuHeaderMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.25) : "transparent"
              radius: Style.space(4)

              Row {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Text {
                  text: "CPU %"
                  color: taskViewRoot.activeSort === "cpu" ? Color.accent : Util.alpha(Color.menu.text, 0.7)
                  font.family: Style.font.family
                  font.pixelSize: Style.space(11)
                  font.weight: taskViewRoot.activeSort === "cpu" ? Font.Bold : Font.DemiBold
                }

                Text {
                  visible: taskViewRoot.activeSort === "cpu"
                  text: taskViewRoot.sortDirection === "asc" ? "▲" : "▼"
                  color: Color.accent
                  font.pixelSize: Style.space(9)
                }
              }

              MouseArea {
                id: cpuHeaderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: taskViewRoot.toggleSort("cpu")
              }
            }

            // 5. Memory / RAM Column Header
            Rectangle {
              height: parent.height
              width: Style.space(75)
              color: memHeaderMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.25) : "transparent"
              radius: Style.space(4)

              Row {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Text {
                  text: "Memory"
                  color: (taskViewRoot.activeSort === "mem" || taskViewRoot.activeSort === "ram") ? Color.accent : Util.alpha(Color.menu.text, 0.7)
                  font.family: Style.font.family
                  font.pixelSize: Style.space(11)
                  font.weight: (taskViewRoot.activeSort === "mem" || taskViewRoot.activeSort === "ram") ? Font.Bold : Font.DemiBold
                }

                Text {
                  visible: (taskViewRoot.activeSort === "mem" || taskViewRoot.activeSort === "ram")
                  text: taskViewRoot.sortDirection === "asc" ? "▲" : "▼"
                  color: Color.accent
                  font.pixelSize: Style.space(9)
                }
              }

              MouseArea {
                id: memHeaderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: taskViewRoot.toggleSort("mem")
              }
            }

            // 6. GPU Column Header
            Rectangle {
              height: parent.height
              width: Style.space(55)
              color: gpuHeaderMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.25) : "transparent"
              radius: Style.space(4)

              Row {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Text {
                  text: "GPU"
                  color: taskViewRoot.activeSort === "gpu" ? Color.accent : Util.alpha(Color.menu.text, 0.7)
                  font.family: Style.font.family
                  font.pixelSize: Style.space(11)
                  font.weight: taskViewRoot.activeSort === "gpu" ? Font.Bold : Font.DemiBold
                }

                Text {
                  visible: taskViewRoot.activeSort === "gpu"
                  text: taskViewRoot.sortDirection === "asc" ? "▲" : "▼"
                  color: Color.accent
                  font.pixelSize: Style.space(9)
                }
              }

              MouseArea {
                id: gpuHeaderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: taskViewRoot.toggleSort("gpu")
              }
            }
          }
        }

        // Process List View with Buttery-Smooth Touchpad Scrolling
        ListView {
          id: taskListView
          width: parent.width
          height: parent.height - Style.space(32)
          model: taskViewRoot.tasks
          currentIndex: taskViewRoot.selectedIndex
          spacing: Style.space(2)
          pixelAligned: true
          reuseItems: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          highlightMoveDuration: 0
          clip: true

          delegate: Rectangle {
            id: taskRow
            width: ListView.view ? ListView.view.width : Style.space(400)
            height: Style.space(38)
            radius: Style.space(4)

            // Omarchy-compliant background & border
            color: index === taskViewRoot.selectedIndex
              ? Util.alpha(Color.accent, 0.12)
              : (taskRowMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.2) : "transparent")

            // Left Accent Stroke when selected
            Rectangle {
              visible: index === taskViewRoot.selectedIndex
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: 2
              color: Color.accent
            }

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              // 1. Process Name & Icon (Left flex column)
              Row {
                height: parent.height
                width: parent.parent.width - Style.space(340)
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.cpu > 5.0 ? "⚡" : (modelData.isMine ? "👤" : "⚙️")
                  font.pixelSize: Style.space(12)
                  opacity: 0.85
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(24)
                  text: modelData.name
                  color: index === taskViewRoot.selectedIndex ? Color.menu.selectedText : Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.space(12)
                  font.weight: index === taskViewRoot.selectedIndex ? Font.DemiBold : Font.Normal
                  elide: Text.ElideRight
                }
              }

              // 2. PID Column
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(55)
                text: String(modelData.pid)
                color: Util.alpha(Color.menu.text, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                horizontalAlignment: Text.AlignRight
              }

              // 3. User Column
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(55)
                text: modelData.user
                color: modelData.isMine ? Color.accent : Util.alpha(Color.menu.text, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
              }

              // 4. CPU % Column
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(65)
                height: Style.space(22)
                radius: Style.space(3)
                color: {
                  if (modelData.cpu > 20.0) return Util.alpha("#ef4444", 0.18);
                  if (modelData.cpu > 5.0) return Util.alpha("#f59e0b", 0.18);
                  return "transparent";
                }

                Text {
                  anchors.centerIn: parent
                  text: modelData.cpuFormatted
                  color: {
                    if (modelData.cpu > 20.0) return "#fca5a5";
                    if (modelData.cpu > 5.0) return "#fcd34d";
                    return Util.alpha(Color.menu.text, 0.85);
                  }
                  font.family: Style.font.family
                  font.pixelSize: Style.space(11)
                  font.weight: modelData.cpu > 5.0 ? Font.Bold : Font.Normal
                }
              }

              // 5. Memory / RAM Column
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(75)
                text: modelData.rssFormatted
                color: Util.alpha(Color.menu.text, 0.8)
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
              }

              // 6. GPU Column
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(55)
                text: modelData.gpuFormatted
                color: modelData.gpu > 0 ? Color.accent : Util.alpha(Color.menu.text, 0.45)
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                horizontalAlignment: Text.AlignRight
              }
            }

            MouseArea {
              id: taskRowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                taskViewRoot.selectedIndex = index;
              }
            }
          }

          // Empty state
          Item {
            anchors.fill: parent
            visible: taskViewRoot.tasks.length === 0

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
                text: "No matching processes found"
                color: Util.alpha(Color.menu.text, 0.5)
                font.family: Style.font.family
                font.pixelSize: Style.space(12)
              }
            }
          }
        }
      }
    }

    // Right Pane: Process Details & Control Drawer
    Rectangle {
      width: parent.width * 0.42 - Style.space(14)
      height: parent.height
      radius: Style.cornerRadius
      color: Util.alpha(Color.menu.selectedBackground, 0.12)
      border.width: 1
      border.color: Util.alpha(Color.menu.border, 0.3)
      clip: true

      // Empty State
      Item {
        anchors.fill: parent
        visible: !taskViewRoot.inspectedTask

        Column {
          anchors.centerIn: parent
          spacing: Style.space(12)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "📊"
            font.pixelSize: Style.space(36)
            opacity: 0.6
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Select a process to inspect & manage"
            color: Util.alpha(Color.menu.text, 0.45)
            font.family: Style.font.family
            font.pixelSize: Style.space(12)
          }
        }
      }

      // Active Process Inspector
      Flickable {
        anchors.fill: parent
        anchors.margins: Style.space(14)
        visible: !!taskViewRoot.inspectedTask
        contentHeight: pContentCol.implicitHeight
        pixelAligned: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: pContentCol
          width: parent.width
          spacing: Style.space(12)

          // Header: Icon + Process Name + PID
          Row {
            width: parent.width
            spacing: Style.space(12)

            Rectangle {
              width: Style.space(44)
              height: Style.space(44)
              radius: Style.space(8)
              color: Util.alpha(Color.menu.selectedBackground, 0.25)

              Text {
                anchors.centerIn: parent
                text: taskViewRoot.inspectedTask && taskViewRoot.inspectedTask.cpu > 5.0 ? "⚡" : "⚙️"
                font.pixelSize: Style.space(20)
              }
            }

            Column {
              width: parent.width - Style.space(56)
              spacing: Style.space(2)
              clip: true

              Text {
                width: parent.width
                text: taskViewRoot.inspectedTask ? taskViewRoot.inspectedTask.name : ""
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.heading ? Style.font.heading : 15
                font.weight: Font.Bold
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: taskViewRoot.inspectedTask ? ("PID " + taskViewRoot.inspectedTask.pid + " • User: " + taskViewRoot.inspectedTask.user) : ""
                color: Util.alpha(Color.menu.text, 0.6)
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                elide: Text.ElideRight
              }
            }
          }

          // Action Buttons Flow (Omarchy monochrome & tinted design)
          Flow {
            width: parent.width
            spacing: Style.space(8)

            // 1. Terminate Button (SIGTERM)
            Rectangle {
              height: Style.space(30)
              width: termText.implicitWidth + Style.space(20)
              radius: Style.space(4)
              color: Util.alpha("#ef4444", 0.15)
              border.width: 1
              border.color: Util.alpha("#ef4444", 0.3)

              Row {
                anchors.centerIn: parent
                spacing: Style.space(5)
                Text { text: "🛑"; font.pixelSize: Style.space(10) }
                Text {
                  id: termText
                  text: "End Task (SIGTERM)"
                  color: "#fca5a5"
                  font.family: Style.font.family
                  font.pixelSize: Style.space(11)
                  font.weight: Font.Medium
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (taskViewRoot.inspectedTask) {
                    taskViewRoot.killRequested(taskViewRoot.inspectedTask.pid, false);
                  }
                }
              }
            }

            // 2. Force Kill Button (SIGKILL)
            Rectangle {
              height: Style.space(30)
              width: forceText.implicitWidth + Style.space(20)
              radius: Style.space(4)
              color: Util.alpha(Color.menu.selectedBackground, 0.25)
              border.width: 1
              border.color: Util.alpha(Color.menu.border, 0.3)

              Row {
                anchors.centerIn: parent
                spacing: Style.space(5)
                Text { text: "⚡"; font.pixelSize: Style.space(10) }
                Text {
                  id: forceText
                  text: "Force Kill"
                  color: Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.space(11)
                  font.weight: Font.Medium
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (taskViewRoot.inspectedTask) {
                    taskViewRoot.killRequested(taskViewRoot.inspectedTask.pid, true);
                  }
                }
              }
            }

            // 3. Open File Location Button
            Rectangle {
              height: Style.space(30)
              width: openLocText.implicitWidth + Style.space(20)
              radius: Style.space(4)
              color: Util.alpha(Color.menu.selectedBackground, 0.15)
              border.width: 1
              border.color: Util.alpha(Color.menu.border, 0.25)

              Row {
                anchors.centerIn: parent
                spacing: Style.space(5)
                Text { text: "📂"; font.pixelSize: Style.space(10) }
                Text {
                  id: openLocText
                  text: "Open File Location"
                  color: Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.space(11)
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (taskViewRoot.inspectedTask) {
                    taskViewRoot.openLocationRequested(taskViewRoot.inspectedTask.pid);
                  }
                }
              }
            }

            // 4. View Package in App Manager
            Rectangle {
              visible: !!taskViewRoot.inspectedDetails.pkg
              height: Style.space(30)
              width: viewPkgText.implicitWidth + Style.space(20)
              radius: Style.space(4)
              color: Util.alpha(Color.accent, 0.18)
              border.width: 1
              border.color: Util.alpha(Color.accent, 0.35)

              Row {
                anchors.centerIn: parent
                spacing: Style.space(5)
                Text { text: "📦"; font.pixelSize: Style.space(10) }
                Text {
                  id: viewPkgText
                  text: "Package: " + taskViewRoot.inspectedDetails.pkg
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.space(11)
                  font.weight: Font.DemiBold
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  taskViewRoot.inspectPackageRequested(taskViewRoot.inspectedDetails.pkg);
                }
              }
            }
          }

          // Resource Meters (CPU & RAM)
          Rectangle {
            width: parent.width
            height: Style.space(56)
            radius: Style.space(6)
            color: Util.alpha(Color.menu.selectedBackground, 0.12)
            border.width: 1
            border.color: Util.alpha(Color.menu.border, 0.2)

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(8)

              // CPU Box
              Column {
                width: parent.width * 0.5
                spacing: Style.space(2)
                Text { text: "CPU Usage"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(10) }
                Text {
                  text: taskViewRoot.inspectedTask ? taskViewRoot.inspectedTask.cpuFormatted : "0%"
                  color: taskViewRoot.inspectedTask && taskViewRoot.inspectedTask.cpu > 10.0 ? "#fca5a5" : Color.menu.text
                  font.pixelSize: Style.space(14)
                  font.weight: Font.Bold
                }
              }

              // RAM Box
              Column {
                width: parent.width * 0.5
                spacing: Style.space(2)
                Text { text: "Memory (RSS)"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(10) }
                Text {
                  text: taskViewRoot.inspectedTask ? taskViewRoot.inspectedTask.rssFormatted : "0 B"
                  color: Color.menu.text
                  font.pixelSize: Style.space(14)
                  font.weight: Font.Bold
                }
              }
            }
          }

          // Divider
          Rectangle {
            width: parent.width
            height: 1
            color: Util.alpha(Color.menu.border, 0.2)
          }

          // Process Details Table
          Column {
            width: parent.width
            spacing: Style.space(6)

            Row {
              width: parent.width
              Text { width: Style.space(90); text: "Executable:"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(11) }
              Text {
                width: parent.width - Style.space(90)
                text: taskViewRoot.isDetailsLoading ? "Loading..." : (taskViewRoot.inspectedDetails.exe || "Kernel worker / No binary")
                color: Color.menu.text
                font.pixelSize: Style.space(11)
                elide: Text.ElideMiddle
              }
            }

            Row {
              width: parent.width
              Text { width: Style.space(90); text: "Package:"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(11) }
              Text {
                width: parent.width - Style.space(90)
                text: taskViewRoot.isDetailsLoading ? "Checking..." : (taskViewRoot.inspectedDetails.pkg || "Unmanaged binary / daemon")
                color: taskViewRoot.inspectedDetails.pkg ? Color.accent : Util.alpha(Color.menu.text, 0.6)
                font.pixelSize: Style.space(11)
                font.weight: taskViewRoot.inspectedDetails.pkg ? Font.DemiBold : Font.Normal
              }
            }

            Row {
              width: parent.width
              Text { width: Style.space(90); text: "Working Dir:"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(11) }
              Text {
                width: parent.width - Style.space(90)
                text: taskViewRoot.isDetailsLoading ? "-" : (taskViewRoot.inspectedDetails.cwd || "-")
                color: Color.menu.text
                font.pixelSize: Style.space(11)
                elide: Text.ElideMiddle
              }
            }

            Row {
              width: parent.width
              Text { width: Style.space(90); text: "Command Line:"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(11) }
              Text {
                width: parent.width - Style.space(90)
                text: taskViewRoot.isDetailsLoading ? "-" : (taskViewRoot.inspectedDetails.cmd || "-")
                color: Util.alpha(Color.menu.text, 0.8)
                font.pixelSize: Style.space(11)
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
}
