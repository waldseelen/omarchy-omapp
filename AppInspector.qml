import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

BorderSurface {
  id: inspectorRoot

  property var appItem: null
  property bool isRunning: false
  property string runningPid: ""
  property var shell: null

  signal uninstallRequested(var app)
  signal killRequested(var app)
  signal launchRequested(var app)
  signal openConfigRequested(var app)
  signal openUrlRequested(string url)

  radius: Style.cornerRadius
  color: Style.normalFill
  borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)
  clip: true

  function resolveIconSource(iconName) {
    if (!iconName || iconName.length === 0) {
      return Quickshell.iconPath("application-x-executable", true);
    }
    if (iconName.indexOf("/") === 0) {
      return Util.fileUrl(iconName);
    }
    if (iconName.indexOf("file://") === 0 || iconName.indexOf("image://") === 0) {
      return iconName;
    }
    var cleanName = iconName;
    if (cleanName.slice(-4) === ".png" || cleanName.slice(-4) === ".svg") {
      cleanName = cleanName.slice(0, -4);
    }
    if (inspectorRoot.shell && inspectorRoot.shell.appLibrary && typeof inspectorRoot.shell.appLibrary.iconSource === "function") {
      var src = inspectorRoot.shell.appLibrary.iconSource(cleanName);
      if (src && src.length > 0) return src;
      var srcRaw = inspectorRoot.shell.appLibrary.iconSource(iconName);
      if (srcRaw && srcRaw.length > 0) return srcRaw;
    }
    var p = Quickshell.iconPath(cleanName, true);
    if (p && p.length > 0) return p;
    var p2 = Quickshell.iconPath(iconName, true);
    if (p2 && p2.length > 0) return p2;
    return Quickshell.iconPath("application-x-executable", true);
  }

  Item {
    anchors.fill: parent
    visible: !inspectorRoot.appItem

    Column {
      anchors.centerIn: parent
      spacing: Style.space(10)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: "󰏖"
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.display
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: "Select an application to inspect"
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }
  }

  Flickable {
    anchors.fill: parent
    anchors.margins: Style.space(16)
    visible: !!inspectorRoot.appItem
    contentHeight: contentCol.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    pixelAligned: true

    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: contentCol
      width: parent.width
      spacing: Style.space(14)

      // Header: App Icon + Titles
      Row {
        width: parent.width
        spacing: Style.space(12)

        Item {
          width: Style.space(48)
          height: Style.space(48)

          BorderSurface {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: Style.hoverFill
            visible: inspectorIconImg.status !== Image.Ready

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: {
                if (!inspectorRoot.appItem) return "󰏖";
                if (inspectorRoot.appItem.category === "aur") return "󰣇";
                if (inspectorRoot.appItem.category === "webapp") return "󰖟";
                if (inspectorRoot.appItem.category === "system") return "󰆍";
                return "󰏖";
              }
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.iconLarge
            }
          }

          Image {
            id: inspectorIconImg
            anchors.fill: parent
            sourceSize.width: Style.space(48) * Screen.devicePixelRatio
            sourceSize.height: Style.space(48) * Screen.devicePixelRatio
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            source: inspectorRoot.resolveIconSource(inspectorRoot.appItem ? inspectorRoot.appItem.icon : "")
            visible: status === Image.Ready
          }
        }

        Column {
          width: parent.width - Style.space(60)
          spacing: Style.space(3)

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: inspectorRoot.appItem ? (inspectorRoot.appItem.name || inspectorRoot.appItem.pkg) : ""
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: inspectorRoot.appItem ? (inspectorRoot.appItem.pkg + (inspectorRoot.appItem.version ? " • " + inspectorRoot.appItem.version : "")) : ""
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Row {
            spacing: Style.space(6)

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(6)
              height: Style.space(6)
              radius: width / 2
              color: inspectorRoot.isRunning ? Color.accent : Color.muted
            }

            Text {
              textFormat: Text.PlainText
              text: inspectorRoot.isRunning ? ("Running" + (inspectorRoot.runningPid ? " (PID " + inspectorRoot.runningPid + ")" : "")) : "Stopped"
              color: inspectorRoot.isRunning ? Color.accent : Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      // Action Buttons using native qs.Ui.Button
      Flow {
        width: parent.width
        spacing: Style.space(8)

        Button {
          bordered: true
          iconText: "󰩺"
          text: "Deep Uninstall"
          foreground: Color.urgent
          accent: Color.urgent
          background: Util.alpha(Color.urgent, Style.normalFillAlpha)
          onClicked: inspectorRoot.uninstallRequested(inspectorRoot.appItem)
        }

        Button {
          visible: inspectorRoot.isRunning
          bordered: true
          iconText: "󰅙"
          text: "Stop Process"
          foreground: Color.urgent
          accent: Color.urgent
          onClicked: inspectorRoot.killRequested(inspectorRoot.appItem)
        }

        Button {
          visible: inspectorRoot.appItem ? inspectorRoot.appItem.isDesktop : false
          bordered: true
          iconText: "󰐊"
          text: "Launch"
          foreground: Color.accent
          accent: Color.accent
          onClicked: inspectorRoot.launchRequested(inspectorRoot.appItem)
        }

        Button {
          bordered: true
          iconText: "󰉋"
          text: "Config"
          foreground: Color.menu.text
          accent: Color.accent
          onClicked: inspectorRoot.openConfigRequested(inspectorRoot.appItem)
        }
      }

      // Required By Dependency Warning Box
      BorderSurface {
        visible: !!(inspectorRoot.appItem && inspectorRoot.appItem.requiredBy && inspectorRoot.appItem.requiredBy !== "None")
        width: parent.width
        implicitHeight: reqCol.implicitHeight + Style.space(16)
        height: implicitHeight
        radius: Style.cornerRadius
        color: Util.alpha(Color.urgent, Style.normalFillAlpha)
        borderSpec: Border.controlSpec("normal", Color.urgent, Color.urgent)

        Column {
          id: reqCol
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(4)

          Text {
            textFormat: Text.PlainText
            text: "󰀦 Required by other packages"
            color: Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: inspectorRoot.appItem ? inspectorRoot.appItem.requiredBy : ""
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: !!(inspectorRoot.appItem && inspectorRoot.appItem.description)
        width: parent.width
        text: inspectorRoot.appItem ? inspectorRoot.appItem.description : ""
        color: Color.menu.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      PanelSeparator {
        foreground: Color.menu.text
      }

      // Metadata Table
      Column {
        width: parent.width
        spacing: Style.space(8)

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(110); text: "Installed Size"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(110); text: inspectorRoot.appItem ? inspectorRoot.appItem.sizeFormatted : "-"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
        }

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(110); text: "Install Date"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(110); text: inspectorRoot.appItem && inspectorRoot.appItem.installDate ? inspectorRoot.appItem.installDate : "Unknown"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
        }

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(110); text: "License"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(110); text: inspectorRoot.appItem && inspectorRoot.appItem.licenses ? inspectorRoot.appItem.licenses : "Custom"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
        }

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(110); text: "Packager"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(110); text: inspectorRoot.appItem && inspectorRoot.appItem.packager ? inspectorRoot.appItem.packager : "Local"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
        }

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(110); text: "Executable"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(110); text: inspectorRoot.appItem && inspectorRoot.appItem.exec ? inspectorRoot.appItem.exec : "-"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideMiddle }
        }
      }

      Button {
        visible: !!(inspectorRoot.appItem && inspectorRoot.appItem.url)
        width: parent.width
        leftAlign: true
        bordered: true
        iconText: "󰖟"
        text: inspectorRoot.appItem && inspectorRoot.appItem.url ? inspectorRoot.appItem.url : ""
        foreground: Color.accent
        accent: Color.accent
        fontSize: Style.font.caption
        onClicked: inspectorRoot.openUrlRequested(inspectorRoot.appItem.url)
      }
    }
  }
}
