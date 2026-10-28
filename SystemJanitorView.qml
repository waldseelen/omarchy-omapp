import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
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
  color: Style.normalFill
  borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

  Column {
    anchors.fill: parent
    anchors.margins: Style.space(20)
    spacing: Style.space(18)

    Item {
      width: parent.width
      height: Style.space(40)

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
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
          spacing: Style.space(2)
          Text {
            textFormat: Text.PlainText
            text: "System Janitor & Storage Reclamation"
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
          }
          Text {
            textFormat: Text.PlainText
            text: "Clean unneeded dependencies, package archives, and AUR build caches"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }
      }

      Button {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        bordered: true
        iconText: "󰁍"
        text: "Back to Apps"
        foreground: Color.menu.text
        accent: Color.accent
        onClicked: janitorRoot.backClicked()
      }
    }

    PanelSeparator {
      foreground: Color.menu.text
    }

    Grid {
      width: parent.width
      columns: 3
      spacing: Style.space(16)

      // Card 1: Orphan Packages
      BorderSurface {
        width: (parent.width - Style.space(32)) / 3
        height: Style.space(180)
        radius: Style.cornerRadius
        color: Style.hoverFill
        borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(16)
          spacing: Style.space(10)

          Row {
            spacing: Style.space(8)
            Text { textFormat: Text.PlainText; text: "󰏖"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            Text {
              textFormat: Text.PlainText
              text: "Orphan Dependencies"
              color: Color.menu.text
              font.family: Style.font.family
              font.bold: true
              font.pixelSize: Style.font.subtitle
            }
          }

          Text {
            textFormat: Text.PlainText
            text: janitorRoot.orphanCountText
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            text: "Packages installed as dependencies that are no longer required by any application."
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }

          Item { width: 1; height: Style.space(4) }

          Button {
            width: parent.width
            bordered: true
            selected: true
            iconText: "󰩺"
            text: "Prune Orphans"
            foreground: Color.menu.text
            accent: Color.accent
            onClicked: janitorRoot.cleanOrphansRequested()
          }
        }
      }

      // Card 2: Pacman Package Cache
      BorderSurface {
        width: (parent.width - Style.space(32)) / 3
        height: Style.space(180)
        radius: Style.cornerRadius
        color: Style.hoverFill
        borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(16)
          spacing: Style.space(10)

          Row {
            spacing: Style.space(8)
            Text { textFormat: Text.PlainText; text: "󰋊"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            Text {
              textFormat: Text.PlainText
              text: "Pacman Cache"
              color: Color.menu.text
              font.family: Style.font.family
              font.bold: true
              font.pixelSize: Style.font.subtitle
            }
          }

          Text {
            textFormat: Text.PlainText
            text: janitorRoot.pacmanCacheSize
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            text: "Downloaded .pkg.tar.zst archives stored in /var/cache/pacman/pkg."
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }

          Item { width: 1; height: Style.space(4) }

          Button {
            width: parent.width
            bordered: true
            selected: true
            iconText: "󰃢"
            text: "Trim Cache (paccache -r)"
            foreground: Color.menu.text
            accent: Color.accent
            onClicked: janitorRoot.cleanPacmanCacheRequested()
          }
        }
      }

      // Card 3: AUR Build Cache
      BorderSurface {
        width: (parent.width - Style.space(32)) / 3
        height: Style.space(180)
        radius: Style.cornerRadius
        color: Style.hoverFill
        borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(16)
          spacing: Style.space(10)

          Row {
            spacing: Style.space(8)
            Text { textFormat: Text.PlainText; text: "󰣇"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            Text {
              textFormat: Text.PlainText
              text: "AUR Yay Cache"
              color: Color.menu.text
              font.family: Style.font.family
              font.bold: true
              font.pixelSize: Style.font.subtitle
            }
          }

          Text {
            textFormat: Text.PlainText
            text: janitorRoot.aurCacheSize
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            text: "Temporary git checkouts and build artifacts stored in ~/.cache/yay."
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }

          Item { width: 1; height: Style.space(4) }

          Button {
            width: parent.width
            bordered: true
            selected: true
            iconText: "󰃢"
            text: "Purge Yay Cache"
            foreground: Color.menu.text
            accent: Color.accent
            onClicked: janitorRoot.cleanAurCacheRequested()
          }
        }
      }
    }
  }
}
