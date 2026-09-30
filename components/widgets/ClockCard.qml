pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

WidgetWindow {
    id: root
    property bool use24Hour: true
    property color surface: "#d91a2029"
    property color border: "#3b9bb9c7"
    property color foreground: "#f3f6fa"
    property color muted: "#aab4c1"
    cardHeight: 104
    visible: screen !== null
    readonly property date now: clock.date

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    WidgetCard {
        anchors.fill: parent
        surface: root.surface
        outlineColor: root.border
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 3
            Text {
                text: Qt.formatDate(root.now, "dddd, MMMM d")
                color: root.muted
                font.family: "sans-serif"
                font.pixelSize: 12
            }
            Text {
                text: Qt.formatTime(root.now, root.use24Hour ? "HH:mm" : "h:mm AP")
                color: root.foreground
                font.family: "sans-serif"
                font.pixelSize: 35
                font.weight: Font.Light
            }
        }
    }
}
