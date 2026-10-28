import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: headerRoot

  property string filterText: ""
  property string activeTab: "apps" // "apps", "tasks", "janitor"
  property string activeCategory: "all"
  property int itemCount: 0
  property bool sudoActive: false
  property bool isJanitorView: activeTab === "janitor"

  signal searchChanged(string text)
  signal tabChanged(string tab)
  signal categorySelected(string category)
  signal sudoClicked()

  height: Style.space(84)

  Column {
    anchors.fill: parent
    spacing: Style.space(10)

    // Row 1: Native Omarchy Search TextField + Segmented Tab Buttons + Sudo Button
    Item {
      width: parent.width
      height: Style.space(36)

      // Search Input using native qs.Ui.TextField
      Item {
        id: searchBox
        anchors.left: parent.left
        anchors.right: tabGroup.left
        anchors.rightMargin: Style.space(10)
        height: parent.height

        TextField {
          id: searchInput
          anchors.fill: parent
          foreground: Color.menu.text
          accent: Color.accent
          text: headerRoot.filterText
          placeholderText: headerRoot.activeTab === "tasks"
            ? "Filter processes by name, PID, or user (Press /)..."
            : "Search applications, packages, binaries (Press /)..."
          rightPadding: clearBtn.visible ? Style.space(32) : Style.spacing.controlPaddingX
          onTextChanged: {
            if (text !== headerRoot.filterText) {
              headerRoot.searchChanged(text);
            }
          }
        }

        Button {
          id: clearBtn
          visible: searchInput.text.length > 0
          anchors.right: parent.right
          anchors.rightMargin: Style.space(4)
          anchors.verticalCenter: parent.verticalCenter
          text: "✕"
          fontSize: Style.font.caption
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(2)
          foreground: Color.muted
          onClicked: {
            searchInput.text = "";
            headerRoot.searchChanged("");
            searchInput.forceActiveFocus();
          }
        }
      }

      // 3-Way Tab Switcher (Apps | Tasks | Janitor) using native qs.Ui.Button
      BorderSurface {
        id: tabGroup
        anchors.right: sudoBtn.left
        anchors.rightMargin: Style.space(10)
        height: parent.height
        width: tabsRow.implicitWidth + Style.space(8)
        radius: Style.cornerRadius
        color: Style.normalFill
        borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

        Row {
          id: tabsRow
          anchors.centerIn: parent
          spacing: Style.space(4)

          Button {
            text: "Apps"
            iconText: "󰏖"
            selected: headerRoot.activeTab === "apps"
            foreground: Color.menu.text
            accent: Color.accent
            horizontalPadding: Style.space(12)
            verticalPadding: Style.space(5)
            onClicked: headerRoot.tabChanged("apps")
          }

          Button {
            text: "Tasks"
            iconText: "󰍛"
            selected: headerRoot.activeTab === "tasks"
            foreground: Color.menu.text
            accent: Color.accent
            horizontalPadding: Style.space(12)
            verticalPadding: Style.space(5)
            onClicked: headerRoot.tabChanged("tasks")
          }

          Button {
            text: "Janitor"
            iconText: "󰃢"
            selected: headerRoot.activeTab === "janitor"
            foreground: Color.menu.text
            accent: Color.accent
            horizontalPadding: Style.space(12)
            verticalPadding: Style.space(5)
            onClicked: headerRoot.tabChanged("janitor")
          }
        }
      }

      // Sudo Session Status Button
      Button {
        id: sudoBtn
        anchors.right: parent.right
        height: parent.height
        bordered: true
        iconText: headerRoot.sudoActive ? "󰌿" : "󰌾"
        text: headerRoot.sudoActive ? "Root Active" : "Unlock Root"
        foreground: headerRoot.sudoActive ? Color.accent : Color.urgent
        accent: headerRoot.sudoActive ? Color.accent : Color.urgent
        background: Util.alpha(headerRoot.sudoActive ? Color.accent : Color.urgent, Style.normalFillAlpha)
        horizontalPadding: Style.space(12)
        onClicked: headerRoot.sudoClicked()
      }
    }

    // Row 2: Category Filter Buttons (Left) + Item Count (Right) — NO Sort Dropdown!
    Item {
      width: parent.width
      height: Style.space(32)
      visible: !headerRoot.isJanitorView

      Row {
        id: categoryRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        Repeater {
          model: headerRoot.activeTab === "tasks"
            ? [
                { id: "all", label: "All Processes" },
                { id: "user", label: "User Apps" },
                { id: "system", label: "System" },
                { id: "heavy_cpu", label: "Active CPU" },
                { id: "heavy_gpu", label: "Active GPU" },
                { id: "heavy_ram", label: "High RAM" }
              ]
            : [
                { id: "all", label: "All Packages" },
                { id: "desktop", label: "Desktop" },
                { id: "system", label: "CLI / System" },
                { id: "aur", label: "AUR" },
                { id: "webapp", label: "Web Apps" },
                { id: "large", label: "Large (>100M)" }
              ]

          Button {
            required property var modelData
            text: modelData.label
            selected: headerRoot.activeCategory === modelData.id
            bordered: true
            fontSize: Style.font.bodySmall
            horizontalPadding: Style.space(10)
            verticalPadding: Style.space(4)
            foreground: Color.menu.text
            accent: Color.accent
            onClicked: headerRoot.categorySelected(modelData.id)
          }
        }
      }

      Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: headerRoot.itemCount + (headerRoot.activeTab === "tasks" ? " processes" : " packages")
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }
  }

  function focusSearch() {
    searchInput.forceActiveFocus();
  }
}
