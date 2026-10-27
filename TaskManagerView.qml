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
  property string activeCategory: "all" // all, user, system, heavy_cpu, heavy_ram
  property string activeSort: "cpu" // cpu, ram, pid, name
  property string filterText: ""
  property bool sudoActive: false

  // Inspected task details
  property var inspectedTask: (tasks.length > 0 && selectedIndex >= 0 && selectedIndex < tasks.length)
    ? tasks[selectedIndex] : null
  property var inspectedDetails: ({ exe: "", cwd: "", cmd: "", pkg: "" })

  signal killRequested(int pid, bool force)
  signal openLocationRequested(int pid)
  signal inspectPackageRequested(string pkg)
  signal refreshRequested()

  radius: Style.cornerRadius
  color: "transparent"

  onInspectedTaskChanged: {
    if (inspectedTask) {
      detailsProc.command = TaskManager.buildGetProcessDetailsScript(inspectedTask.pid);
      detailsProc.running = true;
    } else {
      inspectedDetails = { exe: "", cwd: "", cmd: "", pkg: "" };
    }
  }

  Process {
    id: detailsProc
    stdout: StdioCollector {
      id: detailsOut
      waitForEnd: true
      onStreamFinished: {
        taskViewRoot.inspectedDetails = TaskManager.parseProcessDetails(text);
      }
    }
  }

  Row {
    anchors.fill: parent
    spacing: Style.space(14)

    // Left Pane: Process List Table
    Rectangle {
      width: parent.width * 0.58
      height: parent.height
      radius: Style.cornerRadius
      color: Util.alpha(Color.menu.selectedBackground, 0.08)
      border.width: 1
      border.color: Util.alpha(Color.menu.border, 0.3)
      clip: true

      ListView {
        id: taskListView
        anchors.fill: parent
        anchors.margins: Style.space(6)
        model: taskViewRoot.tasks
        currentIndex: taskViewRoot.selectedIndex
        spacing: Style.space(4)
        pixelAligned: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        highlightMoveDuration: 0

        delegate: Rectangle {
          id: taskRow
          width: ListView.view ? ListView.view.width : Style.space(400)
          height: Style.space(48)
          radius: Style.cornerRadius
          color: index === taskViewRoot.selectedIndex
            ? Util.alpha(Color.accent, 0.18)
            : (taskRowMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.25) : "transparent")
          border.width: index === taskViewRoot.selectedIndex ? 1 : 0
          border.color: index === taskViewRoot.selectedIndex ? Util.alpha(Color.accent, 0.45) : "transparent"

          // Process Icon / Glyph Box
          Rectangle {
            id: pIconBox
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28)
            height: Style.space(28)
            radius: Style.space(6)
            color: Util.alpha(Color.menu.selectedBackground, 0.25)

            Text {
              anchors.centerIn: parent
              text: modelData.cpu > 5.0 ? "⚡" : (modelData.isMine ? "👤" : "⚙️")
              font.pixelSize: Style.space(13)
            }
          }

          // Meta Badges on Right: CPU % & RAM (Anchored first)
          Row {
            id: pMetaRow
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            // CPU Badge
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(22)
              width: cpuText.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: {
                if (modelData.cpu > 20.0) return Util.alpha("#ef4444", 0.25);
                if (modelData.cpu > 5.0) return Util.alpha("#f59e0b", 0.25);
                return Util.alpha(Color.menu.border, 0.2);
              }

              Text {
                id: cpuText
                anchors.centerIn: parent
                text: modelData.cpuFormatted
                color: {
                  if (modelData.cpu > 20.0) return "#fca5a5";
                  if (modelData.cpu > 5.0) return "#fcd34d";
                  return Util.alpha(Color.menu.text, 0.85);
                }
                font.family: Style.font.family
                font.pixelSize: Style.space(10)
                font.weight: Font.DemiBold
              }
            }

            // RAM Label
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(68)
              text: modelData.rssFormatted
              color: Util.alpha(Color.menu.text, 0.75)
              font.family: Style.font.family
              font.pixelSize: Style.space(11)
              font.weight: Font.Medium
              horizontalAlignment: Text.AlignRight
            }
          }

          // Process Name & PID (Bounded between pIconBox and pMetaRow)
          Column {
            anchors.left: pIconBox.right
            anchors.leftMargin: Style.space(10)
            anchors.right: pMetaRow.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            clip: true

            Text {
              width: parent.width
              text: modelData.name
              color: index === taskViewRoot.selectedIndex ? Color.menu.selectedText : Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body ? Style.font.body : 13
              font.weight: Font.Medium
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: "PID " + modelData.pid + " • " + modelData.user
              color: Util.alpha(Color.menu.text, 0.55)
              font.family: Style.font.family
              font.pixelSize: Style.space(10)
              elide: Text.ElideRight
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
              width: Style.space(48)
              height: Style.space(48)
              radius: Style.space(8)
              color: Util.alpha(Color.menu.selectedBackground, 0.3)

              Text {
                anchors.centerIn: parent
                text: taskViewRoot.inspectedTask && taskViewRoot.inspectedTask.cpu > 5.0 ? "⚡" : "⚙️"
                font.pixelSize: Style.space(22)
              }
            }

            Column {
              width: parent.width - Style.space(60)
              spacing: Style.space(3)
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

          // Action Buttons Flow
          Flow {
            width: parent.width
            spacing: Style.space(8)

            // 1. Terminate Button (SIGTERM - Graceful)
            Rectangle {
              height: Style.space(32)
              width: termText.implicitWidth + Style.space(24)
              radius: Style.space(6)
              color: Util.alpha("#ef4444", 0.2)
              border.width: 1
              border.color: Util.alpha("#ef4444", 0.4)

              Row {
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text { text: "🛑"; font.pixelSize: Style.space(11) }
                Text {
                  id: termText
                  text: "End Task (SIGTERM)"
                  color: "#fca5a5"
                  font.family: Style.font.family
                  font.pixelSize: Style.space(11)
                  font.weight: Font.DemiBold
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
              height: Style.space(32)
              width: forceText.implicitWidth + Style.space(24)
              radius: Style.space(6)
              color: "#ef4444"

              Row {
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text { text: "⚡"; font.pixelSize: Style.space(11) }
                Text {
                  id: forceText
                  text: "Force Kill (SIGKILL)"
                  color: "#ffffff"
                  font.family: Style.font.family
                  font.pixelSize: Style.space(11)
                  font.weight: Font.Bold
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
              height: Style.space(32)
              width: openLocText.implicitWidth + Style.space(24)
              radius: Style.space(6)
              color: Util.alpha(Color.menu.selectedBackground, 0.2)
              border.width: 1
              border.color: Util.alpha(Color.menu.border, 0.3)

              Row {
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text { text: "📂"; font.pixelSize: Style.space(11) }
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
              height: Style.space(32)
              width: viewPkgText.implicitWidth + Style.space(24)
              radius: Style.space(6)
              color: Util.alpha(Color.accent, 0.2)
              border.width: 1
              border.color: Util.alpha(Color.accent, 0.4)

              Row {
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text { text: "📦"; font.pixelSize: Style.space(11) }
                Text {
                  id: viewPkgText
                  text: "Inspect Package (" + taskViewRoot.inspectedDetails.pkg + ")"
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
            height: Style.space(60)
            radius: Style.space(6)
            color: Util.alpha(Color.menu.selectedBackground, 0.15)
            border.width: 1
            border.color: Util.alpha(Color.menu.border, 0.2)

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(10)

              // CPU Box
              Column {
                width: parent.width * 0.5
                spacing: Style.space(2)
                Text { text: "CPU Usage"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(10) }
                Text {
                  text: taskViewRoot.inspectedTask ? taskViewRoot.inspectedTask.cpuFormatted : "0%"
                  color: taskViewRoot.inspectedTask && taskViewRoot.inspectedTask.cpu > 10.0 ? "#fca5a5" : Color.menu.text
                  font.pixelSize: Style.space(15)
                  font.weight: Font.Bold
                }
              }

              // RAM Box
              Column {
                width: parent.width * 0.5
                spacing: Style.space(2)
                Text { text: "Resident Memory (RSS)"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(10) }
                Text {
                  text: taskViewRoot.inspectedTask ? taskViewRoot.inspectedTask.rssFormatted : "0 B"
                  color: Color.menu.text
                  font.pixelSize: Style.space(15)
                  font.weight: Font.Bold
                }
              }
            }
          }

          // Divider
          Rectangle {
            width: parent.width
            height: 1
            color: Util.alpha(Color.menu.border, 0.25)
          }

          // Process Details Table
          Column {
            width: parent.width
            spacing: Style.space(8)

            Row {
              width: parent.width
              Text { width: Style.space(90); text: "Executable:"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(11) }
              Text {
                width: parent.width - Style.space(90)
                text: taskViewRoot.inspectedDetails.exe || "Loading..."
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
                text: taskViewRoot.inspectedDetails.pkg || "Unmanaged binary / daemon"
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
                text: taskViewRoot.inspectedDetails.cwd || "-"
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
                text: taskViewRoot.inspectedDetails.cmd || "-"
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
}
