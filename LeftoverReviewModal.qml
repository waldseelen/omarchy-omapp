import QtQuick
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
  color: Util.alpha("#000000", 0.7)
  visible: isOpen
  z: 110

  // Intercept clicks
  MouseArea {
    anchors.fill: parent
    onClicked: {}
  }

  Rectangle {
    id: modalBox
    anchors.centerIn: parent
    width: Style.space(680)
    height: Style.space(480)
    radius: Style.cornerRadius
    color: Color.menu.background || "#18181b"
    border.width: 1
    border.color: Util.alpha(Color.accent, 0.4)

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(20)
      spacing: Style.space(14)

      // Header Bar
      Row {
        width: parent.width
        spacing: Style.space(12)

        Text {
          text: "🧹"
          font.pixelSize: Style.space(24)
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          width: parent.width - Style.space(80)
          spacing: Style.space(2)

          Text {
            text: "Revo Deep Uninstaller — " + (leftoverModalRoot.appItem ? (leftoverModalRoot.appItem.name || leftoverModalRoot.appItem.pkg) : "")
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading ? Style.font.heading : 15
            font.weight: Font.Bold
            elide: Text.ElideRight
          }

          Text {
            text: {
              if (leftoverModalRoot.phase === 1) return "Step 1/3: Removing system package...";
              if (leftoverModalRoot.phase === 2) return "Step 2/3: Deep hunting for residual user configs and caches...";
              if (leftoverModalRoot.phase === 3) return "Step 3/3: Review residual files before permanent purge";
              return "Uninstallation Complete";
            }
            color: Util.alpha(Color.menu.text, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.space(11)
          }
        }
      }

      // Phase 1 & 2: Loading / Working State
      Item {
        visible: leftoverModalRoot.phase === 1 || leftoverModalRoot.phase === 2
        width: parent.width
        height: Style.space(280)

        Column {
          anchors.centerIn: parent
          spacing: Style.space(14)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "⚙️"
            font.pixelSize: Style.space(38)
            opacity: 0.85
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: leftoverModalRoot.statusMessage || "Working..."
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body ? Style.font.body : 13
          }
        }
      }

      // Phase 3: Leftovers Review List
      Item {
        visible: leftoverModalRoot.phase === 3
        width: parent.width
        height: Style.space(330)

        Column {
          anchors.fill: parent
          spacing: Style.space(10)

          // Subheader: Total Size Reclaimed + Select All / Deselect All
          Row {
            width: parent.width
            height: Style.space(28)

            // Reclaim badge
            Rectangle {
              height: parent.height
              width: reclaimText.implicitWidth + Style.space(16)
              radius: Style.space(4)
              color: Util.alpha("#22c55e", 0.2)
              border.width: 1
              border.color: Util.alpha("#22c55e", 0.4)

              Text {
                id: reclaimText
                anchors.centerIn: parent
                text: "Residual footprint: " + leftoverModalRoot.totalLeftoverFormatted
                color: "#86efac"
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                font.weight: Font.Bold
              }
            }

            Item { width: parent.width - x - actionsRow.width; height: 1 }

            Row {
              id: actionsRow
              spacing: Style.space(8)

              Text {
                text: "Select All"
                color: Color.accent
                font.pixelSize: Style.space(11)
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    for (var i = 0; i < leftoverModalRoot.leftoverItems.length; i++) {
                      leftoverModalRoot.leftoverItems[i].selected = true;
                    }
                    leftoverModalRoot.updateTotalSelected();
                  }
                }
              }

              Text { text: "•"; color: Util.alpha(Color.menu.text, 0.4); font.pixelSize: Style.space(11) }

              Text {
                text: "Deselect All"
                color: Util.alpha(Color.menu.text, 0.7)
                font.pixelSize: Style.space(11)
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    for (var i = 0; i < leftoverModalRoot.leftoverItems.length; i++) {
                      leftoverModalRoot.leftoverItems[i].selected = false;
                    }
                    leftoverModalRoot.updateTotalSelected();
                  }
                }
              }
            }
          }

          // Leftover List ScrollView
          Rectangle {
            width: parent.width
            height: Style.space(250)
            radius: Style.cornerRadius
            color: Util.alpha(Color.menu.selectedBackground, 0.1)
            border.width: 1
            border.color: Util.alpha(Color.menu.border, 0.3)
            clip: true

            ListView {
              id: leftoverList
              anchors.fill: parent
              anchors.margins: Style.space(6)
              model: leftoverModalRoot.leftoverItems
              spacing: Style.space(4)
              boundsBehavior: Flickable.StopAtBounds

              delegate: Rectangle {
                width: leftoverList.width
                height: Style.space(36)
                radius: Style.space(4)
                color: modelData.selected ? Util.alpha(Color.menu.selectedBackground, 0.25) : "transparent"

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(10)

                  // Checkbox
                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(16)
                    height: Style.space(16)
                    radius: Style.space(3)
                    color: modelData.selected ? Color.accent : "transparent"
                    border.width: 1
                    border.color: modelData.selected ? Color.accent : Util.alpha(Color.menu.text, 0.5)

                    Text {
                      anchors.centerIn: parent
                      text: "✓"
                      color: Color.menu.selectedText || "#000000"
                      font.pixelSize: Style.space(11)
                      font.weight: Font.Bold
                      visible: modelData.selected
                    }
                  }

                  // Category Badge
                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: Style.space(18)
                    width: tagLabel.implicitWidth + Style.space(8)
                    radius: Style.space(3)
                    color: Util.alpha(Color.menu.border, 0.3)

                    Text {
                      id: tagLabel
                      anchors.centerIn: parent
                      text: modelData.category ? modelData.category.toUpperCase() : "FILE"
                      color: Util.alpha(Color.menu.text, 0.8)
                      font.pixelSize: Style.space(9)
                      font.weight: Font.Bold
                    }
                  }

                  // Relative Path
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Style.space(150)
                    text: "~/" + modelData.relative
                    color: Color.menu.text
                    font.family: Style.font.family
                    font.pixelSize: Style.space(11)
                    elide: Text.ElideMiddle
                  }

                  // Size
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.sizeFormatted
                    color: Util.alpha(Color.menu.text, 0.7)
                    font.pixelSize: Style.space(11)
                    font.weight: Font.DemiBold
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    modelData.selected = !modelData.selected;
                    leftoverModalRoot.updateTotalSelected();
                  }
                }
              }
            }

            // Zero Leftovers empty message
            Item {
              anchors.fill: parent
              visible: leftoverModalRoot.leftoverItems.length === 0

              Column {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "✨"
                  font.pixelSize: Style.space(28)
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "No residual user configs or caches found. Clean system!"
                  color: Util.alpha(Color.menu.text, 0.6)
                  font.pixelSize: Style.space(12)
                }
              }
            }
          }

          // Safety Notice
          Text {
            width: parent.width
            text: "🛡️ A timestamped safety backup will be stored in ~/.local/share/omapp/backups/ prior to deletion."
            color: Util.alpha(Color.menu.text, 0.5)
            font.family: Style.font.family
            font.pixelSize: Style.space(10)
          }
        }
      }

      // Phase 4: Orphans & Done View
      Item {
        visible: leftoverModalRoot.phase === 4
        width: parent.width
        height: Style.space(330)

        Column {
          anchors.fill: parent
          spacing: Style.space(14)

          Row {
            spacing: Style.space(10)
            Text { text: "✅"; font.pixelSize: Style.space(24) }
            Column {
              Text {
                text: "Application and Residual Data Cleaned!"
                color: "#86efac"
                font.pixelSize: Style.space(14)
                font.weight: Font.Bold
              }
              Text {
                text: "Successfully removed and reclaimed disk space."
                color: Util.alpha(Color.menu.text, 0.6)
                font.pixelSize: Style.space(11)
              }
            }
          }

          // Orphan Detection Box
          Rectangle {
            visible: !!leftoverModalRoot.orphanListText && leftoverModalRoot.orphanListText !== "NO_ORPHANS"
            width: parent.width
            height: Style.space(160)
            radius: Style.cornerRadius
            color: Util.alpha("#f59e0b", 0.12)
            border.width: 1
            border.color: Util.alpha("#f59e0b", 0.4)

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(12)
              spacing: Style.space(8)

              Row {
                spacing: Style.space(6)
                Text { text: "📦"; font.pixelSize: Style.space(14) }
                Text {
                  text: "Unneeded Orphan Dependencies Detected"
                  color: "#fcd34d"
                  font.pixelSize: Style.space(12)
                  font.weight: Font.Bold
                }
              }

              Text {
                width: parent.width
                text: "Removing this package left orphan dependencies behind:\n" + leftoverModalRoot.orphanListText
                color: Util.alpha(Color.menu.text, 0.85)
                font.pixelSize: Style.space(11)
                wrapMode: Text.Wrap
              }

              Item { width: 1; height: 1 }

              Rectangle {
                height: Style.space(30)
                width: pruneText.implicitWidth + Style.space(20)
                radius: Style.space(4)
                color: "#f59e0b"

                Text {
                  id: pruneText
                  anchors.centerIn: parent
                  text: "Prune Orphan Packages"
                  color: "#000000"
                  font.pixelSize: Style.space(11)
                  font.weight: Font.Bold
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: leftoverModalRoot.pruneOrphansRequested()
                }
              }
            }
          }
        }
      }

      // Footer Action Buttons
      Row {
        anchors.right: parent.right
        spacing: Style.space(10)

        // Close / Cancel button
        Rectangle {
          height: Style.space(34)
          width: closeText.implicitWidth + Style.space(24)
          radius: Style.space(6)
          color: Util.alpha(Color.menu.selectedBackground, 0.2)
          border.width: 1
          border.color: Util.alpha(Color.menu.border, 0.3)

          Text {
            id: closeText
            anchors.centerIn: parent
            text: (leftoverModalRoot.phase === 4 || leftoverModalRoot.leftoverItems.length === 0) ? "Done" : "Skip Residuals"
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.space(12)
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: leftoverModalRoot.closed()
          }
        }

        // Permanently Purge Button (Phase 3)
        Rectangle {
          visible: leftoverModalRoot.phase === 3 && leftoverModalRoot.leftoverItems.length > 0
          height: Style.space(34)
          width: purgeBtnText.implicitWidth + Style.space(24)
          radius: Style.space(6)
          color: "#ef4444"

          Text {
            id: purgeBtnText
            anchors.centerIn: parent
            text: leftoverModalRoot.isPurging ? "Purging..." : "Permanently Purge Selected"
            color: "#ffffff"
            font.family: Style.font.family
            font.pixelSize: Style.space(12)
            font.weight: Font.Bold
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: !leftoverModalRoot.isPurging
            onClicked: {
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
