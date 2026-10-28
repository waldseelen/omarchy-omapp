import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: footerBar

  property string activeTab: "apps"
  property int selectedBatchCount: 0

  height: Style.space(28)
  radius: Style.cornerRadius
  color: Style.normalFill
  borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

  Row {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(14)

    Repeater {
      model: {
        if (footerBar.activeTab === "tasks") {
          return [
            { key: "↑/↓/J/K", desc: "Navigate" },
            { key: "/", desc: "Filter" },
            { key: "Del/K", desc: "End Task" },
            { key: "F", desc: "Freeze/Resume" },
            { key: "G", desc: "Group by App" },
            { key: "P", desc: "Pin Top" },
            { key: "1-4", desc: "Switch Tab" }
          ];
        }
        if (footerBar.activeTab === "services") {
          return [
            { key: "↑/↓/J/K", desc: "Navigate" },
            { key: "/", desc: "Filter" },
            { key: "R", desc: "Restart Unit" },
            { key: "S", desc: "Start/Stop" },
            { key: "E", desc: "Enable/Disable" },
            { key: "1-4", desc: "Switch Tab" }
          ];
        }
        if (footerBar.activeTab === "janitor") {
          return [
            { key: "R", desc: "Rescan Storage" },
            { key: "1-4", desc: "Switch Tab" },
            { key: "Esc", desc: "Back to Apps" }
          ];
        }
        return [
          { key: "↑/↓/J/K", desc: "Navigate" },
          { key: "/", desc: "Search" },
          { key: "Space", desc: "Select Batch" },
          { key: "Del/U", desc: "Deep Uninstall" },
          { key: "P", desc: "Pin Top" },
          { key: "1-4", desc: "Switch Tab" },
          { key: "Right-Click", desc: "Actions" }
        ];
      }

      Row {
        required property var modelData
        spacing: Style.space(4)

        BorderSurface {
          height: Style.space(18)
          width: kText.implicitWidth + Style.space(8)
          radius: Style.cornerRadius
          color: Style.hoverFill
          borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

          Text {
            id: kText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: modelData.key
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: modelData.desc
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  Text {
    anchors.right: parent.right
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: footerBar.selectedBatchCount > 0
      ? (footerBar.selectedBatchCount + " selected for batch uninstall")
      : "OMAPP Pro • Native Quickshell"
    color: footerBar.selectedBatchCount > 0 ? Color.accent : Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: footerBar.selectedBatchCount > 0
  }
}
