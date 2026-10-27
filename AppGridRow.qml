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

  signal clicked()

  width: ListView.view ? ListView.view.width : Style.space(400)
  height: Style.space(52)
  radius: Style.cornerRadius
  color: isSelected
    ? Color.menu.selectedBackground
    : (rowMouse.containsMouse ? Util.alpha(Color.menu.selectedBackground, 0.25) : "transparent")

  // Icon
  Image {
    id: iconImg
    anchors.left: parent.left
    anchors.leftMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(32)
    height: Style.space(32)
    fillMode: Image.PreserveAspectFit
    source: {
      var icon = rowRoot.appIcon || "application-x-executable";
      if (icon.indexOf("/") === 0) return Util.fileUrl(icon);
      var p = Quickshell.iconPath(icon, true);
      return p ? p : Quickshell.iconPath("application-x-executable", true);
    }
  }

  // App Name & Package info
  Column {
    id: textCol
    anchors.left: iconImg.right
    anchors.leftMargin: Style.space(12)
    anchors.right: metaRow.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Row {
      spacing: Style.space(8)

      Text {
        text: rowRoot.appName || rowRoot.appPkg
        color: rowRoot.isSelected ? Color.menu.selectedText : Color.menu.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body ? Style.font.body : 13
        font.weight: Font.Medium
        elide: Text.ElideRight
      }

      // Running Dot Badge
      Rectangle {
        visible: rowRoot.appRunning
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(8)
        height: Style.space(8)
        radius: width / 2
        color: "#4ade80" // bright green
      }
    }

    Text {
      text: rowRoot.appPkg + (rowRoot.appVersion ? " • " + rowRoot.appVersion : "")
      color: rowRoot.isSelected ? Util.alpha(Color.menu.selectedText, 0.7) : Util.alpha(Color.menu.text, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption ? Style.font.caption : 11
      elide: Text.ElideRight
    }
  }

  // Meta Badges on Right (Category & Size)
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
          if (rowRoot.appCategory === "system") return "CLI / System";
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

  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: rowRoot.clicked()
  }
}
