import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: headerRoot

  property string filterText: ""
  property string activeCategory: "all"
  property string activeSort: "size"
  property int itemCount: 0
  property bool sudoActive: false
  property bool isJanitorView: false

  signal searchChanged(string text)
  signal categorySelected(string category)
  signal sortChanged(string mode)
  signal sudoClicked()
  signal janitorToggled()

  height: Style.space(92)

  Column {
    anchors.fill: parent
    spacing: Style.space(10)

    // Top Bar: Search Bar + Sudo Status + Janitor Button
    Row {
      width: parent.width
      height: Style.space(40)
      spacing: Style.space(10)

      // Search Box Container
      Rectangle {
        width: parent.width - sudoBtn.width - janitorBtn.width - Style.space(20)
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
            text: "Search apps, packages, binaries (Press / or Ctrl+F)..."
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

      // Janitor Tab Toggle Button
      Rectangle {
        id: janitorBtn
        width: janitorText.implicitWidth + Style.space(24)
        height: parent.height
        radius: Style.cornerRadius
        color: headerRoot.isJanitorView ? Util.alpha(Color.accent, 0.3) : Util.alpha(Color.menu.selectedBackground, 0.15)
        border.width: 1
        border.color: headerRoot.isJanitorView ? Color.accent : Util.alpha(Color.menu.border, 0.35)

        Row {
          anchors.centerIn: parent
          spacing: Style.space(6)

          Text {
            text: "🧹"
            font.pixelSize: Style.space(13)
          }

          Text {
            id: janitorText
            text: "Janitor"
            color: headerRoot.isJanitorView ? Color.accent : Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.space(11)
            font.weight: Font.DemiBold
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: headerRoot.janitorToggled()
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
          model: [
            { id: "all", label: "All" },
            { id: "desktop", label: "Desktop" },
            { id: "system", label: "System / CLI" },
            { id: "aur", label: "AUR" },
            { id: "webapp", label: "Web Apps" },
            { id: "large", label: "Large" }
          ]

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

        // Sort Mode Toggle
        Rectangle {
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
          text: headerRoot.itemCount + " apps"
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
