import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

CursorSurface {
  id: rowRoot

  property bool isSelected: false
  property string appName: ""
  property string appPkg: ""
  property string appVersion: ""
  property string appIcon: "application-x-executable"
  property string appCategory: "desktop"
  property string appSize: ""
  property bool appRunning: false
  property var shell: null

  signal clicked()

  width: ListView.view ? ListView.view.width : Style.space(400)
  height: Style.space(44)
  foreground: Color.menu.text
  accent: Color.accent
  current: isSelected
  hasCursor: rowMouse.containsMouse

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
    if (rowRoot.shell && rowRoot.shell.appLibrary && typeof rowRoot.shell.appLibrary.iconSource === "function") {
      var src = rowRoot.shell.appLibrary.iconSource(cleanName);
      if (src && src.length > 0) return src;
      var srcRaw = rowRoot.shell.appLibrary.iconSource(iconName);
      if (srcRaw && srcRaw.length > 0) return srcRaw;
    }
    var p = Quickshell.iconPath(cleanName, true);
    if (p && p.length > 0) return p;
    var p2 = Quickshell.iconPath(iconName, true);
    if (p2 && p2.length > 0) return p2;
    return Quickshell.iconPath("application-x-executable", true);
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    spacing: Style.space(6)

    // Column 1: Application Icon + Name + Package Name (Flexible width matching header)
    Row {
      height: parent.height
      width: Math.max(Style.space(120), parent.width - Style.space(236))
      spacing: Style.space(10)

      Item {
        width: Style.space(28)
        height: Style.space(28)
        anchors.verticalCenter: parent.verticalCenter

        BorderSurface {
          anchors.fill: parent
          radius: Style.cornerRadius
          color: Style.normalFill
          visible: iconImg.status !== Image.Ready

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: {
              if (rowRoot.appCategory === "aur") return "󰣇";
              if (rowRoot.appCategory === "webapp") return "󰖟";
              if (rowRoot.appCategory === "system") return "󰆍";
              return "󰏖";
            }
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.icon
          }
        }

        Image {
          id: iconImg
          anchors.fill: parent
          sourceSize.width: Style.space(28) * Screen.devicePixelRatio
          sourceSize.height: Style.space(28) * Screen.devicePixelRatio
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          source: rowRoot.resolveIconSource(rowRoot.appIcon)
          visible: status === Image.Ready
        }
      }

      Column {
        width: parent.width - Style.space(38)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Row {
          width: parent.width
          spacing: Style.space(6)

          Text {
            textFormat: Text.PlainText
            width: Math.min(implicitWidth, parent.width - (rowRoot.appRunning ? Style.space(14) : 0))
            text: rowRoot.appName || rowRoot.appPkg
            color: rowRoot.isSelected ? Color.accent : Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: rowRoot.isSelected
            elide: Text.ElideRight
          }

          Rectangle {
            visible: rowRoot.appRunning
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(6)
            height: Style.space(6)
            radius: width / 2
            color: Color.accent
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: rowRoot.appPkg
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    // Column 2: Category / Type
    Item {
      width: Style.space(72)
      height: parent.height

      BorderSurface {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        height: Style.space(20)
        width: catText.implicitWidth + Style.space(10)
        radius: Style.cornerRadius
        color: Style.normalFill
        borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

        Text {
          id: catText
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: {
            if (rowRoot.appCategory === "aur") return "AUR";
            if (rowRoot.appCategory === "webapp") return "WEB";
            if (rowRoot.appCategory === "system") return "CLI";
            return "APP";
          }
          color: rowRoot.appCategory === "aur" ? Color.accent : Color.menu.text
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    // Column 3: Version
    Text {
      width: Style.space(76)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: rowRoot.appVersion || "-"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
    }

    // Column 4: Size
    Text {
      width: Style.space(70)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: rowRoot.appSize
      color: rowRoot.isSelected ? Color.accent : Color.menu.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: rowRoot.isSelected
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideLeft
    }
  }

  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: rowRoot.clicked()
  }
}
