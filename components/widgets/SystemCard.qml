pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower

WidgetWindow {
    id: root
    property color surface: "#d91a2029"
    property color border: "#3b9bb9c7"
    property color foreground: "#f3f6fa"
    property color muted: "#aab4c1"
    cardHeight: 130
    topOffset: 470
    visible: screen !== null
    property string cpu: "--"
    property string memory: "--"
    property string disk: "--"
    property string gpu: "--"
    property string temperature: ""
    readonly property string battery: UPower.displayDevice && UPower.displayDevice.isPresent
        ? Math.round(UPower.displayDevice.percentage * 100) + "%" : "N/A"
    property double previousTotal: 0
    property double previousIdle: 0

    function sample() {
        if (probe.running) return;
        probe.command = ["sh", "-c", "awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5+$6}' /proc/stat; awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {if(t>0) printf \"%.0f\\n\", (t-a)*100/t; else print \"-\"}' /proc/meminfo; df -P / | awk 'NR==2 {gsub(\"%\",\"\",$5); print $5}'; if command -v nvidia-smi >/dev/null 2>&1; then gpu=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1); case \"$gpu\" in ''|*[!0-9]*) echo - ;; *) echo \"$gpu\" ;; esac; else echo -; fi; if command -v sensors >/dev/null 2>&1; then sensors 2>/dev/null | awk '/Package id 0:/ {v=$4} /Tctl:/ {v=$2} END {if(v) {gsub(/[+°C]/,\"\",v); print v} else print \"-\"}'; else echo -; fi"];
        probe.running = true;
    }

    Process {
        id: probe
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                if (lines.length < 4) return;
                var cpuParts = lines[0].trim().split(/\s+/).map(Number);
                if (cpuParts.length === 2 && root.previousTotal > 0) {
                    var totalDelta = cpuParts[0] - root.previousTotal;
                    var idleDelta = cpuParts[1] - root.previousIdle;
                    root.cpu = totalDelta > 0 ? Math.round(100 * (1 - idleDelta / totalDelta)) + "%" : "0%";
                }
                if (cpuParts.length === 2) {
                    root.previousTotal = cpuParts[0];
                    root.previousIdle = cpuParts[1];
                }
                root.memory = lines[1] && lines[1] !== "-" ? lines[1] + "%" : "--";
                root.disk = lines[2] && lines[2] !== "-" ? lines[2] + "%" : "--";
                root.gpu = lines[3] && lines[3] !== "-" ? lines[3] + "%" : "N/A";
                root.temperature = lines[4] && lines[4] !== "-" ? lines[4] + "°" : "";
            }
        }
    }
    Timer {
        interval: 15000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    WidgetCard {
        anchors.fill: parent
        surface: root.surface
        outlineColor: root.border
        Grid {
            anchors.fill: parent
            anchors.margins: 14
            columns: 2
            columnSpacing: 20
            rowSpacing: 8
            Repeater {
                model: [
                    { name: "CPU", value: root.cpu },
                    { name: "MEMORY", value: root.memory },
                    { name: "DISK", value: root.disk },
                    { name: "BATTERY", value: root.battery },
                    { name: "GPU", value: root.gpu },
                    { name: "TEMP", value: root.temperature || "N/A" }
                ]
                Column {
                    id: reading
                    required property var modelData
                    width: 92
                    spacing: 2
                    Text { text: reading.modelData.name; color: root.muted; font.pixelSize: 8; font.letterSpacing: 0.5 }
                    Text { text: reading.modelData.value; color: root.foreground; font.pixelSize: 14; font.weight: Font.Medium }
                }
            }
        }
    }
}
