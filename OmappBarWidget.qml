import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "script/TaskManager.js" as TaskManager

Panel {
  id: barWidgetRoot

  moduleName: "waldseelen.omapp"
  ipcTarget: ""
  implicitWidth: contentRow.implicitWidth

  property var cpuPrevState: ({ total: 0, idle: 0 })
  property real cpuPct: 0.0
  property real gpuPct: 0.0
  property real ramGiB: 0.0

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!barStatsProc.running) barStatsProc.running = true;
    }
  }

  Process {
    id: barStatsProc
    command: [
      "bash", "-c",
      'echo "===SYS_START==="; head -n 1 /proc/stat 2>/dev/null; grep -E "^(MemTotal|MemAvailable):" /proc/meminfo 2>/dev/null; cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -n 2; echo "===SYS_END==="'
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var st = TaskManager.parseSystemHeaderStats(text, barWidgetRoot.cpuPrevState);
        barWidgetRoot.cpuPct = st.cpuPercent;
        barWidgetRoot.gpuPct = st.gpuPercent;
        barWidgetRoot.ramGiB = st.memUsedGiB;
      }
    }
  }

  Row {
    id: contentRow
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(5)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "󰍛"
      color: barWidgetRoot.cpuPct >= 50 ? Color.urgent : barWidgetRoot.bar.foreground
      font.family: barWidgetRoot.bar.fontFamily
      font.pixelSize: barWidgetRoot.bar.iconFontSize
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: barWidgetRoot.cpuPct.toFixed(0) + "% · " + barWidgetRoot.ramGiB.toFixed(1) + "G"
      color: barWidgetRoot.bar.foreground
      font.family: barWidgetRoot.bar.fontFamily
      font.pixelSize: barWidgetRoot.bar.fontSize
    }
  }

  function onClicked() {
    Util.execDetached(["omarchy-shell", "shell", "summon", "waldseelen.omapp", "tasks"]);
  }
}
