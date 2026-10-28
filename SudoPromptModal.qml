import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: sudoModalRoot

  property bool isOpen: false
  property string errorMessage: ""
  property bool isChecking: false

  signal submitted(string password)
  signal cancelled()

  anchors.fill: parent
  color: Color.menu.scrim
  visible: isOpen
  z: 100

  onIsOpenChanged: {
    if (isOpen) {
      pwdInput.text = "";
      Qt.callLater(function() { pwdInput.forceActiveFocus(); });
    }
  }

  Keys.onEscapePressed: function(event) {
    event.accepted = true;
    sudoModalRoot.cancelled();
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {}
  }

  BorderSurface {
    id: dialogBox
    anchors.centerIn: parent
    width: Style.space(420)
    height: Style.space(240)
    radius: Style.cornerRadius
    color: Color.menu.background
    borderSpec: Border.controlSpec("selected", Color.menu.text, Color.accent)

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(22)
      spacing: Style.space(14)

      Row {
        spacing: Style.space(10)
        Text {
          textFormat: Text.PlainText
          text: "󰌾"
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.display
          anchors.verticalCenter: parent.verticalCenter
        }
        Column {
          spacing: Style.space(2)
          Text {
            textFormat: Text.PlainText
            text: "Administrator Authentication"
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
          }
          Text {
            textFormat: Text.PlainText
            text: "Unlock OMAPP root operations for this session"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }
      }

      TextField {
        id: pwdInput
        width: parent.width
        password: true
        foreground: Color.menu.text
        accent: Color.accent
        placeholderText: "Enter sudo password..."
        onAccepted: {
          if (pwdInput.text.length > 0 && !sudoModalRoot.isChecking) {
            sudoModalRoot.submitted(pwdInput.text);
          }
        }
      }

      Text {
        visible: !!sudoModalRoot.errorMessage
        textFormat: Text.PlainText
        width: parent.width
        text: sudoModalRoot.errorMessage
        color: Color.urgent
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        wrapMode: Text.Wrap
      }

      Row {
        anchors.right: parent.right
        spacing: Style.space(10)

        Button {
          bordered: true
          text: "Cancel"
          foreground: Color.menu.text
          accent: Color.accent
          onClicked: sudoModalRoot.cancelled()
        }

        Button {
          bordered: true
          selected: true
          iconText: "󰌿"
          text: sudoModalRoot.isChecking ? "Verifying..." : "Unlock Session"
          foreground: Color.menu.text
          accent: Color.accent
          onClicked: {
            if (pwdInput.text.length > 0 && !sudoModalRoot.isChecking) {
              sudoModalRoot.submitted(pwdInput.text);
            }
          }
        }
      }
    }
  }

  function initFocus() {
    pwdInput.text = "";
    Qt.callLater(function() { pwdInput.forceActiveFocus(); });
  }
}
