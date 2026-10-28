import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../script/TaskControl.js" as TaskControl

BorderSurface {
  id: pInspector

  property var inspectedTask: null
  property bool sudoActive: false
  property int currentInspectedPid: -1
  property var inspectedDetails: ({ exe: "", cwd: "", cmd: "", pkg: "", ports: "", affinity: "", logs: "" })
  property bool isDetailsLoading: false
  property bool showLogsDrawer: false

  signal killRequested(int pid, bool force)
  signal freezeRequested(int pid, bool freeze)
  signal reniceRequested(int pid, int priority)
  signal affinityRequested(int pid, string cpuList)
  signal openLocationRequested(int pid)
  signal inspectPackageRequested(string pkg)
  signal togglePinRequested(string name)

  radius: Style.cornerRadius
  color: Style.normalFill
  borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)
  clip: true

  onInspectedTaskChanged: {
    if (inspectedTask) {
      if (inspectedTask.pid !== pInspector.currentInspectedPid) {
        pInspector.currentInspectedPid = inspectedTask.pid;
        pInspector.isDetailsLoading = true;
        detailsProc.command = TaskControl.buildGetProcessDetailsScript(inspectedTask.pid);
        detailsProc.running = true;
      }
    } else {
      pInspector.currentInspectedPid = -1;
      pInspector.inspectedDetails = { exe: "", cwd: "", cmd: "", pkg: "", ports: "", affinity: "", logs: "" };
      pInspector.isDetailsLoading = false;
    }
  }

  Process {
    id: detailsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        pInspector.inspectedDetails = TaskControl.parseProcessDetails(text);
        pInspector.isDetailsLoading = false;
      }
    }
  }

  Item {
    anchors.fill: parent
    visible: !pInspector.inspectedTask

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: "Select a process to inspect & control"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }

  Flickable {
    anchors.fill: parent
    anchors.margins: Style.space(16)
    visible: !!pInspector.inspectedTask
    contentHeight: pCol.implicitHeight
    pixelAligned: true
    boundsBehavior: Flickable.StopAtBounds

    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: pCol
      width: parent.width
      spacing: Style.space(12)

      // Header
      Row {
        width: parent.width
        spacing: Style.space(12)

        BorderSurface {
          width: Style.space(42)
          height: Style.space(42)
          radius: Style.cornerRadius
          color: Style.hoverFill
          borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: pInspector.inspectedTask && pInspector.inspectedTask.isFrozen ? "󰜗" : "󰒋"
            color: pInspector.inspectedTask && pInspector.inspectedTask.cpu > 10.0 ? Color.urgent : Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.iconLarge
          }
        }

        Column {
          width: parent.width - Style.space(54)
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: pInspector.inspectedTask ? pInspector.inspectedTask.name : ""
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: pInspector.inspectedTask
              ? ("PID " + pInspector.inspectedTask.pid + " • " + pInspector.inspectedTask.user + " • Nice " + (pInspector.inspectedTask.nice || 0))
              : ""
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }
      }

      // Primary Action Row (#4 Freeze/Resume, #30 Pin)
      Flow {
        width: parent.width
        spacing: Style.space(6)

        Button {
          bordered: true
          iconText: "󰅙"
          text: "End Task"
          foreground: Color.urgent
          accent: Color.urgent
          background: Util.alpha(Color.urgent, Style.normalFillAlpha)
          onClicked: {
            if (pInspector.inspectedTask) pInspector.killRequested(pInspector.inspectedTask.pid, false);
          }
        }

        Button {
          bordered: true
          iconText: "󰚌"
          text: "Force Kill"
          foreground: Color.urgent
          accent: Color.urgent
          onClicked: {
            if (pInspector.inspectedTask) pInspector.killRequested(pInspector.inspectedTask.pid, true);
          }
        }

        Button {
          bordered: true
          iconText: (pInspector.inspectedTask && pInspector.inspectedTask.isFrozen) ? "󰐊" : "󰏤"
          text: (pInspector.inspectedTask && pInspector.inspectedTask.isFrozen) ? "Resume" : "Freeze"
          foreground: Color.accent
          accent: Color.accent
          onClicked: {
            if (pInspector.inspectedTask) {
              pInspector.freezeRequested(pInspector.inspectedTask.pid, !pInspector.inspectedTask.isFrozen);
            }
          }
        }

        Button {
          bordered: true
          iconText: "󰉋"
          text: "Folder"
          foreground: Color.menu.text
          accent: Color.accent
          onClicked: {
            if (pInspector.inspectedTask) pInspector.openLocationRequested(pInspector.inspectedTask.pid);
          }
        }

        Button {
          bordered: true
          selected: !!(pInspector.inspectedTask && pInspector.inspectedTask.pinned)
          iconText: "󰐃"
          text: "Pin"
          foreground: Color.menu.text
          accent: Color.accent
          onClicked: {
            if (pInspector.inspectedTask) pInspector.togglePinRequested(pInspector.inspectedTask.name);
          }
        }

        Button {
          visible: !!pInspector.inspectedDetails.pkg
          bordered: true
          iconText: "󰏖"
          text: pInspector.inspectedDetails.pkg
          foreground: Color.accent
          accent: Color.accent
          onClicked: pInspector.inspectPackageRequested(pInspector.inspectedDetails.pkg)
        }
      }

      // Priority & CPU Affinity Controls (#3)
      Row {
        width: parent.width
        spacing: Style.space(6)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "Priority:"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        Button {
          bordered: true
          text: "High (-10)"
          fontSize: Style.font.caption
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(2)
          onClicked: { if (pInspector.inspectedTask) pInspector.reniceRequested(pInspector.inspectedTask.pid, -10); }
        }

        Button {
          bordered: true
          text: "Normal (0)"
          fontSize: Style.font.caption
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(2)
          onClicked: { if (pInspector.inspectedTask) pInspector.reniceRequested(pInspector.inspectedTask.pid, 0); }
        }

        Button {
          bordered: true
          text: "Low (+10)"
          fontSize: Style.font.caption
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(2)
          onClicked: { if (pInspector.inspectedTask) pInspector.reniceRequested(pInspector.inspectedTask.pid, 10); }
        }
      }

      // 4-Metric Telemetry Card (CPU | GPU | RAM | Disk I/O #5)
      BorderSurface {
        width: parent.width
        height: Style.space(58)
        radius: Style.cornerRadius
        color: Style.hoverFill
        borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

        Row {
          anchors.fill: parent
          anchors.margins: Style.space(8)

          Column {
            width: parent.width / 4
            Text { textFormat: Text.PlainText; text: "CPU"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            Text { textFormat: Text.PlainText; text: pInspector.inspectedTask ? pInspector.inspectedTask.cpuFormatted : "0.0%"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true }
          }

          Column {
            width: parent.width / 4
            Text { textFormat: Text.PlainText; text: "GPU"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            Text { textFormat: Text.PlainText; text: pInspector.inspectedTask ? pInspector.inspectedTask.gpuFormatted : "0.0%"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true }
          }

          Column {
            width: parent.width / 4
            Text { textFormat: Text.PlainText; text: "RAM"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            Text { textFormat: Text.PlainText; text: pInspector.inspectedTask ? pInspector.inspectedTask.rssFormatted : "0 B"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true }
          }

          Column {
            width: parent.width / 4
            Text { textFormat: Text.PlainText; text: "Disk I/O"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            Text { textFormat: Text.PlainText; text: pInspector.inspectedTask ? (pInspector.inspectedTask.diskFormatted || "0 B/s") : "0 B/s"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true }
          }
        }
      }

      PanelSeparator { foreground: Color.menu.text }

      // Details & Network Ports (#10)
      Column {
        width: parent.width
        spacing: Style.space(6)

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(95); text: "Executable"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(95); text: pInspector.inspectedDetails.exe || "-"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideMiddle }
        }

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(95); text: "CPU Affinity"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(95); text: pInspector.inspectedDetails.affinity || "All Cores"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
        }

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(95); text: "Listen Ports"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(95); text: pInspector.inspectedDetails.ports || "None"; color: pInspector.inspectedDetails.ports ? Color.accent : Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: !!pInspector.inspectedDetails.ports; wrapMode: Text.Wrap }
        }

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(95); text: "Command"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(95); text: pInspector.inspectedDetails.cmd || "-"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WrapAnywhere }
        }
      }

      // Live Journal Logs Drawer (#9)
      Button {
        width: parent.width
        bordered: true
        selected: pInspector.showLogsDrawer
        iconText: "󰌱"
        text: pInspector.showLogsDrawer ? "Hide Process Logs" : "Show Process Journal Logs (_PID)"
        fontSize: Style.font.caption
        onClicked: pInspector.showLogsDrawer = !pInspector.showLogsDrawer
      }

      BorderSurface {
        visible: pInspector.showLogsDrawer
        width: parent.width
        implicitHeight: logText.implicitHeight + Style.space(12)
        height: implicitHeight
        radius: Style.cornerRadius
        color: Style.hoverFill
        borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

        Text {
          id: logText
          anchors.fill: parent
          anchors.margins: Style.space(6)
          textFormat: Text.PlainText
          text: pInspector.inspectedDetails.logs || "No journal entries recorded for this PID."
          color: Color.menu.text
          font.family: Style.font.monoFamily || Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WrapAnywhere
        }
      }
    }
  }
}
