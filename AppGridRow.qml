import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

CursorSurface {
  id: rowRoot

  property bool isSelected: false
  property bool isChecked: false
  property bool isPinned: false
  property bool isProtected: false
  property bool isUnused: false
  property string appName: ""
  property string appPkg: ""
  property string appVersion: ""
  property string appIcon: "application-x-executable"
  property string appCategory: "desktop"
  property string appSize: ""
  property string appUserData: "0 B"
  property bool appRunning: false
  property var shell: null

  property int typeColWidth: Style.space(62)
  property int userDataColWidth: Style.space(66)
  property int verColWidth: Style.space(68)
  property int sizeColWidth: Style.space(68)

  signal clicked()
  signal toggleCheck()
  signal rightClicked(real x, real y)

  width: ListView.view ? ListView.view.width : Style.space(400)
  height: Style.space(42)
  foreground: Color.menu.text
  accent: Color.accent
  current: isSelected
  hasCursor: rowMouse.containsMouse

  function resolveIconSource(iconName) {
    if (!iconName || iconName.length === 0) return Quickshell.iconPath("application-x-executable", true);
    if (iconName.indexOf("/") === 0) return Util.fileUrl(iconName);
    if (iconName.indexOf("file://") === 0 || iconName.indexOf("image://") === 0) return iconName;
    var cleanName = iconName;
    if (cleanName.slice(-4) === ".png" || cleanName.slice(-4) === ".svg") cleanName = cleanName.slice(0, -4);
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
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(8)
    spacing: Style.space(6)

    // Checkbox (#13 Multi-select)
    Item {
      width: Style.space(20)
      height: parent.height

      BorderSurface {
        anchors.centerIn: parent
        width: Style.space(16)
        height: Style.space(16)
        radius: Style.cornerRadius
        color: rowRoot.isChecked ? Color.accent : "transparent"
        borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: rowRoot.isProtected ? "󰌾" : "✓"
          color: rowRoot.isProtected ? Color.muted : Color.menu.background
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          visible: rowRoot.isChecked || rowRoot.isProtected
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (!rowRoot.isProtected) rowRoot.toggleCheck();
        }
      }
    }

    // Column 1: Icon + Name + Badges (#30 Pin, #20 Protected, #15 Unused)
    Row {
      height: parent.height
      width: Math.max(
        Style.space(100),
        parent.width - (Style.space(20) + rowRoot.typeColWidth + rowRoot.userDataColWidth + rowRoot.verColWidth + rowRoot.sizeColWidth + Style.space(30))
      )
      spacing: Style.space(8)

      Item {
        width: Style.space(26)
        height: Style.space(26)
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
              if (rowRoot.appCategory === "flatpak" || rowRoot.appCategory === "appimage") return "󰏗";
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
          sourceSize.width: Style.space(26) * Screen.devicePixelRatio
          sourceSize.height: Style.space(26) * Screen.devicePixelRatio
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          source: rowRoot.resolveIconSource(rowRoot.appIcon)
          visible: status === Image.Ready
        }
      }

      Column {
        width: parent.width - Style.space(34)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Row {
          width: parent.width
          spacing: Style.space(5)

          Text {
            visible: rowRoot.isPinned
            textFormat: Text.PlainText
            text: "󰐃"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            textFormat: Text.PlainText
            width: Math.min(implicitWidth, parent.width - Style.space(32))
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
          text: rowRoot.appPkg + (rowRoot.isUnused ? " • Unused" : "")
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    // Column 2: Category / Type (#12 Flatpak/AppImage support)
    Item {
      width: rowRoot.typeColWidth
      height: parent.height

      BorderSurface {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        height: Style.space(19)
        width: catText.implicitWidth + Style.space(8)
        radius: Style.cornerRadius
        color: Style.normalFill
        borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

        Text {
          id: catText
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: {
            if (rowRoot.appCategory === "aur") return "AUR";
            if (rowRoot.appCategory === "flatpak") return "FLAT";
            if (rowRoot.appCategory === "appimage") return "AIMG";
            if (rowRoot.appCategory === "webapp") return "WEB";
            if (rowRoot.appCategory === "system") return "CLI";
            return "APP";
          }
          color: (rowRoot.appCategory === "aur" || rowRoot.appCategory === "flatpak") ? Color.accent : Color.menu.text
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    // Column 3: User Data Footprint (#11)
    Text {
      width: rowRoot.userDataColWidth
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: rowRoot.appUserData || "0 B"
      color: (rowRoot.appUserData && rowRoot.appUserData !== "0 B") ? Color.accent : Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
    }

    // Column 4: Version
    Text {
      width: rowRoot.verColWidth
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: rowRoot.appVersion || "-"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
    }

    // Column 5: Size
    Text {
      width: rowRoot.sizeColWidth
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
    anchors.leftMargin: Style.space(28)
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      rowRoot.clicked();
      if (mouse.button === Qt.RightButton) {
        var gp = rowRoot.mapToItem(null, mouse.x + Style.space(28), mouse.y);
        rowRoot.rightClicked(gp.x, gp.y);
      }
    }
  }
}
