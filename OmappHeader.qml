import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: headerRoot

  property string filterText: ""
  property string activeTab: "apps" // "apps", "tasks", "janitor"
  property string activeCategory: "all"
  property string activeSort: "size"
  property int itemCount: 0
  property bool sudoActive: false
  property bool isJanitorView: activeTab === "janitor"

  signal searchChanged(string text)
  signal tabChanged(string tab)
  signal categorySelected(string category)
  signal sortChanged(string mode)
  signal sudoClicked()

  height: Style.space(92)

  Column {
    anchors.fill: parent
    spacing: Style.space(10)

    // Top Bar: Search Bar + 3-Way Tab Switcher + Sudo Status
    Row {
      width: parent.width
      height: Style.space(40)
      spacing: Style.space(10)

      // Search Box Container
      Rectangle {
        width: parent.width - tabSwitcher.width - sudoBtn.width - Style.space(20)
        height: parent.height
        radius: Style.cornerRadius
        color: Util.alpha(Color.menu.selectedBackground, 0.15)
        border.width: 1
        border.color: searchInput.activeFocus ? Color.accent : Util.alpha(Color.menu.border, 0.35)

        Text {
          id: searchIcon
          anchors.left: parent.left
          anchors.leftMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          text: "🔍"
          font.pixelSize: Style.space(14)
          opacity: 0.8
        }

        TextInput {
          id: searchInput
          anchors.left: searchIcon.right
          anchors.leftMargin: Style.space(8)
          anchors.right: clearBtn.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          color: Color.menu.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body ? Style.font.body : 13
          text: headerRoot.filterText
          clip: true

          Text {
            anchors.fill: parent
            visible: !searchInput.text && !searchInput.activeFocus
            text: headerRoot.activeTab === "tasks" ? "Filter running processes by name, PID, or user..." : "Search apps, packages, binaries (Press / or Ctrl+F)..."
            color: Util.alpha(Color.menu.text, 0.4)
            font: searchInput.font
          }

          onTextChanged: headerRoot.searchChanged(text)
        }

        // Clear button
        Rectangle {
          id: clearBtn
          visible: !!searchInput.text
          anchors.right: parent.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(22)
          height: Style.space(22)
          radius: width / 2
          color: clearMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.35) : "transparent"

          Text {
            anchors.centerIn: parent
            text: "✕"
            color: Util.alpha(Color.menu.text, 0.6)
            font.pixelSize: Style.space(11)
          }

          MouseArea {
            id: clearMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              searchInput.text = "";
              searchInput.forceActiveFocus();
            }
          }
        }
      }

      // 3-Way Segmented Tab Switcher (Apps | Tasks | Janitor)
      Rectangle {
        id: tabSwitcher
        height: parent.height
        width: tabsRow.width + Style.space(8)
        radius: Style.cornerRadius
        color: Util.alpha(Color.menu.selectedBackground, 0.12)
        border.width: 1
        border.color: Util.alpha(Color.menu.border, 0.3)

        Row {
          id: tabsRow
          anchors.centerIn: parent
          spacing: Style.space(4)

          // 1. Apps Tab
          Rectangle {
            height: Style.space(32)
            width: appsTabText.implicitWidth + Style.space(20)
            radius: Style.space(6)
            color: headerRoot.activeTab === "apps" ? Color.accent : (appsMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.25) : "transparent")

            Row {
              anchors.centerIn: parent
              spacing: Style.space(6)
              Text { text: "📦"; font.pixelSize: Style.space(12) }
              Text {
                id: appsTabText
                text: "Apps"
                color: headerRoot.activeTab === "apps" ? (Color.menu.background || "#18181b") : Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                font.weight: headerRoot.activeTab === "apps" ? Font.Bold : Font.DemiBold
              }
            }

            MouseArea {
              id: appsMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: headerRoot.tabChanged("apps")
            }
          }

          // 2. Tasks Tab (Task Manager)
          Rectangle {
            height: Style.space(32)
            width: tasksTabText.implicitWidth + Style.space(20)
            radius: Style.space(6)
            color: headerRoot.activeTab === "tasks" ? Color.accent : (tasksMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.25) : "transparent")

            Row {
              anchors.centerIn: parent
              spacing: Style.space(6)
              Text { text: "📊"; font.pixelSize: Style.space(12) }
              Text {
                id: tasksTabText
                text: "Tasks"
                color: headerRoot.activeTab === "tasks" ? (Color.menu.background || "#18181b") : Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                font.weight: headerRoot.activeTab === "tasks" ? Font.Bold : Font.DemiBold
              }
            }

            MouseArea {
              id: tasksMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: headerRoot.tabChanged("tasks")
            }
          }

          // 3. Janitor Tab
          Rectangle {
            height: Style.space(32)
            width: janitorTabText.implicitWidth + Style.space(20)
            radius: Style.space(6)
            color: headerRoot.activeTab === "janitor" ? Color.accent : (janitorMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.25) : "transparent")

            Row {
              anchors.centerIn: parent
              spacing: Style.space(6)
              Text { text: "🧹"; font.pixelSize: Style.space(12) }
              Text {
                id: janitorTabText
                text: "Janitor"
                color: headerRoot.activeTab === "janitor" ? (Color.menu.background || "#18181b") : Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                font.weight: headerRoot.activeTab === "janitor" ? Font.Bold : Font.DemiBold
              }
            }

            MouseArea {
              id: janitorMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: headerRoot.tabChanged("janitor")
            }
          }
        }
      }

      // Sudo Status Button
      Rectangle {
        id: sudoBtn
        width: sudoText.implicitWidth + Style.space(24)
        height: parent.height
        radius: Style.cornerRadius
        color: headerRoot.sudoActive ? Util.alpha("#22c55e", 0.15) : Util.alpha("#ef4444", 0.15)
        border.width: 1
        border.color: headerRoot.sudoActive ? Util.alpha("#22c55e", 0.4) : Util.alpha("#ef4444", 0.4)

        Row {
          anchors.centerIn: parent
          spacing: Style.space(6)

          Text {
            text: headerRoot.sudoActive ? "🔓" : "🔒"
            font.pixelSize: Style.space(13)
          }

          Text {
            id: sudoText
            text: headerRoot.sudoActive ? "Sudo Active" : "Unlock Root"
            color: headerRoot.sudoActive ? "#86efac" : "#fca5a5"
            font.family: Style.font.family
            font.pixelSize: Style.space(11)
            font.weight: Font.DemiBold
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: headerRoot.sudoClicked()
        }
      }
    }

    // Bottom Filter Bar: Category Pills (Left) + Sort & Count (Right)
    Item {
      width: parent.width
      height: Style.space(32)

      // Left-aligned Category Pills
      Row {
        id: categoryRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        Repeater {
          model: {
            if (headerRoot.activeTab === "tasks") {
              return [
                { id: "all", label: "All Tasks" },
                { id: "user", label: "User Apps" },
                { id: "system", label: "System Daemons" },
                { id: "heavy_cpu", label: "Heavy CPU (>1%)" },
                { id: "heavy_ram", label: "Heavy RAM (>100MB)" }
              ];
            } else {
              return [
                { id: "all", label: "All" },
                { id: "desktop", label: "Desktop" },
                { id: "system", label: "System / CLI" },
                { id: "aur", label: "AUR" },
                { id: "webapp", label: "Web Apps" },
                { id: "large", label: "Large" }
              ];
            }
          }

          Rectangle {
            property bool isActive: headerRoot.activeCategory === modelData.id
            height: Style.space(26)
            width: pillText.implicitWidth + Style.space(16)
            radius: Style.space(6)
            color: isActive ? Color.accent : (pillMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.3) : Util.alpha(Color.menu.selectedBackground, 0.1))
            border.width: 1
            border.color: isActive ? Color.accent : Util.alpha(Color.menu.border, 0.3)

            Text {
              id: pillText
              anchors.centerIn: parent
              text: modelData.label
              color: parent.isActive ? (Color.menu.background || "#18181b") : Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.space(11)
              font.weight: parent.isActive ? Font.Bold : Font.Normal
            }

            MouseArea {
              id: pillMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onClicked: headerRoot.categorySelected(modelData.id)
            }
          }
        }
      }

      // Right-aligned Sort & Item Count
      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(12)

        // Sort Mode Toggle (Only shown in Apps tab — Tasks tab sorts via column headers)
        Rectangle {
          visible: headerRoot.activeTab === "apps"
          height: Style.space(26)
          width: sortText.implicitWidth + Style.space(16)
          radius: Style.space(6)
          color: Util.alpha(Color.menu.selectedBackground, 0.15)
          border.width: 1
          border.color: Util.alpha(Color.menu.border, 0.3)

          Text {
            id: sortText
            anchors.centerIn: parent
            text: {
              if (headerRoot.activeSort === "size") return "Sort: Size ▾";
              if (headerRoot.activeSort === "name") return "Sort: Name ▾";
              if (headerRoot.activeSort === "date") return "Sort: Install Date ▾";
              return "Sort: Build Date ▾";
            }
            color: Util.alpha(Color.menu.text, 0.85)
            font.family: Style.font.family
            font.pixelSize: Style.space(11)
            font.weight: Font.Medium
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var modes = ["size", "name", "date", "update"];
              var idx = modes.indexOf(headerRoot.activeSort);
              var next = modes[(idx + 1) % modes.length];
              headerRoot.sortChanged(next);
            }
          }
        }

        // Item Count
        Text {
          id: countText
          anchors.verticalCenter: parent.verticalCenter
          text: headerRoot.itemCount + (headerRoot.activeTab === "tasks" ? " processes" : " apps")
          color: Util.alpha(Color.menu.text, 0.5)
          font.family: Style.font.family
          font.pixelSize: Style.space(11)
        }
      }
    }
  }

  function focusSearch() {
    searchInput.forceActiveFocus();
  }
}
