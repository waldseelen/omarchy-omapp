import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: menuOverlay

  property bool isOpen: false
  property real popupX: 0
  property real popupY: 0
  property string menuTitle: ""
  property var actions: []

  signal actionTriggered(string actionId)

  anchors.fill: parent
  visible: isOpen
  z: 200

  function showAt(x, y, title, actionList) {
    menuOverlay.popupX = Math.max(Style.space(12), Math.min(x, width - Style.space(230)));
    menuOverlay.popupY = Math.max(Style.space(12), Math.min(y, height - Style.space(260)));
    menuOverlay.menuTitle = title || "";
    menuOverlay.actions = actionList || [];
    menuOverlay.isOpen = true;
  }

  function hide() {
    menuOverlay.isOpen = false;
  }

  MouseArea {
    anchors.fill: parent
    onClicked: menuOverlay.hide()
    onWheel: menuOverlay.hide()
  }

  BorderSurface {
    id: popupCard
    x: menuOverlay.popupX
    y: menuOverlay.popupY
    width: Style.space(220)
    height: menuCol.implicitHeight + Style.space(12)
    radius: Style.cornerRadius
    color: Color.menu.background
    borderSpec: Border.controlSpec("selected", Color.menu.text, Color.accent)

    Column {
      id: menuCol
      anchors.fill: parent
      anchors.margins: Style.space(6)
      spacing: Style.space(2)

      Text {
        visible: menuOverlay.menuTitle.length > 0
        width: parent.width - Style.space(8)
        x: Style.space(4)
        textFormat: Text.PlainText
        text: menuOverlay.menuTitle
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        elide: Text.ElideRight
      }

      PanelSeparator {
        visible: menuOverlay.menuTitle.length > 0
        foreground: Color.menu.text
      }

      Repeater {
        model: menuOverlay.actions

        CursorSurface {
          required property var modelData
          width: menuCol.width
          height: Style.space(28)
          foreground: modelData.danger ? Color.urgent : Color.menu.text
          accent: modelData.danger ? Color.urgent : Color.accent
          hasCursor: actMouse.containsMouse

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: modelData.icon || "•"
              color: modelData.danger ? Color.urgent : Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(24)
              textFormat: Text.PlainText
              text: modelData.label || ""
              color: modelData.danger ? Color.urgent : Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: actMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var id = modelData.id;
              menuOverlay.hide();
              menuOverlay.actionTriggered(id);
            }
          }
        }
      }
    }
  }
}
