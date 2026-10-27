import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: janitorRoot

  property string orphanCountText: "Checking..."
  property string pacmanCacheSize: "Checking..."
  property string aurCacheSize: "Checking..."
  property bool isBusy: false

  signal cleanOrphansRequested()
  signal cleanPacmanCacheRequested()
  signal cleanAurCacheRequested()
  signal backClicked()

  radius: Style.cornerRadius
  color: Util.alpha(Color.menu.selectedBackground, 0.12)
  border.width: 1
  border.color: Util.alpha(Color.menu.border, 0.3)

  Column {
    anchors.fill: parent
    anchors.margins: Style.space(24)
    spacing: Style.space(20)

    // Header
    Row {
      width: parent.width
      spacing: Style.space(12)

      Text { text: "🧹"; font.pixelSize: Style.space(26); anchors.verticalCenter: parent.verticalCenter }

      Column {
        spacing: Style.space(2)
        Text {
          text: "System Janitor & Storage Reclamation"
          color: Color.menu.text
          font.family: Style.font.family
          font.pixelSize: Style.font.heading ? Style.font.heading : 16
          font.weight: Font.Bold
        }
        Text {
          text: "Clean unneeded packages, build artifacts, and package caches with 1 click"
          color: Util.alpha(Color.menu.text, 0.6)
          font.family: Style.font.family
          font.pixelSize: Style.space(11)
        }
      }

      Item { width: parent.width - x - backBtn.width; height: 1 }

      Rectangle {
        id: backBtn
        height: Style.space(32)
        width: backText.implicitWidth + Style.space(20)
        radius: Style.space(6)
        color: Util.alpha(Color.menu.selectedBackground, 0.25)
        border.width: 1
        border.color: Util.alpha(Color.menu.border, 0.3)

        Text {
          id: backText
          anchors.centerIn: parent
          text: "← Back to Apps"
          color: Color.menu.text
          font.family: Style.font.family
          font.pixelSize: Style.space(11)
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: janitorRoot.backClicked()
        }
      }
    }

    // Grid of 3 Cleaner Cards
    Grid {
      width: parent.width
      columns: 3
      spacing: Style.space(16)

      // Card 1: Orphan Packages
      Rectangle {
        width: (parent.width - Style.space(32)) / 3
        height: Style.space(170)
        radius: Style.cornerRadius
        color: Util.alpha(Color.menu.selectedBackground, 0.18)
        border.width: 1
        border.color: Util.alpha(Color.menu.border, 0.35)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(16)
          spacing: Style.space(10)

          Row {
            spacing: Style.space(8)
            Text { text: "📦"; font.pixelSize: Style.space(18) }
            Text {
              text: "Orphan Dependencies"
              color: Color.menu.text
              font.weight: Font.Bold
              font.pixelSize: Style.space(12)
            }
          }

          Text {
            text: janitorRoot.orphanCountText
            color: Color.accent
            font.pixelSize: Style.space(14)
            font.weight: Font.DemiBold
          }

          Text {
            text: "Packages installed as dependencies that are no longer needed by any app."
            color: Util.alpha(Color.menu.text, 0.6)
            font.pixelSize: Style.space(10)
            wrapMode: Text.Wrap
            width: parent.width
          }

          Item { width: 1; height: 1 }

          Rectangle {
            height: Style.space(30)
            width: parent.width
            radius: Style.space(4)
            color: Color.accent

            Text {
              anchors.centerIn: parent
              text: "Prune Orphans"
              color: Color.menu.selectedText || "#000000"
              font.pixelSize: Style.space(11)
              font.weight: Font.Bold
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: janitorRoot.cleanOrphansRequested()
            }
          }
        }
      }

      // Card 2: Pacman Package Cache
      Rectangle {
        width: (parent.width - Style.space(32)) / 3
        height: Style.space(170)
        radius: Style.cornerRadius
        color: Util.alpha(Color.menu.selectedBackground, 0.18)
        border.width: 1
        border.color: Util.alpha(Color.menu.border, 0.35)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(16)
          spacing: Style.space(10)

          Row {
            spacing: Style.space(8)
            Text { text: "💾"; font.pixelSize: Style.space(18) }
            Text {
              text: "Pacman Cache"
              color: Color.menu.text
              font.weight: Font.Bold
              font.pixelSize: Style.space(12)
            }
          }

          Text {
            text: janitorRoot.pacmanCacheSize
            color: Color.accent
            font.pixelSize: Style.space(14)
            font.weight: Font.DemiBold
          }

          Text {
            text: "Downloaded .pkg.tar.zst archives stored in /var/cache/pacman/pkg."
            color: Util.alpha(Color.menu.text, 0.6)
            font.pixelSize: Style.space(10)
            wrapMode: Text.Wrap
            width: parent.width
          }

          Item { width: 1; height: 1 }

          Rectangle {
            height: Style.space(30)
            width: parent.width
            radius: Style.space(4)
            color: Color.accent

            Text {
              anchors.centerIn: parent
              text: "Trim Cache (paccache -r)"
              color: Color.menu.selectedText || "#000000"
              font.pixelSize: Style.space(11)
              font.weight: Font.Bold
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: janitorRoot.cleanPacmanCacheRequested()
            }
          }
        }
      }

      // Card 3: AUR Build Cache
      Rectangle {
        width: (parent.width - Style.space(32)) / 3
        height: Style.space(170)
        radius: Style.cornerRadius
        color: Util.alpha(Color.menu.selectedBackground, 0.18)
        border.width: 1
        border.color: Util.alpha(Color.menu.border, 0.35)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(16)
          spacing: Style.space(10)

          Row {
            spacing: Style.space(8)
            Text { text: "⚡"; font.pixelSize: Style.space(18) }
            Text {
              text: "AUR Yay Cache"
              color: Color.menu.text
              font.weight: Font.Bold
              font.pixelSize: Style.space(12)
            }
          }

          Text {
            text: janitorRoot.aurCacheSize
            color: Color.accent
            font.pixelSize: Style.space(14)
            font.weight: Font.DemiBold
          }

          Text {
            text: "Temporary git checkouts and build files stored in ~/.cache/yay."
            color: Util.alpha(Color.menu.text, 0.6)
            font.pixelSize: Style.space(10)
            wrapMode: Text.Wrap
            width: parent.width
          }

          Item { width: 1; height: 1 }

          Rectangle {
            height: Style.space(30)
            width: parent.width
            radius: Style.space(4)
            color: Color.accent

            Text {
              anchors.centerIn: parent
              text: "Purge Yay Cache"
              color: Color.menu.selectedText || "#000000"
              font.pixelSize: Style.space(11)
              font.weight: Font.Bold
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: janitorRoot.cleanAurCacheRequested()
            }
          }
        }
      }
    }
  }
}
