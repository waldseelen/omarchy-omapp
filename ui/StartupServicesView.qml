import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../script/StartupServices.js" as StartupServices

Item {
  id: srvViewRoot

  property var serviceModel: null
  property var items: []
  property int selectedIndex: 0
  property string activeSort: "impact" // "impact", "name", "scope", "state"
  property string sortDirection: "desc"
  property bool sudoActive: false

  property var inspectedItem: (items.length > 0 && selectedIndex >= 0 && selectedIndex < items.length)
    ? items[selectedIndex] : null
  property string currentLogUnit: ""
  property string unitLogs: ""
  property bool logsLoading: false

  signal itemSelected(int index)
  signal sortRequested(string column, string direction)
  signal actionRequested(var item, string action)
  signal contextMenuRequested(real x, real y, var item)

  function toggleSort(column) {
    var nextDir = "desc";
    if (srvViewRoot.activeSort === column) {
      nextDir = (srvViewRoot.sortDirection === "desc") ? "asc" : "desc";
    } else {
      nextDir = (column === "name" || column === "scope") ? "asc" : "desc";
    }
    srvViewRoot.activeSort = column;
    srvViewRoot.sortDirection = nextDir;
    srvViewRoot.sortRequested(column, nextDir);
  }

  onInspectedItemChanged: {
    if (inspectedItem && (inspectedItem.scope === "user" || inspectedItem.scope === "system")) {
      var key = inspectedItem.scope + ":" + inspectedItem.id;
      if (key !== srvViewRoot.currentLogUnit) {
        srvViewRoot.currentLogUnit = key;
        srvViewRoot.logsLoading = true;
        var cmd = StartupServices.buildServiceLogsScript(inspectedItem.id, inspectedItem.scope);
        if (cmd) {
          srvLogProc.command = cmd;
          srvLogProc.running = true;
        }
      }
    } else {
      srvViewRoot.currentLogUnit = "";
      srvViewRoot.unitLogs = inspectedItem ? ("Autostart Entry:\n" + inspectedItem.description) : "";
      srvViewRoot.logsLoading = false;
    }
  }

  Process {
    id: srvLogProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        srvViewRoot.unitLogs = text.trim() || "No journal entries found for this unit.";
        srvViewRoot.logsLoading = false;
      }
    }
  }

  Row {
    anchors.fill: parent
    spacing: Style.space(14)

    // Left Pane: Services & Startup Table
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
            spacing: Style.space(6)

            Item {
              height: parent.height
              width: Math.max(Style.space(120), parent.width - Style.space(236))
              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "Unit / Autostart Item" + (srvViewRoot.activeSort === "name" ? (srvViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : "")
                color: srvViewRoot.activeSort === "name" ? Color.accent : Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: srvViewRoot.toggleSort("name") }
            }

            Item {
              height: parent.height; width: Style.space(68)
              Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "Scope" + (srvViewRoot.activeSort === "scope" ? (srvViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : ""); color: srvViewRoot.activeSort === "scope" ? Color.accent : Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: srvViewRoot.toggleSort("scope") }
            }
            Item {
              height: parent.height; width: Style.space(68)
              Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "State" + (srvViewRoot.activeSort === "state" ? (srvViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : ""); color: srvViewRoot.activeSort === "state" ? Color.accent : Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: srvViewRoot.toggleSort("state") }
            }
            Item {
              height: parent.height; width: Style.space(82)
              Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "Boot Impact" + (srvViewRoot.activeSort === "impact" ? (srvViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : ""); color: srvViewRoot.activeSort === "impact" ? Color.accent : Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: srvViewRoot.toggleSort("impact") }
            }
          }
        }

        ListView {
          id: srvListView
          width: parent.width
          height: parent.height - Style.space(34)
          model: srvViewRoot.serviceModel
          currentIndex: srvViewRoot.selectedIndex
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
              var dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y * 1.8 : (event.angleDelta.y / 120 * Style.space(50));
              if (dy !== 0) {
                var maxY = Math.max(0, srvListView.contentHeight - srvListView.height);
                srvListView.contentY = Math.max(0, Math.min(maxY, srvListView.contentY - dy));
                event.accepted = true;
              }
            }
          }

          delegate: CursorSurface {
            id: srvRow
            required property int index
            required property string unitId
            required property string name
            required property string scope
            required property string state
            required property string subState
            required property int bootMs
            required property string bootFormatted
            required property string impact

            readonly property bool isRowSelected: index === srvViewRoot.selectedIndex

            width: ListView.view ? ListView.view.width : Style.space(400)
            height: Style.space(36)
            foreground: Color.menu.text
            accent: Color.accent
            current: isRowSelected
            hasCursor: srvMouse.containsMouse

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Row {
                height: parent.height
                width: Math.max(Style.space(120), parent.width - Style.space(236))
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: srvRow.state === "failed" ? "󰀦" : (srvRow.subState === "running" ? "󰐊" : "󰒓")
                  color: srvRow.state === "failed" ? Color.urgent : (srvRow.subState === "running" ? Color.accent : Color.muted)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  width: parent.width - Style.space(24)
                  text: srvRow.name
                  color: srvRow.isRowSelected ? Color.accent : Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: srvRow.isRowSelected
                  elide: Text.ElideRight
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(68)
                textFormat: Text.PlainText
                text: srvRow.scope.toUpperCase()
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignRight
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(68)
                textFormat: Text.PlainText
                text: srvRow.subState || srvRow.state
                color: srvRow.state === "failed" ? Color.urgent : (srvRow.subState === "running" || srvRow.state === "enabled" ? Color.accent : Color.muted)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: srvRow.subState === "running" || srvRow.state === "failed"
                horizontalAlignment: Text.AlignRight
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(82)
                textFormat: Text.PlainText
                text: srvRow.bootMs > 0 ? (srvRow.bootFormatted + " (" + srvRow.impact + ")") : "-"
                color: srvRow.impact === "High" ? Color.urgent : (srvRow.impact === "Medium" ? Color.accent : Color.muted)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: srvRow.impact === "High"
                horizontalAlignment: Text.AlignRight
              }
            }

            MouseArea {
              id: srvMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              cursorShape: Qt.PointingHandCursor
              onClicked: function(mouse) {
                srvViewRoot.itemSelected(srvRow.index);
                if (mouse.button === Qt.RightButton) {
                  var gp = srvRow.mapToItem(null, mouse.x, mouse.y);
                  var obj = srvViewRoot.items[srvRow.index];
                  if (obj) srvViewRoot.contextMenuRequested(gp.x, gp.y, obj);
                }
              }
            }
          }
        }
      }
    }

    // Right Pane: Service & Startup Inspector (#8, #9)
    BorderSurface {
      width: parent.width * 0.40 - Style.space(14)
      height: parent.height
      radius: Style.cornerRadius
      color: Style.normalFill
      borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)
      clip: true

      Flickable {
        anchors.fill: parent
        anchors.margins: Style.space(16)
        visible: !!srvViewRoot.inspectedItem
        contentHeight: sCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: sCol
          width: parent.width
          spacing: Style.space(12)

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: srvViewRoot.inspectedItem ? srvViewRoot.inspectedItem.name : ""
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: srvViewRoot.inspectedItem ? (srvViewRoot.inspectedItem.id + " • " + srvViewRoot.inspectedItem.scope) : ""
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Flow {
            width: parent.width
            spacing: Style.space(6)
            visible: !!(srvViewRoot.inspectedItem && (srvViewRoot.inspectedItem.scope === "user" || srvViewRoot.inspectedItem.scope === "system"))

            Button { bordered: true; iconText: "󰐊"; text: "Start"; foreground: Color.accent; accent: Color.accent; onClicked: srvViewRoot.actionRequested(srvViewRoot.inspectedItem, "start") }
            Button { bordered: true; iconText: "󰅙"; text: "Stop"; foreground: Color.urgent; accent: Color.urgent; onClicked: srvViewRoot.actionRequested(srvViewRoot.inspectedItem, "stop") }
            Button { bordered: true; iconText: "󰜉"; text: "Restart"; foreground: Color.menu.text; accent: Color.accent; onClicked: srvViewRoot.actionRequested(srvViewRoot.inspectedItem, "restart") }
            Button { bordered: true; text: "Enable"; onClicked: srvViewRoot.actionRequested(srvViewRoot.inspectedItem, "enable") }
            Button { bordered: true; text: "Disable"; foreground: Color.urgent; accent: Color.urgent; onClicked: srvViewRoot.actionRequested(srvViewRoot.inspectedItem, "disable") }
          }

          Button {
            visible: !!(srvViewRoot.inspectedItem && srvViewRoot.inspectedItem.scope === "xdg-autostart")
            bordered: true
            text: srvViewRoot.inspectedItem && srvViewRoot.inspectedItem.state === "enabled" ? "Disable Autostart Entry" : "Enable Autostart Entry"
            foreground: Color.accent
            accent: Color.accent
            onClicked: {
              var act = (srvViewRoot.inspectedItem.state === "enabled") ? "disable" : "enable";
              srvViewRoot.actionRequested(srvViewRoot.inspectedItem, act);
            }
          }

          PanelSeparator { foreground: Color.menu.text }

          Text {
            textFormat: Text.PlainText
            text: "Recent Journal Logs / Autostart Command"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          BorderSurface {
            width: parent.width
            implicitHeight: Math.max(Style.space(180), srvLogText.implicitHeight + Style.space(16))
            height: implicitHeight
            radius: Style.cornerRadius
            color: Style.hoverFill
            borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

            Text {
              id: srvLogText
              anchors.fill: parent
              anchors.margins: Style.space(8)
              textFormat: Text.PlainText
              text: srvViewRoot.logsLoading ? "Loading logs..." : srvViewRoot.unitLogs
              color: Color.menu.text
              font.family: Style.font.monoFamily || Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WrapAnywhere
            }
          }
        }
      }
    }
  }

  function positionAt(idx) {
    if (idx >= 0 && idx < srvListView.count) {
      srvListView.positionViewAtIndex(idx, ListView.Contain);
    }
  }
}
