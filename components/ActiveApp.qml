import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: root
    property var bar: null
    property string moduleName: ""
    property var settings: ({})
    readonly property var window: ToplevelManager.activeToplevel
    readonly property var entry: window ? DesktopEntries.byId(window.appId) : null
    readonly property string appName: entry ? entry.name : (window ? String(window.appId).split(".").pop() : "Desktop")
    implicitHeight: bar ? bar.barSize : 26
    implicitWidth: Math.min(label.implicitWidth, 160) + 20
    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, 160)
        text: root.appName
        textFormat: Text.PlainText
        color: "#f4f4f7"
        font.family: "sans-serif"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }
}
