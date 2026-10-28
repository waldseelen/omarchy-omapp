import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "script/Scanner.js" as Scanner

BorderSurface {
  id: inspectorRoot

  property var appItem: null
  property bool isRunning: false
  property string runningPid: ""
  property var shell: null

  property string currentDeepPkg: ""
  property string deepSection: "" // "", "files", "tree", "downgrade"
  property var deepData: ({ files: [], tree: "", versions: [] })
  property bool deepLoading: false

  signal uninstallRequested(var app)
  signal killRequested(var app)
  signal launchRequested(var app)
  signal openConfigRequested(var app)
  signal openUrlRequested(string url)
  signal togglePinRequested(string pkg)
  signal downgradeRequested(string pkg, string archivePath)

  radius: Style.cornerRadius
  color: Style.normalFill
  borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)
  clip: true

  onAppItemChanged: {
    inspectorRoot.deepSection = "";
    inspectorRoot.currentDeepPkg = "";
    inspectorRoot.deepData = { files: [], tree: "", versions: [] };
  }

  function loadDeepInspect(section) {
    if (!inspectorRoot.appItem || !inspectorRoot.appItem.pkg) return;
    if (inspectorRoot.deepSection === section) {
      inspectorRoot.deepSection = "";
      return;
    }
    inspectorRoot.deepSection = section;
    if (inspectorRoot.currentDeepPkg !== inspectorRoot.appItem.pkg) {
      inspectorRoot.currentDeepPkg = inspectorRoot.appItem.pkg;
      inspectorRoot.deepLoading = true;
      var cmd = Scanner.buildPackageDeepInspectScript(inspectorRoot.appItem.pkg);
      if (cmd) {
        deepInspectProc.command = cmd;
        deepInspectProc.running = true;
      } else {
        inspectorRoot.deepLoading = false;
      }
    }
  }

  Process {
    id: deepInspectProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        inspectorRoot.deepData = Scanner.parsePackageDeepInspect(text);
        inspectorRoot.deepLoading = false;
      }
    }
  }

  function resolveIconSource(iconName) {
    if (!iconName || iconName.length === 0) return Quickshell.iconPath("application-x-executable", true);
    if (iconName.indexOf("/") === 0) return Util.fileUrl(iconName);
    if (iconName.indexOf("file://") === 0 || iconName.indexOf("image://") === 0) return iconName;
    var cleanName = iconName;
    if (cleanName.slice(-4) === ".png" || cleanName.slice(-4) === ".svg") cleanName = cleanName.slice(0, -4);
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
    Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: "Select an application to inspect"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.body }
  }

  Flickable {
    anchors.fill: parent; anchors.margins: Style.space(16); visible: !!inspectorRoot.appItem
    contentHeight: contentCol.implicitHeight; boundsBehavior: Flickable.StopAtBounds; pixelAligned: true
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: contentCol; width: parent.width; spacing: Style.space(12)

      Row {
        width: parent.width; spacing: Style.space(12)
        Item {
          width: Style.space(44); height: Style.space(44)
          BorderSurface {
            anchors.fill: parent; radius: Style.cornerRadius; color: Style.hoverFill; visible: inspectorIconImg.status !== Image.Ready
            Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: "󰏖"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
          }
          Image {
            id: inspectorIconImg; anchors.fill: parent; sourceSize.width: Style.space(44) * Screen.devicePixelRatio; sourceSize.height: Style.space(44) * Screen.devicePixelRatio
            fillMode: Image.PreserveAspectFit; asynchronous: true; source: inspectorRoot.resolveIconSource(inspectorRoot.appItem ? inspectorRoot.appItem.icon : ""); visible: status === Image.Ready
          }
        }
        Column {
          width: parent.width - Style.space(56); spacing: Style.space(2)
          Text { textFormat: Text.PlainText; width: parent.width; text: inspectorRoot.appItem ? (inspectorRoot.appItem.name || inspectorRoot.appItem.pkg) : ""; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true; elide: Text.ElideRight }
          Text { textFormat: Text.PlainText; width: parent.width; text: inspectorRoot.appItem ? (inspectorRoot.appItem.pkg + (inspectorRoot.appItem.version ? " • " + inspectorRoot.appItem.version : "")) : ""; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
          Text { textFormat: Text.PlainText; text: inspectorRoot.isRunning ? ("● Running" + (inspectorRoot.runningPid ? " (PID " + inspectorRoot.runningPid + ")" : "")) : "○ Stopped"; color: inspectorRoot.isRunning ? Color.accent : Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
      }

      // Action Buttons (#20 Core Package Lock, #30 Pin)
      Flow {
        width: parent.width
        spacing: Style.space(6)

        Button {
          bordered: true
          iconText: (inspectorRoot.appItem && inspectorRoot.appItem.isProtected) ? "󰌾" : "󰩺"
          text: (inspectorRoot.appItem && inspectorRoot.appItem.isProtected) ? "Core Protected" : "Deep Uninstall"
          foreground: (inspectorRoot.appItem && inspectorRoot.appItem.isProtected) ? Color.muted : Color.urgent
          accent: Color.urgent
          background: (inspectorRoot.appItem && inspectorRoot.appItem.isProtected) ? "transparent" : Util.alpha(Color.urgent, Style.normalFillAlpha)
          onClicked: {
            if (inspectorRoot.appItem && !inspectorRoot.appItem.isProtected) {
              inspectorRoot.uninstallRequested(inspectorRoot.appItem);
            }
          }
        }

        Button {
          visible: inspectorRoot.isRunning
          bordered: true
          iconText: "󰅙"
          text: "Stop"
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

        Button {
          bordered: true
          selected: !!(inspectorRoot.appItem && inspectorRoot.appItem.pinned)
          iconText: "󰐃"
          text: (inspectorRoot.appItem && inspectorRoot.appItem.pinned) ? "Pinned" : "Pin"
          foreground: Color.menu.text
          accent: Color.accent
          onClicked: {
            if (inspectorRoot.appItem) inspectorRoot.togglePinRequested(inspectorRoot.appItem.pkg);
          }
        }
      }

      // Required By Warning Box
      BorderSurface {
        visible: !!(inspectorRoot.appItem && inspectorRoot.appItem.requiredBy && inspectorRoot.appItem.requiredBy !== "None")
        width: parent.width
        implicitHeight: reqCol.implicitHeight + Style.space(12)
        height: implicitHeight
        radius: Style.cornerRadius
        color: Util.alpha(Color.urgent, Style.normalFillAlpha)
        borderSpec: Border.controlSpec("normal", Color.urgent, Color.urgent)

        Column {
          id: reqCol
          anchors.fill: parent
          anchors.margins: Style.space(6)
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            text: "󰀦 Required by: " + (inspectorRoot.appItem ? inspectorRoot.appItem.requiredBy : "")
            color: Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            wrapMode: Text.Wrap
            width: parent.width
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

      PanelSeparator { foreground: Color.menu.text }

      // Metadata Table (#11 User Data + Total Footprint)
      Column {
        width: parent.width
        spacing: Style.space(6)

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(120); text: "Binary Size"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(120); text: inspectorRoot.appItem ? inspectorRoot.appItem.sizeFormatted : "-"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
        }

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(120); text: "User Config/Cache"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(120); text: inspectorRoot.appItem ? (inspectorRoot.appItem.userDataFormatted || "0 B") : "0 B"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
        }

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(120); text: "Total Footprint"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(120); text: inspectorRoot.appItem ? (inspectorRoot.appItem.totalSizeFormatted || inspectorRoot.appItem.sizeFormatted) : "-"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
        }

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(120); text: "Install Date"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(120); text: inspectorRoot.appItem && inspectorRoot.appItem.installDate ? inspectorRoot.appItem.installDate : "Unknown"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
        }

        Row {
          width: parent.width
          Text { textFormat: Text.PlainText; width: Style.space(120); text: "Executable"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { textFormat: Text.PlainText; width: parent.width - Style.space(120); text: inspectorRoot.appItem && inspectorRoot.appItem.exec ? inspectorRoot.appItem.exec : "-"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideMiddle }
        }
      }

      // Deep Package Tools (#14 Files & Downgrade, #19 Dependency Tree)
      Row {
        width: parent.width
        spacing: Style.space(6)
        visible: !!(inspectorRoot.appItem && inspectorRoot.appItem.category !== "webapp" && inspectorRoot.appItem.category !== "appimage")

        Button {
          bordered: true
          selected: inspectorRoot.deepSection === "files"
          text: "Files (pacman -Ql)"
          fontSize: Style.font.caption
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(3)
          onClicked: inspectorRoot.loadDeepInspect("files")
        }

        Button {
          bordered: true
          selected: inspectorRoot.deepSection === "tree"
          text: "Dep Tree"
          fontSize: Style.font.caption
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(3)
          onClicked: inspectorRoot.loadDeepInspect("tree")
        }

        Button {
          bordered: true
          selected: inspectorRoot.deepSection === "downgrade"
          text: "Downgrade"
          fontSize: Style.font.caption
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(3)
          onClicked: inspectorRoot.loadDeepInspect("downgrade")
        }
      }

      BorderSurface {
        visible: inspectorRoot.deepSection.length > 0
        width: parent.width
        implicitHeight: deepCol.implicitHeight + Style.space(12)
        height: implicitHeight
        radius: Style.cornerRadius
        color: Style.hoverFill
        borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)

        Column {
          id: deepCol
          anchors.fill: parent
          anchors.margins: Style.space(6)
          spacing: Style.space(4)

          Text {
            visible: inspectorRoot.deepSection !== "downgrade"
            width: parent.width
            textFormat: Text.PlainText
            text: {
              if (inspectorRoot.deepLoading) return "Loading package metadata...";
              if (inspectorRoot.deepSection === "files") {
                return inspectorRoot.deepData.files.length > 0 ? inspectorRoot.deepData.files.slice(0, 30).join("\n") : "No file list available";
              }
              return inspectorRoot.deepData.tree || "No dependency tree available";
            }
            color: Color.menu.text
            font.family: Style.font.monoFamily || Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WrapAnywhere
          }

          Repeater {
            model: inspectorRoot.deepSection === "downgrade" ? inspectorRoot.deepData.versions : []

            Button {
              required property var modelData
              width: deepCol.width
              bordered: true
              leftAlign: true
              iconText: "󰁯"
              text: "Install cached: " + modelData.split("/").pop()
              fontSize: Style.font.caption
              foreground: Color.accent
              accent: Color.accent
              onClicked: {
                if (inspectorRoot.appItem) {
                  inspectorRoot.downgradeRequested(inspectorRoot.appItem.pkg, modelData);
                }
              }
            }
          }

          Text {
            visible: inspectorRoot.deepSection === "downgrade" && !inspectorRoot.deepLoading && inspectorRoot.deepData.versions.length === 0
            textFormat: Text.PlainText
            text: "No cached archives found in /var/cache/pacman/pkg"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
