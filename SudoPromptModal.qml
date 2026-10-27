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
  color: Util.alpha("#000000", 0.65)
  visible: isOpen
  z: 100

  // Intercept all clicks outside the dialog
  MouseArea {
    anchors.fill: parent
    onClicked: {}
  }

  Rectangle {
    id: dialogBox
    anchors.centerIn: parent
    width: Style.space(420)
    height: Style.space(260)
    radius: Style.cornerRadius
    color: Color.menu.background || "#18181b"
    border.width: 1
    border.color: Util.alpha(Color.accent, 0.4)

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(24)
      spacing: Style.space(14)

      // Header icon + title
      Row {
        spacing: Style.space(10)
        Text {
          text: "🔒"
          font.pixelSize: Style.space(22)
          anchors.verticalCenter: parent.verticalCenter
        }
        Column {
          spacing: Style.space(2)
          Text {
            text: "Administrator Authentication"
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading ? Style.font.heading : 15
            font.weight: Font.Bold
          }
          Text {
            text: "Unlock OMAPP package operations for this session"
            color: Util.alpha(Color.menu.text, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.space(11)
          }
        }
      }

      // Password Input Box
      Rectangle {
        width: parent.width
        height: Style.space(42)
        radius: Style.cornerRadius
        color: Util.alpha(Color.menu.selectedBackground, 0.25)
        border.width: 1
        border.color: pwdInput.activeFocus ? Color.accent : Util.alpha(Color.menu.border, 0.4)

        TextInput {
          id: pwdInput
          anchors.fill: parent
          anchors.margins: Style.space(10)
          color: Color.menu.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body ? Style.font.body : 13
          echoMode: TextInput.Password
          clip: true

          Text {
            anchors.fill: parent
            visible: !pwdInput.text && !pwdInput.activeFocus
            text: "Enter sudo password..."
            color: Util.alpha(Color.menu.text, 0.4)
            font: pwdInput.font
          }

          onAccepted: {
            if (pwdInput.text.length > 0 && !sudoModalRoot.isChecking) {
              sudoModalRoot.submitted(pwdInput.text);
            }
          }
        }
      }

      // Error Message display
      Text {
        visible: !!sudoModalRoot.errorMessage
        width: parent.width
        text: sudoModalRoot.errorMessage
        color: "#f87171" // bright red
        font.family: Style.font.family
        font.pixelSize: Style.space(11)
        font.weight: Font.DemiBold
        wrapMode: Text.Wrap
      }

      Item { width: 1; height: Style.space(2) }

      // Buttons Row
      Row {
        anchors.right: parent.right
        spacing: Style.space(10)

        // Cancel
        Rectangle {
          height: Style.space(34)
          width: cancelText.implicitWidth + Style.space(24)
          radius: Style.space(6)
          color: Util.alpha(Color.menu.selectedBackground, 0.2)
          border.width: 1
          border.color: Util.alpha(Color.menu.border, 0.3)

          Text {
            id: cancelText
            anchors.centerIn: parent
            text: "Cancel"
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.space(12)
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sudoModalRoot.cancelled()
          }
        }

        // Unlock (Submit)
        Rectangle {
          height: Style.space(34)
          width: unlockText.implicitWidth + Style.space(24)
          radius: Style.space(6)
          color: Color.accent
          opacity: (pwdInput.text.length > 0 && !sudoModalRoot.isChecking) ? 1.0 : 0.5

          Text {
            id: unlockText
            anchors.centerIn: parent
            text: sudoModalRoot.isChecking ? "Verifying..." : "Unlock Session"
            color: Color.menu.selectedText || "#000000"
            font.family: Style.font.family
            font.pixelSize: Style.space(12)
            font.weight: Font.Bold
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: pwdInput.text.length > 0 && !sudoModalRoot.isChecking
            onClicked: {
              sudoModalRoot.submitted(pwdInput.text);
            }
          }
        }
      }
    }
  }

  function initFocus() {
    pwdInput.text = "";
    pwdInput.forceActiveFocus();
  }
}
