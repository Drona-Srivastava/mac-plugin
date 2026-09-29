import QtQuick
import Quickshell

Item {
    id: root
    property var bar: null
    property string moduleName: ""
    property var settings: ({})
    implicitWidth: 30
    implicitHeight: bar ? bar.barSize : 26
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 5
        color: mouse.containsMouse ? "#25ffffff" : "transparent"
    }
    Column {
        anchors.centerIn: parent
        spacing: 4
        Repeater {
            model: 2
            Rectangle {
                required property int index
                width: 15
                height: 2
                radius: 1
                color: "#ededf0"
                Rectangle {
                    x: parent.index === 0 ? 3 : 9
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: 5
                    radius: 3
                    color: "#ededf0"
                    border.color: "#202127"
                    border.width: 1
                }
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["omarchy-shell", "drona-mac", "settings"])
        onEntered: if (root.bar)
            root.bar.showTooltip(root, "Mac Desktop appearance")
        onExited: if (root.bar)
            root.bar.hideTooltip(root)
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Mac Desktop appearance"
    Accessible.onPressAction: Quickshell.execDetached(["omarchy-shell", "drona-mac", "settings"])
}
