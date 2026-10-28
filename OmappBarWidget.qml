import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "script/TaskManager.js" as TaskManager

BarWidget {
  id: barWidgetRoot

  moduleName: "waldseelen.omapp"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

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

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: barWidgetRoot.bar
    labelVisible: false
    fixedWidth: contentRow.implicitWidth + Style.spaceReal(16)
    tooltipText: "OMAPP Task Manager (Click to open)"

    onPressed: function(b) {
      if (!barWidgetRoot.bar) {
        Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "waldseelen.omapp", "tasks"]);
        return;
      }
      barWidgetRoot.bar.run("omarchy-shell shell toggle waldseelen.omapp '{\"tab\":\"tasks\"}'");
    }

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(5)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "󰍛"
        color: barWidgetRoot.cpuPct >= 50 ? Color.urgent : (barWidgetRoot.bar ? barWidgetRoot.bar.foreground : Color.foreground)
        font.family: barWidgetRoot.bar ? barWidgetRoot.bar.fontFamily : Style.font.family
        font.pixelSize: barWidgetRoot.bar ? barWidgetRoot.bar.iconFontSize : Style.font.body
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: barWidgetRoot.cpuPct.toFixed(0) + "% · " + barWidgetRoot.ramGiB.toFixed(1) + "G"
        color: barWidgetRoot.bar ? barWidgetRoot.bar.foreground : Color.foreground
        font.family: barWidgetRoot.bar ? barWidgetRoot.bar.fontFamily : Style.font.family
        font.pixelSize: barWidgetRoot.bar ? barWidgetRoot.bar.fontSize : Style.font.caption
      }
    }
  }
}
