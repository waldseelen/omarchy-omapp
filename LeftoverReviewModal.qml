import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Rectangle {
  id: leftoverModalRoot

  property bool isOpen: false
  property var appItem: null
  property int phase: 1 // 1: Removing Package, 2: Scanning Leftovers, 3: Review & Purge, 4: Done / Orphans
  property var leftoverItems: []
  property int totalLeftoverBytes: 0
  property string totalLeftoverFormatted: "0 B"
  property string statusMessage: ""
  property string orphanListText: ""
  property bool isPurging: false

  signal confirmedPurge(var selectedPaths)
  signal pruneOrphansRequested()
  signal closed()

  anchors.fill: parent
  color: Color.menu.scrim
  visible: isOpen
  z: 110

  MouseArea {
    anchors.fill: parent
    onClicked: {}
  }

  BorderSurface {
    id: modalBox
    anchors.centerIn: parent
    width: Style.space(680)
    height: Style.space(480)
    radius: Style.cornerRadius
    color: Color.menu.background
    borderSpec: Border.controlSpec("selected", Color.menu.text, Color.accent)

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(20)
      spacing: Style.space(14)

      Row {
        width: parent.width
        spacing: Style.space(12)

        Text {
          textFormat: Text.PlainText
          text: "󰃢"
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.display
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          width: parent.width - Style.space(60)
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            text: "OMAPP Deep Cleaner — " + (leftoverModalRoot.appItem ? (leftoverModalRoot.appItem.name || leftoverModalRoot.appItem.pkg) : "")
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            text: {
              if (leftoverModalRoot.phase === 1) return "Step 1/3: Removing system package...";
              if (leftoverModalRoot.phase === 2) return "Step 2/3: Scanning for residual user configs and caches...";
              if (leftoverModalRoot.phase === 3) return "Step 3/3: Review residual files before permanent purge";
              return "Uninstallation Complete";
            }
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }
      }

      PanelSeparator {
        foreground: Color.menu.text
      }

      // Phase 1 & 2: Working State
      Item {
        visible: leftoverModalRoot.phase === 1 || leftoverModalRoot.phase === 2
        width: parent.width
        height: Style.space(310)

        Column {
          anchors.centerIn: parent
          spacing: Style.space(12)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: "󰒋"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.displayLarge
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: leftoverModalRoot.statusMessage || "Working..."
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }
      }

      // Phase 3: Leftovers Review List
      Item {
        visible: leftoverModalRoot.phase === 3
        width: parent.width
        height: Style.space(310)

        Column {
          anchors.fill: parent
          spacing: Style.space(10)

          Item {
            width: parent.width
            height: Style.space(28)

            BorderSurface {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              height: parent.height
              width: reclaimText.implicitWidth + Style.space(16)
              radius: Style.cornerRadius
              color: Style.hoverFill
              borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

              Text {
                id: reclaimText
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "Residual footprint: " + leftoverModalRoot.totalLeftoverFormatted
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Button {
                text: "Select All"
                bordered: true
                fontSize: Style.font.caption
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(3)
                onClicked: {
                  for (var i = 0; i < leftoverModalRoot.leftoverItems.length; i++) {
                    leftoverModalRoot.leftoverItems[i].selected = true;
                  }
                  leftoverModalRoot.updateTotalSelected();
                }
              }

              Button {
                text: "Deselect All"
                bordered: true
                fontSize: Style.font.caption
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(3)
                onClicked: {
                  for (var i = 0; i < leftoverModalRoot.leftoverItems.length; i++) {
                    leftoverModalRoot.leftoverItems[i].selected = false;
                  }
                  leftoverModalRoot.updateTotalSelected();
                }
              }
            }
          }

          BorderSurface {
            width: parent.width
            height: Style.space(235)
            radius: Style.cornerRadius
            color: Style.normalFill
            borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)
            clip: true

            ListView {
              id: leftoverList
              anchors.fill: parent
              anchors.margins: Style.space(6)
              model: leftoverModalRoot.leftoverItems
              spacing: Style.space(4)
              boundsBehavior: Flickable.StopAtBounds

              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

              delegate: CursorSurface {
                required property var modelData
                width: leftoverList.width
                height: Style.space(34)
                current: !!modelData.selected
                hasCursor: itemMouse.containsMouse

                Item {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)

                  BorderSurface {
                    id: checkRect
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(16)
                    height: Style.space(16)
                    radius: Style.cornerRadius
                    color: modelData.selected ? Color.accent : "transparent"
                    borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

                    Text {
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: "✓"
                      color: Color.menu.background
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      visible: !!modelData.selected
                    }
                  }

                  Text {
                    id: tagLabel
                    anchors.left: checkRect.right
                    anchors.leftMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: modelData.category ? modelData.category.toUpperCase() : "FILE"
                    color: Color.accent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Text {
                    id: sizeLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: modelData.sizeFormatted
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }

                  Text {
                    anchors.left: tagLabel.right
                    anchors.leftMargin: Style.space(10)
                    anchors.right: sizeLabel.left
                    anchors.rightMargin: Style.space(10)
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
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    modelData.selected = !modelData.selected;
                    leftoverModalRoot.updateTotalSelected();
                  }
                }
              }
            }

            Item {
              anchors.fill: parent
              visible: leftoverModalRoot.leftoverItems.length === 0

              Column {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: "󰄬"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.display
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: "No residual user configs or caches found."
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "Safety backup is created in ~/.local/share/omapp/backups/ prior to deletion."
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }

      // Phase 4: Orphans & Done View
      Item {
        visible: leftoverModalRoot.phase === 4
        width: parent.width
        height: Style.space(310)

        Column {
          anchors.fill: parent
          spacing: Style.space(14)

          Row {
            spacing: Style.space(10)
            Text {
              textFormat: Text.PlainText
              text: "󰄬"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.display
            }
            Column {
              Text {
                textFormat: Text.PlainText
                text: "Application and Residual Data Cleaned"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                textFormat: Text.PlainText
                text: "Successfully removed package and reclaimed disk space."
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

          BorderSurface {
            visible: !!leftoverModalRoot.orphanListText && leftoverModalRoot.orphanListText !== "NO_ORPHANS"
            width: parent.width
            height: Style.space(160)
            radius: Style.cornerRadius
            color: Style.hoverFill
            borderSpec: Border.controlSpec("normal", Color.urgent, Color.urgent)

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(12)
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: "󰏖 Unneeded Orphan Dependencies Detected"
                color: Color.urgent
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: leftoverModalRoot.orphanListText
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
              }

              Button {
                bordered: true
                iconText: "󰩺"
                text: "Prune Orphan Packages"
                foreground: Color.urgent
                accent: Color.urgent
                onClicked: leftoverModalRoot.pruneOrphansRequested()
              }
            }
          }
        }
      }

      // Footer Buttons
      Row {
        anchors.right: parent.right
        spacing: Style.space(10)

        Button {
          bordered: true
          text: {
            if (leftoverModalRoot.phase === 4 || leftoverModalRoot.leftoverItems.length === 0) return "Done";
            if (leftoverModalRoot.phase === 1 || leftoverModalRoot.phase === 2) return "Cancel";
            return "Skip Residuals";
          }
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
          text: leftoverModalRoot.isPurging ? "Purging..." : "Permanently Purge Selected"
          foreground: Color.urgent
          accent: Color.urgent
          background: Util.alpha(Color.urgent, Style.normalFillAlpha)
          onClicked: {
            if (leftoverModalRoot.isPurging) return;
            var selected = [];
            for (var i = 0; i < leftoverModalRoot.leftoverItems.length; i++) {
              if (leftoverModalRoot.leftoverItems[i].selected) {
                selected.push(leftoverModalRoot.leftoverItems[i].path);
              }
            }
            leftoverModalRoot.confirmedPurge(selected);
          }
        }
      }
    }
  }

  function updateTotalSelected() {
    var total = 0;
    for (var i = 0; i < leftoverModalRoot.leftoverItems.length; i++) {
      if (leftoverModalRoot.leftoverItems[i].selected) {
        total += leftoverModalRoot.leftoverItems[i].size || 0;
      }
    }
    leftoverModalRoot.totalLeftoverBytes = total;
    leftoverModalRoot.totalLeftoverFormatted = (total === 0) ? "0 B" : ((total / (1024 * 1024)).toFixed(1) + " MiB");
  }
}
