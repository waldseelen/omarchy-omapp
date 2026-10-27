import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Rectangle {
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
  color: Util.alpha(Color.menu.selectedBackground, 0.12)
  border.width: 1
  border.color: Util.alpha(Color.menu.border, 0.3)
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

  // Empty State
  Item {
    anchors.fill: parent
    visible: !inspectorRoot.appItem

    Column {
      anchors.centerIn: parent
      spacing: Style.space(12)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "📦"
        font.pixelSize: Style.space(36)
        opacity: 0.6
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Select an application to inspect"
        color: Util.alpha(Color.menu.text, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.body ? Style.font.body : 13
      }
    }
  }

  // Active Inspector Content
  Flickable {
    anchors.fill: parent
    anchors.margins: Style.space(14)
    visible: !!inspectorRoot.appItem
    contentHeight: contentCol.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: contentCol
      width: parent.width
      spacing: Style.space(12)

      // Header: App Icon + Titles
      Row {
        width: parent.width
        spacing: Style.space(12)

        Item {
          width: Style.space(48)
          height: Style.space(48)

          Rectangle {
            anchors.fill: parent
            radius: Style.space(8)
            color: Util.alpha(Color.menu.selectedBackground, 0.3)
            visible: inspectorIconImg.status !== Image.Ready

            Text {
              anchors.centerIn: parent
              text: {
                if (!inspectorRoot.appItem) return "📦";
                if (inspectorRoot.appItem.category === "aur") return "⚡";
                if (inspectorRoot.appItem.category === "webapp") return "🌐";
                if (inspectorRoot.appItem.category === "system") return "⚙️";
                return "📦";
              }
              font.pixelSize: Style.space(22)
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
          clip: true

          Text {
            width: parent.width
            text: inspectorRoot.appItem ? (inspectorRoot.appItem.name || inspectorRoot.appItem.pkg) : ""
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading ? Style.font.heading : 15
            font.weight: Font.Bold
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            text: inspectorRoot.appItem ? (inspectorRoot.appItem.pkg + " " + inspectorRoot.appItem.version) : ""
            color: Util.alpha(Color.menu.text, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption ? Style.font.caption : 11
            elide: Text.ElideRight
          }

          // Process status badge
          Row {
            spacing: Style.space(6)

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(7)
              height: Style.space(7)
              radius: width / 2
              color: inspectorRoot.isRunning ? "#4ade80" : Util.alpha(Color.menu.text, 0.3)
            }

            Text {
              text: inspectorRoot.isRunning ? ("Running" + (inspectorRoot.runningPid ? " (PID " + inspectorRoot.runningPid + ")" : "")) : "Stopped"
              color: inspectorRoot.isRunning ? "#86efac" : Util.alpha(Color.menu.text, 0.5)
              font.family: Style.font.family
              font.pixelSize: Style.space(10)
            }
          }
        }
      }

      // Action Buttons Flow (Automatically wraps onto next line without clipping!)
      Flow {
        width: parent.width
        spacing: Style.space(8)

        // Deep Uninstall Button (Primary Action)
        Rectangle {
          height: Style.space(30)
          width: unText.implicitWidth + Style.space(20)
          radius: Style.space(6)
          color: Util.alpha("#ef4444", 0.25)
          border.width: 1
          border.color: unMouse.containsMouse ? "#ef4444" : Util.alpha("#ef4444", 0.5)

          Row {
            anchors.centerIn: parent
            spacing: Style.space(5)

            Text { text: "🗑️"; font.pixelSize: Style.space(11) }
            Text {
              id: unText
              text: "Deep Uninstall"
              color: "#fca5a5"
              font.family: Style.font.family
              font.pixelSize: Style.space(11)
              font.weight: Font.Bold
            }
          }

          MouseArea {
            id: unMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: inspectorRoot.uninstallRequested(inspectorRoot.appItem)
          }
        }

        // Kill Process Button (Visible when running)
        Rectangle {
          visible: inspectorRoot.isRunning
          height: Style.space(30)
          width: killText.implicitWidth + Style.space(18)
          radius: Style.space(6)
          color: Util.alpha("#f97316", 0.2)
          border.width: 1
          border.color: Util.alpha("#f97316", 0.4)

          Row {
            anchors.centerIn: parent
            spacing: Style.space(5)

            Text { text: "⚡"; font.pixelSize: Style.space(11) }
            Text {
              id: killText
              text: "Kill Process"
              color: "#fdba74"
              font.family: Style.font.family
              font.pixelSize: Style.space(11)
              font.weight: Font.DemiBold
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: inspectorRoot.killRequested(inspectorRoot.appItem)
          }
        }

        // Launch App Button
        Rectangle {
          visible: inspectorRoot.appItem ? inspectorRoot.appItem.isDesktop : false
          height: Style.space(30)
          width: launchText.implicitWidth + Style.space(18)
          radius: Style.space(6)
          color: Util.alpha(Color.accent, 0.2)
          border.width: 1
          border.color: Util.alpha(Color.accent, 0.4)

          Row {
            anchors.centerIn: parent
            spacing: Style.space(5)

            Text { text: "🚀"; font.pixelSize: Style.space(11) }
            Text {
              id: launchText
              text: "Launch"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.space(11)
              font.weight: Font.DemiBold
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: inspectorRoot.launchRequested(inspectorRoot.appItem)
          }
        }

        // Open Config Folder Button
        Rectangle {
          height: Style.space(30)
          width: cfgText.implicitWidth + Style.space(16)
          radius: Style.space(6)
          color: Util.alpha(Color.menu.selectedBackground, 0.2)
          border.width: 1
          border.color: Util.alpha(Color.menu.border, 0.3)

          Row {
            anchors.centerIn: parent
            spacing: Style.space(5)

            Text { text: "📁"; font.pixelSize: Style.space(11) }
            Text {
              id: cfgText
              text: "Config"
              color: Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.space(11)
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: inspectorRoot.openConfigRequested(inspectorRoot.appItem)
          }
        }
      }

      // Required By Dependency Warning Badge
      Rectangle {
        visible: inspectorRoot.appItem && inspectorRoot.appItem.requiredBy && inspectorRoot.appItem.requiredBy !== "None"
        width: parent.width
        height: reqCol.implicitHeight + Style.space(14)
        radius: Style.space(6)
        color: Util.alpha("#f59e0b", 0.15)
        border.width: 1
        border.color: Util.alpha("#f59e0b", 0.4)

        Column {
          id: reqCol
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(3)

          Row {
            spacing: Style.space(6)
            Text { text: "⚠️"; font.pixelSize: Style.space(11) }
            Text {
              text: "Other packages depend on this!"
              color: "#fcd34d"
              font.family: Style.font.family
              font.pixelSize: Style.space(11)
              font.weight: Font.Bold
            }
          }

          Text {
            width: parent.width
            text: "Required By: " + (inspectorRoot.appItem ? inspectorRoot.appItem.requiredBy : "")
            color: Util.alpha("#fcd34d", 0.85)
            font.family: Style.font.family
            font.pixelSize: Style.space(10)
            wrapMode: Text.Wrap
          }
        }
      }

      // App Description
      Text {
        width: parent.width
        text: inspectorRoot.appItem ? inspectorRoot.appItem.description : ""
        color: Util.alpha(Color.menu.text, 0.75)
        font.family: Style.font.family
        font.pixelSize: Style.space(11)
        wrapMode: Text.Wrap
      }

      // Divider
      Rectangle {
        width: parent.width
        height: 1
        color: Util.alpha(Color.menu.border, 0.25)
      }

      // Metadata Table (Strictly bounded 2-column layout)
      Column {
        width: parent.width
        spacing: Style.space(6)

        Row {
          width: parent.width
          Text { width: Style.space(90); text: "Size:"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(11) }
          Text {
            width: parent.width - Style.space(90)
            text: inspectorRoot.appItem ? inspectorRoot.appItem.sizeFormatted : "-"
            color: Color.menu.text
            font.pixelSize: Style.space(11)
            font.weight: Font.DemiBold
          }
        }

        Row {
          width: parent.width
          Text { width: Style.space(90); text: "Install Date:"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(11) }
          Text {
            width: parent.width - Style.space(90)
            text: inspectorRoot.appItem && inspectorRoot.appItem.installDate ? inspectorRoot.appItem.installDate : "Unknown"
            color: Color.menu.text
            font.pixelSize: Style.space(11)
            elide: Text.ElideRight
          }
        }

        Row {
          width: parent.width
          Text { width: Style.space(90); text: "License:"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(11) }
          Text {
            width: parent.width - Style.space(90)
            text: inspectorRoot.appItem && inspectorRoot.appItem.licenses ? inspectorRoot.appItem.licenses : "Custom"
            color: Color.menu.text
            font.pixelSize: Style.space(11)
            elide: Text.ElideRight
          }
        }

        Row {
          width: parent.width
          Text { width: Style.space(90); text: "Packager:"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(11) }
          Text {
            width: parent.width - Style.space(90)
            text: inspectorRoot.appItem && inspectorRoot.appItem.packager ? inspectorRoot.appItem.packager : "Local"
            color: Color.menu.text
            font.pixelSize: Style.space(11)
            elide: Text.ElideRight
          }
        }

        Row {
          width: parent.width
          Text { width: Style.space(90); text: "Binary:"; color: Util.alpha(Color.menu.text, 0.5); font.pixelSize: Style.space(11) }
          Text {
            width: parent.width - Style.space(90)
            text: inspectorRoot.appItem && inspectorRoot.appItem.exec ? inspectorRoot.appItem.exec : "-"
            color: Color.menu.text
            font.pixelSize: Style.space(11)
            elide: Text.ElideMiddle
          }
        }
      }

      // Website Link
      Rectangle {
        visible: inspectorRoot.appItem && !!inspectorRoot.appItem.url
        height: Style.space(24)
        width: parent.width
        radius: Style.space(4)
        color: urlMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.3) : "transparent"

        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          Text { text: "🌐"; font.pixelSize: Style.space(11) }
          Text {
            width: contentCol.width - Style.space(24)
            text: inspectorRoot.appItem ? inspectorRoot.appItem.url : ""
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.space(11)
            elide: Text.ElideRight
          }
        }

        MouseArea {
          id: urlMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true
          onClicked: inspectorRoot.openUrlRequested(inspectorRoot.appItem.url)
        }
      }
    }
  }
}
