import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Rectangle {
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
  height: Style.space(52)
  radius: Style.cornerRadius
  color: isSelected
    ? Util.alpha(Color.accent, 0.18)
    : (rowMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.25) : "transparent")
  border.width: isSelected ? 1 : 0
  border.color: isSelected ? Util.alpha(Color.accent, 0.45) : "transparent"

  // Function to resolve icon with multi-level fallbacks
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

  // App Icon Box with Fallback Glyph
  Item {
    id: iconBox
    anchors.left: parent.left
    anchors.leftMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(32)
    height: Style.space(32)

    // Fallback Glyph Container
    Rectangle {
      anchors.fill: parent
      radius: Style.space(6)
      color: Util.alpha(Color.menu.selectedBackground, 0.3)
      visible: iconImg.status !== Image.Ready

      Text {
        anchors.centerIn: parent
        text: {
          if (rowRoot.appCategory === "aur") return "⚡";
          if (rowRoot.appCategory === "webapp") return "🌐";
          if (rowRoot.appCategory === "system") return "⚙️";
          return "📦";
        }
        font.pixelSize: Style.space(14)
      }
    }

    // App Icon
    Image {
      id: iconImg
      anchors.fill: parent
      sourceSize.width: Style.space(32) * Screen.devicePixelRatio
      sourceSize.height: Style.space(32) * Screen.devicePixelRatio
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      source: rowRoot.resolveIconSource(rowRoot.appIcon)
      visible: status === Image.Ready
    }
  }

  // Right Meta Badges (Category & Size) - Right-anchored first to reserve width
  Row {
    id: metaRow
    anchors.right: parent.right
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(8)

    // Category Badge
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      height: Style.space(20)
      width: catText.implicitWidth + Style.space(12)
      radius: Style.space(4)
      color: {
        if (rowRoot.appCategory === "aur") return Util.alpha("#a855f7", 0.25);
        if (rowRoot.appCategory === "webapp") return Util.alpha("#06b6d4", 0.25);
        if (rowRoot.appCategory === "system") return Util.alpha(Color.menu.border, 0.3);
        return Util.alpha(Color.accent, 0.25);
      }

      Text {
        id: catText
        anchors.centerIn: parent
        text: {
          if (rowRoot.appCategory === "aur") return "AUR";
          if (rowRoot.appCategory === "webapp") return "Web App";
          if (rowRoot.appCategory === "system") return "CLI";
          return "Desktop";
        }
        color: {
          if (rowRoot.appCategory === "aur") return "#d8b4fe";
          if (rowRoot.appCategory === "webapp") return "#67e8f9";
          if (rowRoot.appCategory === "system") return Util.alpha(Color.menu.text, 0.7);
          return Color.accent;
        }
        font.family: Style.font.family
        font.pixelSize: Style.space(10)
        font.weight: Font.Bold
      }
    }

    // Size Label
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: rowRoot.appSize
      color: rowRoot.isSelected ? Color.menu.selectedText : Util.alpha(Color.menu.text, 0.75)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption ? Style.font.caption : 11
      font.weight: Font.DemiBold
    }
  }

  // App Name & Package info (Strictly bounded between iconBox and metaRow)
  Column {
    id: textCol
    anchors.left: iconBox.right
    anchors.leftMargin: Style.space(12)
    anchors.right: metaRow.left
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)
    clip: true

    // Top Title Row: Name + Running Indicator
    Item {
      width: textCol.width
      height: Math.max(nameText.implicitHeight, runningDot.height)

      Text {
        id: nameText
        anchors.left: parent.left
        anchors.right: rowRoot.appRunning ? runningDot.left : parent.right
        anchors.rightMargin: rowRoot.appRunning ? Style.space(6) : 0
        anchors.verticalCenter: parent.verticalCenter
        text: rowRoot.appName || rowRoot.appPkg
        color: rowRoot.isSelected ? Color.menu.selectedText : Color.menu.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body ? Style.font.body : 13
        font.weight: Font.Medium
        elide: Text.ElideRight
      }

      // Running Dot Badge
      Rectangle {
        id: runningDot
        visible: rowRoot.appRunning
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(7)
        height: Style.space(7)
        radius: width / 2
        color: "#4ade80"
      }
    }

    // Subtitle: Package Name + Version
    Text {
      width: textCol.width
      text: rowRoot.appPkg + (rowRoot.appVersion ? " • " + rowRoot.appVersion : "")
      color: rowRoot.isSelected ? Util.alpha(Color.menu.selectedText, 0.7) : Util.alpha(Color.menu.text, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption ? Style.font.caption : 11
      elide: Text.ElideRight
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
