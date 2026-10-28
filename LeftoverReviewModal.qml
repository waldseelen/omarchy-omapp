import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui
import "script/LeftoverHunter.js" as LeftoverHunter
import "script/SafeOps.js" as SafeOps

Rectangle {
  id: leftoverModalRoot

  property bool isOpen: false
  property var appItem: null
  property string home: ""
  property int phase: 1 // 1: Removing, 2: Scanning, 3: Review & Preview, 4: Done
  property var leftoverItems: []
  property int totalLeftoverBytes: 0
  property string totalLeftoverFormatted: "0 B"
  property string statusMessage: ""
  property string orphanListText: ""
  property bool isPurging: false
  property string previewPath: ""
  property string previewContent: ""

  signal confirmedPurge(var selectedPaths)
  signal pruneOrphansRequested()
  signal closed()

  anchors.fill: parent
  color: Color.menu.scrim
  visible: isOpen
  z: 110

  Process {
    id: previewProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        leftoverModalRoot.previewContent = text.trim() || "(Empty file or directory)";
      }
    }
  }

  function loadPreview(path) {
    if (leftoverModalRoot.previewPath === path) {
      leftoverModalRoot.previewPath = "";
      return;
    }
    leftoverModalRoot.previewPath = path;
    leftoverModalRoot.previewContent = "Loading preview...";
    var cmd = LeftoverHunter.buildPreviewCommand(path, leftoverModalRoot.home, SafeOps);
    if (cmd) {
      previewProc.command = cmd;
      previewProc.running = true;
    } else {
      leftoverModalRoot.previewContent = "Preview blocked outside safe user paths.";
    }
  }

  MouseArea { anchors.fill: parent; onClicked: {} }

  BorderSurface {
    id: modalBox
    anchors.centerIn: parent
    width: Style.space(700)
    height: Style.space(500)
    radius: Style.cornerRadius
    color: Color.menu.background
    borderSpec: Border.controlSpec("selected", Color.menu.text, Color.accent)

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(18)
      spacing: Style.space(12)

      Row {
        width: parent.width; spacing: Style.space(10)
        Text { textFormat: Text.PlainText; text: "󰃢"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.display }
        Column {
          width: parent.width - Style.space(50); spacing: Style.space(2)
          Text { textFormat: Text.PlainText; text: "OMAPP Deep Cleaner — " + (leftoverModalRoot.appItem ? (leftoverModalRoot.appItem.name || leftoverModalRoot.appItem.pkg) : "Orphaned Dotfiles"); color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true; elide: Text.ElideRight }
          Text {
            textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
            text: leftoverModalRoot.phase === 1 ? "Step 1/3: Removing system package..." : (leftoverModalRoot.phase === 2 ? "Step 2/3: Scanning residual user configs and caches..." : (leftoverModalRoot.phase === 3 ? "Step 3/3: Review & preview residual files before purge" : "Cleanup Complete"))
          }
        }
      }

      PanelSeparator { foreground: Color.menu.text }

      Item {
        visible: leftoverModalRoot.phase === 1 || leftoverModalRoot.phase === 2; width: parent.width; height: Style.space(330)
        Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: leftoverModalRoot.statusMessage || "Working..."; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.body }
      }

      // Phase 3: Review + File Preview (#18)
      Item {
        visible: leftoverModalRoot.phase === 3
        width: parent.width
        height: Style.space(330)

        Column {
          anchors.fill: parent
          spacing: Style.space(8)

          Item {
            width: parent.width
            height: Style.space(26)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "Selected footprint: " + leftoverModalRoot.totalLeftoverFormatted + " (auto-backed up to ~/.local/share/omapp/backups)"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Row {
              anchors.right: parent.right
              spacing: Style.space(6)

              Button {
                text: "Select All"
                bordered: true
                fontSize: Style.font.caption
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(2)
                onClicked: {
                  for (var i = 0; i < leftoverModalRoot.leftoverItems.length; i++) leftoverModalRoot.leftoverItems[i].selected = true;
                  leftoverModalRoot.updateTotalSelected();
                }
              }

              Button {
                text: "Deselect All"
                bordered: true
                fontSize: Style.font.caption
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(2)
                onClicked: {
                  for (var i = 0; i < leftoverModalRoot.leftoverItems.length; i++) leftoverModalRoot.leftoverItems[i].selected = false;
                  leftoverModalRoot.updateTotalSelected();
                }
              }
            }
          }

          BorderSurface {
            width: parent.width
            height: leftoverModalRoot.previewPath.length > 0 ? Style.space(180) : Style.space(290)
            radius: Style.cornerRadius
            color: Style.normalFill
            borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)
            clip: true

            ListView {
              id: leftoverList
              anchors.fill: parent
              anchors.margins: Style.space(6)
              model: leftoverModalRoot.leftoverItems
              spacing: Style.space(3)
              boundsBehavior: Flickable.StopAtBounds

              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

              delegate: CursorSurface {
                required property var modelData
                width: leftoverList.width
                height: Style.space(32)
                current: !!modelData.selected
                hasCursor: itemMouse.containsMouse

                Item {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)

                  Text {
                    id: chkTxt
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: modelData.selected ? "☑" : "☐"
                    color: modelData.selected ? Color.accent : Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                  }

                  Text {
                    id: catTxt
                    anchors.left: chkTxt.right
                    anchors.leftMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: modelData.category ? modelData.category.toUpperCase() : "FILE"
                    color: Color.accent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Button {
                    id: prevBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    bordered: true
                    iconText: "󰈈"
                    text: "Preview"
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(6)
                    verticalPadding: Style.space(1)
                    z: 2
                    onClicked: leftoverModalRoot.loadPreview(modelData.path)
                  }

                  Text {
                    id: szTxt
                    anchors.right: prevBtn.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: modelData.sizeFormatted
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }

                  Text {
                    anchors.left: catTxt.right
                    anchors.leftMargin: Style.space(8)
                    anchors.right: szTxt.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: "~/" + modelData.relative
                    color: Color.menu.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideMiddle
                  }
                }

                MouseArea {
                  id: itemMouse
                  anchors.fill: parent
                  anchors.rightMargin: Style.space(70)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    modelData.selected = !modelData.selected;
                    leftoverModalRoot.updateTotalSelected();
                  }
                }
              }
            }
          }

          // File/Folder Quick Preview Pane (#18)
          BorderSurface {
            visible: leftoverModalRoot.previewPath.length > 0
            width: parent.width
            height: Style.space(102)
            radius: Style.cornerRadius
            color: Style.hoverFill
            borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)
            clip: true

            Flickable {
              anchors.fill: parent
              anchors.margins: Style.space(6)
              contentHeight: prevTxt.implicitHeight
              boundsBehavior: Flickable.StopAtBounds

              Text {
                id: prevTxt
                width: parent.width
                textFormat: Text.PlainText
                text: leftoverModalRoot.previewContent
                color: Color.menu.text
                font.family: Style.font.monoFamily || Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WrapAnywhere
              }
            }
          }
        }
      }

      // Phase 4: Done & Orphans
      Item {
        visible: leftoverModalRoot.phase === 4
        width: parent.width
        height: Style.space(330)

        Column {
          anchors.centerIn: parent
          spacing: Style.space(10)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: "󰄬 Cleanup Complete"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
          }

          Button {
            visible: !!leftoverModalRoot.orphanListText && leftoverModalRoot.orphanListText !== "NO_ORPHANS"
            anchors.horizontalCenter: parent.horizontalCenter
            bordered: true
            iconText: "󰩺"
            text: "Prune Orphan Dependencies (" + leftoverModalRoot.orphanListText.split(/\s+/).length + ")"
            foreground: Color.urgent
            accent: Color.urgent
            onClicked: leftoverModalRoot.pruneOrphansRequested()
          }
        }
      }

      // Footer Buttons
      Row {
        anchors.right: parent.right
        spacing: Style.space(10)

        Button {
          bordered: true
          text: (leftoverModalRoot.phase === 4 || leftoverModalRoot.leftoverItems.length === 0) ? "Done" : "Close"
          foreground: Color.menu.text
          accent: Color.accent
          onClicked: {
            leftoverModalRoot.isOpen = false;
            leftoverModalRoot.closed();
          }
        }

        Button {
          visible: leftoverModalRoot.phase === 3 && leftoverModalRoot.leftoverItems.length > 0
          bordered: true
          iconText: "󰩺"
          text: leftoverModalRoot.isPurging ? "Purging..." : "Backup & Purge Selected"
          foreground: Color.urgent
          accent: Color.urgent
          background: Util.alpha(Color.urgent, Style.normalFillAlpha)
          onClicked: {
            if (leftoverModalRoot.isPurging) return;
            var sel = [];
            for (var i = 0; i < leftoverModalRoot.leftoverItems.length; i++) {
              if (leftoverModalRoot.leftoverItems[i].selected) sel.push(leftoverModalRoot.leftoverItems[i].path);
            }
            leftoverModalRoot.confirmedPurge(sel);
          }
        }
      }
    }
  }

  function updateTotalSelected() {
    var total = 0;
    for (var i = 0; i < leftoverModalRoot.leftoverItems.length; i++) {
      if (leftoverModalRoot.leftoverItems[i].selected) total += leftoverModalRoot.leftoverItems[i].size || 0;
    }
    leftoverModalRoot.totalLeftoverBytes = total;
    leftoverModalRoot.totalLeftoverFormatted = (total === 0) ? "0 B" : ((total / (1024 * 1024)).toFixed(1) + " MiB");
    leftoverList.model = [];
    leftoverList.model = leftoverModalRoot.leftoverItems;
  }
}
