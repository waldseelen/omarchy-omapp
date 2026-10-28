import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: headerRoot

  property string filterText: ""
  property string activeTab: "apps" // "apps", "tasks", "services", "janitor"
  property string activeCategory: "all"
  property int itemCount: 0
  property bool sudoActive: false
  property bool isJanitorView: activeTab === "janitor"
  property bool groupTasks: false

  // Live System Telemetry (#2)
  property real sysCpuPercent: 0.0
  property real sysGpuPercent: 0.0
  property real sysMemUsedGiB: 0.0
  property real sysMemTotalGiB: 0.0
  property int sysTempC: 0

  signal searchChanged(string text)
  signal tabChanged(string tab)
  signal categorySelected(string category)
  signal sudoClicked()
  signal toggleGroupTasksRequested()

  height: Style.space(84)

  Column {
    anchors.fill: parent
    spacing: Style.space(10)

    // Row 1: Search Input + System Telemetry Pill (#2) + 4-Way Tab Switcher (#6) + Sudo Button
    Item {
      width: parent.width
      height: Style.space(36)

      Item {
        id: searchBox
        anchors.left: parent.left
        anchors.right: telemetryBar.left
        anchors.rightMargin: Style.space(8)
        height: parent.height

        TextField {
          id: searchInput
          anchors.fill: parent
          foreground: Color.menu.text
          accent: Color.accent
          text: headerRoot.filterText
          placeholderText: {
            if (headerRoot.activeTab === "tasks") return "Filter processes by name, PID, or user (/)...";
            if (headerRoot.activeTab === "services") return "Filter systemd units & autostart items (/)...";
            return "Search applications, Flatpaks, AppImages, binaries (/)...";
          }
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

      // Live System Telemetry Summary Bar (#2)
      BorderSurface {
        id: telemetryBar
        anchors.right: tabGroup.left
        anchors.rightMargin: Style.space(8)
        height: parent.height
        width: telemRow.implicitWidth + Style.space(16)
        radius: Style.cornerRadius
        color: Style.normalFill
        borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

        Row {
          id: telemRow
          anchors.centerIn: parent
          spacing: Style.space(10)

          Text {
            textFormat: Text.PlainText
            text: "CPU " + headerRoot.sysCpuPercent.toFixed(1) + "%"
            color: headerRoot.sysCpuPercent >= 50 ? Color.urgent : Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            text: "GPU " + headerRoot.sysGpuPercent.toFixed(0) + "%"
            color: headerRoot.sysGpuPercent >= 50 ? Color.urgent : Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          Text {
            textFormat: Text.PlainText
            text: "RAM " + headerRoot.sysMemUsedGiB.toFixed(1) + "/" + headerRoot.sysMemTotalGiB.toFixed(0) + "G"
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          Text {
            visible: headerRoot.sysTempC > 0
            textFormat: Text.PlainText
            text: headerRoot.sysTempC + "°C"
            color: headerRoot.sysTempC >= 80 ? Color.urgent : Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }

      // 4-Way Tab Switcher (Apps | Tasks | Services | Janitor)
      BorderSurface {
        id: tabGroup
        anchors.right: sudoBtn.left
        anchors.rightMargin: Style.space(8)
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
            horizontalPadding: Style.space(10)
            verticalPadding: Style.space(5)
            onClicked: headerRoot.tabChanged("apps")
          }

          Button {
            text: "Tasks"
            iconText: "󰍛"
            selected: headerRoot.activeTab === "tasks"
            foreground: Color.menu.text
            accent: Color.accent
            horizontalPadding: Style.space(10)
            verticalPadding: Style.space(5)
            onClicked: headerRoot.tabChanged("tasks")
          }

          Button {
            text: "Services"
            iconText: "󰒓"
            selected: headerRoot.activeTab === "services"
            foreground: Color.menu.text
            accent: Color.accent
            horizontalPadding: Style.space(10)
            verticalPadding: Style.space(5)
            onClicked: headerRoot.tabChanged("services")
          }

          Button {
            text: "Janitor"
            iconText: "󰃢"
            selected: headerRoot.activeTab === "janitor"
            foreground: Color.menu.text
            accent: Color.accent
            horizontalPadding: Style.space(10)
            verticalPadding: Style.space(5)
            onClicked: headerRoot.tabChanged("janitor")
          }
        }
      }

      Button {
        id: sudoBtn
        anchors.right: parent.right
        height: parent.height
        bordered: true
        iconText: headerRoot.sudoActive ? "󰌿" : "󰌾"
        text: headerRoot.sudoActive ? "Root" : "Unlock"
        foreground: headerRoot.sudoActive ? Color.accent : Color.urgent
        accent: headerRoot.sudoActive ? Color.accent : Color.urgent
        background: Util.alpha(headerRoot.sudoActive ? Color.accent : Color.urgent, Style.normalFillAlpha)
        horizontalPadding: Style.space(10)
        onClicked: headerRoot.sudoClicked()
      }
    }

    // Row 2: Category Filter Pills + Group Toggle (#1) + Item Count
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
          model: {
            if (headerRoot.activeTab === "tasks") {
              return [
                { id: "all", label: "All Processes" },
                { id: "user", label: "User Apps" },
                { id: "system", label: "System" },
                { id: "heavy_cpu", label: "Active CPU" },
                { id: "heavy_gpu", label: "Active GPU" },
                { id: "heavy_ram", label: "High RAM" }
              ];
            }
            if (headerRoot.activeTab === "services") {
              return [
                { id: "all", label: "All Startup & Units" },
                { id: "user", label: "User Services" },
                { id: "system", label: "System Daemons" },
                { id: "running", label: "Running" },
                { id: "failed", label: "Failed" },
                { id: "autostart", label: "Hyprland / XDG" }
              ];
            }
            return [
              { id: "all", label: "All" },
              { id: "desktop", label: "Desktop" },
              { id: "system", label: "CLI / Sys" },
              { id: "aur", label: "AUR" },
              { id: "flatpak", label: "Flatpak / AppImg" },
              { id: "webapp", label: "Web Apps" },
              { id: "large", label: "Large (>100M)" },
              { id: "unused", label: "Unused (>30d)" }
            ];
          }

          Button {
            required property var modelData
            text: modelData.label
            selected: headerRoot.activeCategory === modelData.id
            bordered: true
            fontSize: Style.font.bodySmall
            horizontalPadding: Style.space(8)
            verticalPadding: Style.space(4)
            foreground: Color.menu.text
            accent: Color.accent
            onClicked: headerRoot.categorySelected(modelData.id)
          }
        }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(10)

        Button {
          visible: headerRoot.activeTab === "tasks"
          bordered: true
          selected: headerRoot.groupTasks
          iconText: "󰙅"
          text: headerRoot.groupTasks ? "Grouped" : "Group Apps"
          fontSize: Style.font.caption
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(3)
          foreground: Color.menu.text
          accent: Color.accent
          onClicked: headerRoot.toggleGroupTasksRequested()
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: {
            if (headerRoot.activeTab === "tasks") return headerRoot.itemCount + " rows";
            if (headerRoot.activeTab === "services") return headerRoot.itemCount + " units";
            return headerRoot.itemCount + " packages";
          }
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }

  function focusSearch() {
    searchInput.forceActiveFocus();
  }
}
