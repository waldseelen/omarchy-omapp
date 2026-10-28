import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

BorderSurface {
  id: janitorRoot

  property var stats: ({
    orphans: "Checking...",
    pacman: "Checking...",
    yay: "Checking...",
    journal: "Checking...",
    dev: "Checking...",
    docker: "Checking...",
    symlinks: 0,
    pacnew: 0,
    browser: "Checking...",
    backups: []
  })
  property string cleaningCategory: ""
  property string statusMessage: ""
  property bool statusIsError: false
  property string confirmingCategory: ""
  property string confirmingBackup: ""

  signal cleanActionRequested(string category)
  signal scanOrphanDotfilesRequested()
  signal restoreBackupRequested(string archiveName)
  signal rescanRequested()
  signal backClicked()

  radius: Style.cornerRadius
  color: Style.normalFill
  borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)
  clip: true

  Flickable {
    id: jFlickable
    anchors.fill: parent
    anchors.margins: Style.space(18)
    contentHeight: jCol.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    flickDeceleration: 750
    maximumFlickVelocity: 6000
    pixelAligned: false

    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    WheelHandler {
      target: null
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function(event) {
        var dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y * 1.8 : (event.angleDelta.y / 120 * Style.space(60));
        if (dy !== 0) {
          var maxY = Math.max(0, jFlickable.contentHeight - jFlickable.height);
          jFlickable.contentY = Math.max(0, Math.min(maxY, jFlickable.contentY - dy));
          event.accepted = true;
        }
      }
    }

    Column {
      id: jCol
      width: parent.width
      spacing: Style.space(12)

      // Top Header Row
      Item {
        width: parent.width
        height: Style.space(38)

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)

          Text {
            textFormat: Text.PlainText
            text: "󰃢"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.display
          }

          Column {
            spacing: Style.space(1)
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
              text: "Reclaim disk space across packages, developer toolchains, logs, and browser caches"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Button {
            bordered: true
            iconText: "󰑐"
            text: "Rescan"
            foreground: Color.menu.text
            accent: Color.accent
            onClicked: janitorRoot.rescanRequested()
          }

          Button {
            bordered: true
            iconText: "󰍉"
            text: "Scan Orphaned Dotfiles"
            foreground: Color.accent
            accent: Color.accent
            onClicked: janitorRoot.scanOrphanDotfilesRequested()
          }

          Button {
            bordered: true
            iconText: "󰁍"
            text: "Back"
            foreground: Color.menu.text
            accent: Color.accent
            onClicked: janitorRoot.backClicked()
          }
        }
      }

      // Live Feedback / Status Banner
      BorderSurface {
        visible: janitorRoot.statusMessage.length > 0 || janitorRoot.cleaningCategory.length > 0
        width: parent.width
        height: Style.space(32)
        radius: Style.cornerRadius
        color: janitorRoot.statusIsError ? Util.alpha(Color.urgent, Style.normalFillAlpha) : Util.alpha(Color.accent, Style.normalFillAlpha)
        borderSpec: Border.controlSpec("normal", janitorRoot.statusIsError ? Color.urgent : Color.accent, Color.accent)

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(8)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: janitorRoot.cleaningCategory.length > 0 ? "󰒋 Working: " + janitorRoot.statusMessage : (janitorRoot.statusIsError ? "󰀦 " + janitorRoot.statusMessage : "󰄬 " + janitorRoot.statusMessage)
            color: janitorRoot.statusIsError ? Color.urgent : Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
        }
      }

      PanelSeparator { foreground: Color.menu.text }

      // 8-Card Bento Grid (#21–#25) with 2-Step Inline Confirmation
      Grid {
        width: parent.width
        columns: 4
        spacing: Style.space(10)

        Repeater {
          model: [
            { id: "orphans", icon: "󰏖", title: "Orphan Packages", val: janitorRoot.stats.orphans, desc: "Unneeded dependency packages", btn: "Prune Orphans" },
            { id: "pacman", icon: "󰋊", title: "Pacman Cache", val: janitorRoot.stats.pacman, desc: "/var/cache/pacman/pkg (keep 1)", btn: "Trim Cache" },
            { id: "yay", icon: "󰣇", title: "AUR Build Cache", val: janitorRoot.stats.yay, desc: "~/.cache/yay & paru artifacts", btn: "Purge AUR Cache" },
            { id: "journal", icon: "󰌱", title: "Systemd Journal", val: janitorRoot.stats.journal, desc: "/var/log/journal (>100M vacuum)", btn: "Vacuum Logs" },
            { id: "dev", icon: "󰅩", title: "Dev Caches", val: janitorRoot.stats.dev, desc: "npm, pip, cargo, go-build, gradle", btn: "Clean Dev Cache" },
            { id: "browser", icon: "󰖟", title: "Browser GPU/Cache", val: janitorRoot.stats.browser, desc: "Safe transient Cache (keeps logins)", btn: "Clean Cache" },
            { id: "docker", icon: "󰡨", title: "Docker Reclaimable", val: janitorRoot.stats.docker, desc: "Unused containers & build cache", btn: "Docker Prune" },
            { id: "symlinks", icon: "󰌺", title: "Broken Symlinks", val: (janitorRoot.stats.symlinks || 0) + " broken links", desc: "Dangling ~/.config symlinks", btn: "Clean Links" }
          ]

          BorderSurface {
            required property var modelData
            readonly property bool isConfirming: janitorRoot.confirmingCategory === modelData.id
            readonly property bool isCleaningThis: janitorRoot.cleaningCategory === modelData.id

            width: (parent.width - Style.space(30)) / 4
            height: Style.space(134)
            radius: Style.cornerRadius
            color: Style.hoverFill
            borderSpec: Border.controlSpec(isConfirming ? "selected" : "normal", Color.menu.text, Color.accent)

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(5)

              Row {
                spacing: Style.space(6)
                Text { textFormat: Text.PlainText; text: modelData.icon; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.body }
                Text { textFormat: Text.PlainText; text: modelData.title; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight }
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: String(modelData.val || "0 B")
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: modelData.desc
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }

              Button {
                visible: !parent.parent.isConfirming
                width: parent.width
                bordered: true
                selected: true
                text: parent.parent.isCleaningThis ? "Cleaning..." : modelData.btn
                fontSize: Style.font.caption
                horizontalPadding: Style.space(6)
                verticalPadding: Style.space(3)
                foreground: Color.menu.text
                accent: Color.accent
                onClicked: {
                  if (janitorRoot.cleaningCategory.length > 0) return;
                  janitorRoot.confirmingCategory = modelData.id;
                }
              }

              Row {
                visible: parent.parent.isConfirming
                width: parent.width
                spacing: Style.space(4)

                Button {
                  width: (parent.width - Style.space(4)) * 0.62
                  bordered: true
                  text: "Confirm Clean"
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(4)
                  verticalPadding: Style.space(3)
                  foreground: Color.urgent
                  accent: Color.urgent
                  background: Util.alpha(Color.urgent, Style.normalFillAlpha)
                  onClicked: {
                    janitorRoot.confirmingCategory = "";
                    janitorRoot.cleanActionRequested(modelData.id);
                  }
                }

                Button {
                  width: (parent.width - Style.space(4)) * 0.38
                  bordered: true
                  text: "Cancel"
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(4)
                  verticalPadding: Style.space(3)
                  foreground: Color.menu.text
                  accent: Color.accent
                  onClicked: janitorRoot.confirmingCategory = ""
                }
              }
            }
          }
        }
      }

      PanelSeparator { foreground: Color.menu.text }

      // Backup Manager & 1-Click Restore Section (#16)
      Text {
        textFormat: Text.PlainText
        text: "󰁯 Safety Backups (~/.local/share/omapp/backups)"
        color: Color.menu.text
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      BorderSurface {
        width: parent.width
        implicitHeight: Math.max(Style.space(58), backupCol.implicitHeight + Style.space(16))
        height: implicitHeight
        radius: Style.cornerRadius
        color: Style.hoverFill
        borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

        Column {
          id: backupCol
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(4)

          Text {
            visible: !janitorRoot.stats.backups || janitorRoot.stats.backups.length === 0
            textFormat: Text.PlainText
            text: "No safety backup archives found yet. Backups are created automatically before purging app leftovers."
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Repeater {
            model: janitorRoot.stats.backups || []

            Item {
              required property var modelData
              width: backupCol.width
              height: Style.space(28)

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: modelData.name + "  •  " + (modelData.sizeFormatted || modelData.size || "0 B") + "  •  " + modelData.date
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              Button {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                bordered: true
                iconText: "󰁯"
                text: janitorRoot.confirmingBackup === modelData.name ? "Click Again to Restore" : "Restore to $HOME"
                fontSize: Style.font.caption
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(2)
                foreground: janitorRoot.confirmingBackup === modelData.name ? Color.urgent : Color.accent
                accent: janitorRoot.confirmingBackup === modelData.name ? Color.urgent : Color.accent
                onClicked: {
                  if (janitorRoot.confirmingBackup === modelData.name) {
                    janitorRoot.confirmingBackup = "";
                    janitorRoot.restoreBackupRequested(modelData.name);
                  } else {
                    janitorRoot.confirmingBackup = modelData.name;
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
