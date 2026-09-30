pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

WidgetWindow {
    id: root
    property color surface: "#d91a2029"
    property color border: "#3b9bb9c7"
    property color foreground: "#f3f6fa"
    property color muted: "#aab4c1"
    cardHeight: 230
    topOffset: 234
    visible: screen !== null
    readonly property date today: calendarClock.date

    function cells() {
        var first = new Date(today.getFullYear(), today.getMonth(), 1);
        var offset = (first.getDay() + 6) % 7;
        var days = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
        var list = [];
        for (var i = 0; i < 42; i++) {
            var day = i - offset + 1;
            list.push({ label: day > 0 && day <= days ? String(day) : "", today: day === today.getDate() });
        }
        return list;
    }

    SystemClock { id: calendarClock; precision: SystemClock.Minutes }

    WidgetCard {
        anchors.fill: parent
        surface: root.surface
        outlineColor: root.border
        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 7
            Text {
                text: Qt.formatDate(root.today, "MMMM yyyy").toUpperCase()
                color: "#7bc8df"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
            Grid {
                columns: 7
                spacing: 4
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    Text {
                        required property string modelData
                        width: 26
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: root.muted
                        font.pixelSize: 9
                    }
                }
            }
            Grid {
                columns: 7
                spacing: 4
                Repeater {
                    model: root.cells()
                    Rectangle {
                        id: dayCell
                        required property var modelData
                        width: 26
                        height: 24
                        radius: 12
                        color: modelData.today ? "#73bed8" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: dayCell.modelData.label
                            color: dayCell.modelData.today ? "#101820" : root.muted
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }
}
