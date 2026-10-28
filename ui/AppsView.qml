import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import ".."

Row {
  id: appsViewRoot

  property var shell: null
  property var appModel: null
  property var displayItems: []
  property int selectedIndex: 0
  property string activeSort: "size"
  property string sortDirection: "desc"
  property var runningPids: ({})
  property var selectedBatchMap: ({})
  property int selectedBatchCount: 0
  property var colWidths: ({ type: 62, userdata: 66, version: 68, size: 68 })

  signal rowSelected(int index)
  signal sortRequested(string column)
  signal toggleCheckRequested(string pkg)
  signal clearBatchRequested()
  signal batchUninstallRequested()
  signal uninstallRequested(var app)
  signal killRequested(var app)
  signal launchRequested(var app)
  signal openConfigRequested(var app)
  signal openUrlRequested(string url)
  signal togglePinRequested(string pkg)
  signal downgradeRequested(string pkg, string archivePath)
  signal contextMenuRequested(real x, real y, var app)
  signal colWidthChanged(string colKey, int newWidth)

  spacing: Style.space(14)

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

      // Batch Uninstall Action Bar (#13)
      BorderSurface {
        visible: appsViewRoot.selectedBatchCount > 0
        width: parent.width
        height: Style.space(32)
        radius: Style.cornerRadius
        color: Util.alpha(Color.urgent, Style.normalFillAlpha)
        borderSpec: Border.controlSpec("normal", Color.urgent, Color.urgent)

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(10)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "󰩺 " + appsViewRoot.selectedBatchCount + " packages selected"
            color: Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          Button {
            anchors.verticalCenter: parent.verticalCenter
            bordered: true
            text: "Batch Uninstall Selected"
            foreground: Color.urgent
            accent: Color.urgent
            fontSize: Style.font.caption
            horizontalPadding: Style.space(8)
            verticalPadding: Style.space(3)
            onClicked: appsViewRoot.batchUninstallRequested()
          }

          Button {
            anchors.verticalCenter: parent.verticalCenter
            bordered: true
            text: "Clear"
            foreground: Color.menu.text
            accent: Color.accent
            fontSize: Style.font.caption
            horizontalPadding: Style.space(8)
            verticalPadding: Style.space(3)
            onClicked: appsViewRoot.clearBatchRequested()
          }
        }
      }

      // Clickable & Draggable Column Header Bar (#28)
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

          Item { width: Style.space(20); height: parent.height }

          // 1. Application Name
          Item {
            height: parent.height
            width: Math.max(
              Style.space(100),
              parent.width - (Style.space(20) + appsViewRoot.colWidths.type + appsViewRoot.colWidths.userdata + appsViewRoot.colWidths.version + appsViewRoot.colWidths.size + Style.space(30))
            )

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "Application" + (appsViewRoot.activeSort === "name" ? (appsViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : "")
              color: appsViewRoot.activeSort === "name" ? Color.accent : Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: appsViewRoot.sortRequested("name")
            }
          }

          // 2. Type
          Item {
            height: parent.height
            width: appsViewRoot.colWidths.type

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "Type" + (appsViewRoot.activeSort === "category" ? (appsViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : "")
              color: appsViewRoot.activeSort === "category" ? Color.accent : Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: appsViewRoot.sortRequested("category")
            }
          }

          // 3. User Data (#11)
          Item {
            height: parent.height
            width: appsViewRoot.colWidths.userdata

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "Data" + (appsViewRoot.activeSort === "userdata" ? (appsViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : "")
              color: appsViewRoot.activeSort === "userdata" ? Color.accent : Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: appsViewRoot.sortRequested("userdata")
            }
          }

          // 4. Version
          Item {
            height: parent.height
            width: appsViewRoot.colWidths.version

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "Ver" + (appsViewRoot.activeSort === "version" ? (appsViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : "")
              color: appsViewRoot.activeSort === "version" ? Color.accent : Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: appsViewRoot.sortRequested("version")
            }
          }

          // 5. Size
          Item {
            height: parent.height
            width: appsViewRoot.colWidths.size

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "Size" + (appsViewRoot.activeSort === "size" ? (appsViewRoot.sortDirection === "asc" ? " ▲" : " ▼") : "")
              color: appsViewRoot.activeSort === "size" ? Color.accent : Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: appsViewRoot.sortRequested("size")
            }
          }
        }
      }

      ListView {
        id: appListView
        width: parent.width
        height: parent.height - Style.space(appsViewRoot.selectedBatchCount > 0 ? 70 : 34)
        model: appsViewRoot.appModel
        currentIndex: appsViewRoot.selectedIndex
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
              var maxY = Math.max(0, appListView.contentHeight - appListView.height);
              appListView.contentY = Math.max(0, Math.min(maxY, appListView.contentY - dy));
              event.accepted = true;
            }
          }
        }

        delegate: AppGridRow {
          required property int index
          required property string name
          required property string pkg
          required property string version
          required property string icon
          required property string category
          required property string sizeFormatted
          required property string userDataFormatted
          required property bool running
          required property bool pinned
          required property bool isProtected
          required property bool isUnused
          required property bool checked

          shell: appsViewRoot.shell
          isSelected: index === appsViewRoot.selectedIndex
          isChecked: checked
          isPinned: pinned
          isProtected: isProtected
          isUnused: isUnused
          appName: name
          appPkg: pkg
          appVersion: version
          appIcon: icon
          appCategory: category
          appSize: sizeFormatted
          appUserData: userDataFormatted
          appRunning: running
          typeColWidth: appsViewRoot.colWidths.type
          userDataColWidth: appsViewRoot.colWidths.userdata
          verColWidth: appsViewRoot.colWidths.version
          sizeColWidth: appsViewRoot.colWidths.size

          onClicked: appsViewRoot.rowSelected(index)
          onToggleCheck: appsViewRoot.toggleCheckRequested(pkg)
          onRightClicked: function(rx, ry) {
            appsViewRoot.rowSelected(index);
            var itemObj = appsViewRoot.displayItems[index];
            if (itemObj) appsViewRoot.contextMenuRequested(rx, ry, itemObj);
          }
        }

        Item {
          anchors.fill: parent
          visible: appsViewRoot.displayItems.length === 0

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "No matching applications found"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }
      }
    }
  }

  AppInspector {
    id: inspector
    shell: appsViewRoot.shell
    width: parent.width * 0.40 - Style.space(14)
    height: parent.height
    appItem: (appsViewRoot.displayItems.length > 0 && appsViewRoot.selectedIndex >= 0 && appsViewRoot.selectedIndex < appsViewRoot.displayItems.length)
      ? appsViewRoot.displayItems[appsViewRoot.selectedIndex] : null
    isRunning: appItem ? (!!appsViewRoot.runningPids[appItem.pkg] || !!appsViewRoot.runningPids[appItem.name.toLowerCase()]) : false
    runningPid: appItem ? (appsViewRoot.runningPids[appItem.pkg] || appsViewRoot.runningPids[appItem.name.toLowerCase()] || "") : ""

    onUninstallRequested: function(app) { appsViewRoot.uninstallRequested(app); }
    onKillRequested: function(app) { appsViewRoot.killRequested(app); }
    onLaunchRequested: function(app) { appsViewRoot.launchRequested(app); }
    onOpenConfigRequested: function(app) { appsViewRoot.openConfigRequested(app); }
    onOpenUrlRequested: function(url) { appsViewRoot.openUrlRequested(url); }
    onTogglePinRequested: function(pkg) { appsViewRoot.togglePinRequested(pkg); }
    onDowngradeRequested: function(pkg, path) { appsViewRoot.downgradeRequested(pkg, path); }
  }

  function positionAt(idx) {
    if (idx >= 0 && idx < appListView.count) {
      appListView.positionViewAtIndex(idx, ListView.Contain);
    }
  }
}
