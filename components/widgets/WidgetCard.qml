import QtQuick

Rectangle {
    id: root
    property color outlineColor: "#3b9bb9c7"
    property color surface: "#d91a2029"
    property color foreground: "#f3f6fa"
    property color muted: "#aab4c1"
    radius: 12
    color: root.surface
    border.color: root.outlineColor
    border.width: 1
    antialiasing: true
}
