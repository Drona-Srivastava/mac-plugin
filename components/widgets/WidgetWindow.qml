import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    property int cardWidth: 246
    property int cardHeight: 100
    property int topOffset: 24
    property int leftOffset: 18

    anchors.top: true
    anchors.left: true
    margins {
        top: root.topOffset
        left: root.leftOffset
    }
    implicitWidth: cardWidth
    implicitHeight: cardHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "drona.mac.desktop-widget"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
}
