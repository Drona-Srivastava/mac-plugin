pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../services"

// Instantiate ONCE under Bar.qml, not once per top-bar screen. This component
// owns its own screen variants and never touches compositor styling or keys.
Scope {
    id: root

    property var preferences: null
    readonly property var values: preferences && preferences.values ? preferences.values : ({})
    readonly property bool enabled: values.dockEnabled !== false
    readonly property bool autoHide: values.dockAutoHide !== false
    readonly property int iconSize: Math.max(32, Math.min(72, Number(values.dockSize) || 48))
    readonly property bool reduceMotion: values.reduceMotion === true
    readonly property bool reduceTransparency: values.reduceTransparency === true
    readonly property string monitorName: String(values.dockMonitor || "")
    readonly property color surfaceColor: reduceTransparency ? "#25272d" : "#ed25272d"
    readonly property color textColor: "#f4f5f7"
    readonly property color secondaryColor: "#bec3ce"
    readonly property color borderColor: "#626772"
    readonly property var dockScreens: {
        var screens = Quickshell.screens;
        if (!root.monitorName)
            return screens;
        var selected = screens.filter(function (screen) {
            return screen.name === root.monitorName;
        });
        // A disconnected selected monitor must not strand the dock.
        return selected.length > 0 ? selected : screens.slice(0, 1);
    }

    DockModel {
        id: dockModel
        preferences: root.preferences
    }

    Variants {
        model: root.enabled ? root.dockScreens : []

        delegate: Component {
            Scope {
                id: screenDock
                required property var modelData

                readonly property var monitor: Hyprland.monitorFor(screenDock.modelData)
                readonly property bool fullscreen: {
                    if (monitor && monitor.activeWorkspace && monitor.activeWorkspace.hasFullscreen)
                        return true;
                    // A visible special workspace can also contain a fullscreen app.
                    var special = monitor && monitor.lastIpcObject.specialWorkspace;
                    var workspaces = Hyprland.workspaces.values;
                    if (special && special.id) {
                        for (var i = 0; i < workspaces.length; ++i) {
                            if (workspaces[i].id === special.id && workspaces[i].hasFullscreen)
                                return true;
                        }
                    }
                    var active = ToplevelManager.activeToplevel;
                    return !!active && active.fullscreen && active.screens.indexOf(screenDock.modelData) !== -1;
                }
                property bool revealed: false
                readonly property bool shown: !fullscreen && (!root.autoHide || revealed)
                property string menuKey: ""
                readonly property var menuGroup: dockModel.groupFor(menuKey)
                property Item hoveredItem: null
                property string hoveredLabel: ""
                property Item menuAnchor: null
                property bool tooltipReady: false
                readonly property var menuRows: {
                    var group = menuGroup;
                    if (!group)
                        return [];
                    var rows = [];
                    for (var i = 0; i < group.windows.length; ++i) {
                        var top = group.windows[i];
                        rows.push({
                            action: "focus",
                            window: top,
                            label: (top.activated ? "•  " : "") + (top.title || group.name),
                            enabled: true
                        });
                    }
                    if (group.entry) {
                        rows.push({
                            action: "launch",
                            label: "Launch application",
                            enabled: true
                        });
                        rows.push({
                            action: "pin",
                            label: group.pinned ? "Unpin from Dock" : "Pin to Dock",
                            enabled: dockModel.canPersist && (group.pinned || dockModel.pins.length < 40)
                        });
                        if (group.pinned) {
                            rows.push({
                                action: "left",
                                label: "Move pin left",
                                enabled: dockModel.canPersist
                            });
                            rows.push({
                                action: "right",
                                label: "Move pin right",
                                enabled: dockModel.canPersist
                            });
                        }
                    }
                    return rows;
                }

                function closeMenu() {
                    screenDock.menuKey = "";
                    if (!dockHover.hovered)
                        hideDelay.restart();
                }

                function openMenu(group, item) {
                    screenDock.menuAnchor = item;
                    screenDock.tooltipReady = false;
                    screenDock.menuKey = group.key;
                    screenDock.revealed = true;
                    hideDelay.stop();
                    menuList.currentIndex = 0;
                }

                function activateGroup(group, item, context) {
                    if (context || group.windows.length > 1) {
                        screenDock.openMenu(group, item);
                    } else if (group.windows.length === 1) {
                        screenDock.closeMenu();
                        dockModel.focusWindow(group.windows[0]);
                    } else {
                        screenDock.closeMenu();
                        dockModel.launch(group.desktopId);
                    }
                }

                function triggerRow(row) {
                    if (!row || !row.enabled)
                        return;
                    var group = screenDock.menuGroup;
                    if (!group)
                        return;
                    screenDock.closeMenu();
                    if (row.action === "focus")
                        dockModel.focusWindow(row.window);
                    else if (row.action === "launch")
                        dockModel.launch(group.desktopId);
                    else if (row.action === "pin")
                        dockModel.togglePin(group.key);
                    else if (row.action === "left")
                        dockModel.movePin(group.key, -1);
                    else if (row.action === "right")
                        dockModel.movePin(group.key, 1);
                }

                onFullscreenChanged: {
                    if (fullscreen) {
                        screenDock.closeMenu();
                        screenDock.revealed = false;
                        screenDock.hoveredItem = null;
                        revealDelay.stop();
                        hideDelay.stop();
                    }
                }
                onMenuGroupChanged: if (!menuGroup && menuKey)
                    screenDock.closeMenu()
                onHoveredItemChanged: {
                    screenDock.tooltipReady = false;
                    if (hoveredItem)
                        tooltipDelay.restart();
                    else
                        tooltipDelay.stop();
                }

                // Single-shot interaction timers only: nothing wakes periodically.
                Timer {
                    id: revealDelay
                    interval: 140
                    onTriggered: if (dockHover.hovered && !screenDock.fullscreen)
                        screenDock.revealed = true
                }
                Timer {
                    id: hideDelay
                    interval: 550
                    onTriggered: if (!dockHover.hovered && !screenDock.menuKey)
                        screenDock.revealed = false
                }
                Timer {
                    id: tooltipDelay
                    interval: 500
                    onTriggered: screenDock.tooltipReady = true
                }

                PanelWindow {
                    id: dockWindow
                    screen: screenDock.modelData
                    anchors.bottom: true
                    implicitWidth: Math.max(1, Math.min(screenDock.modelData.width - 24, dockModel.groups.length * (root.iconSize + 12) + 16))
                    implicitHeight: root.iconSize + 34
                    color: "transparent"
                    visible: !screenDock.fullscreen && dockModel.groups.length > 0
                    // Always-visible mode explicitly reserves this bottom band;
                    // autohide (even while revealed) never changes window layout.
                    exclusionMode: root.autoHide || screenDock.fullscreen ? ExclusionMode.Ignore : ExclusionMode.Normal
                    exclusiveZone: root.autoHide || screenDock.fullscreen ? 0 : implicitHeight
                    WlrLayershell.namespace: "drona.mac.dock"
                    WlrLayershell.layer: WlrLayer.Top
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                    // No fullscreen input catcher. Hidden input is ONLY a centred
                    // 3px edge strip; shown input is bounded by the dock width.
                    mask: Region {
                        x: screenDock.shown ? 0 : Math.round((dockWindow.width - width) / 2)
                        y: screenDock.shown ? 0 : dockWindow.height - 3
                        width: screenDock.fullscreen ? 0 : screenDock.shown ? dockWindow.width : Math.min(240, dockWindow.width)
                        height: screenDock.fullscreen ? 0 : screenDock.shown ? dockWindow.height : 3
                    }

                    HoverHandler {
                        id: dockHover
                        onHoveredChanged: {
                            if (hovered) {
                                hideDelay.stop();
                                if (!screenDock.shown)
                                    revealDelay.restart();
                            } else {
                                revealDelay.stop();
                                if (!screenDock.menuKey)
                                    hideDelay.restart();
                            }
                        }
                    }

                    Rectangle {
                        id: dockSurface
                        width: parent.width
                        height: root.iconSize + 24
                        radius: 20
                        color: root.surfaceColor
                        border.width: 1
                        border.color: root.borderColor
                        opacity: screenDock.shown ? 1 : 0
                        enabled: screenDock.shown

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.reduceMotion ? 0 : 140
                            }
                        }

                        ListView {
                            id: appList
                            anchors.fill: parent
                            anchors.margins: 8
                            orientation: ListView.Horizontal
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            model: dockModel.groups
                            spacing: 0

                            WheelHandler {
                                target: null
                                onWheel: function (event) {
                                    var delta = event.angleDelta.y || event.angleDelta.x;
                                    appList.contentX = Math.max(0, Math.min(Math.max(0, appList.contentWidth - appList.width), appList.contentX - delta / 2));
                                    event.accepted = true;
                                }
                            }

                            delegate: Item {
                                id: appItem
                                required property var modelData
                                readonly property var group: modelData
                                readonly property bool active: group.windows.some(function (top) {
                                    return top.activated;
                                })
                                width: root.iconSize + 12
                                height: appList.height
                                Accessible.role: Accessible.Button
                                Accessible.name: group.name
                                Accessible.description: group.windows.length > 1 ? "Choose a window; right-click for dock actions" : "Focus or launch; right-click for dock actions"
                                Accessible.onPressAction: screenDock.activateGroup(appItem.group, appItem, false)

                                Rectangle {
                                    x: 3
                                    y: 0
                                    width: parent.width - 6
                                    height: root.iconSize + 2
                                    radius: 12
                                    color: appMouse.containsMouse ? "#25ffffff" : appItem.active ? "#17ffffff" : "transparent"
                                }
                                Image {
                                    id: appIcon
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: root.iconSize
                                    height: width
                                    source: dockModel.iconSource(appItem.group.entry)
                                    sourceSize: Qt.size(root.iconSize * (screenDock.modelData.devicePixelRatio || 1), root.iconSize * (screenDock.modelData.devicePixelRatio || 1))
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                }
                                Text {
                                    anchors.centerIn: appIcon
                                    visible: appIcon.status === Image.Error || appIcon.status === Image.Null
                                    text: appItem.group.name.slice(0, 1).toUpperCase()
                                    color: root.textColor
                                    font.pixelSize: root.iconSize / 2
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: appItem.group.windows.length > 1 ? 12 : 5
                                    height: 4
                                    radius: 2
                                    visible: appItem.group.windows.length > 0
                                    color: appItem.active ? "#85baff" : root.secondaryColor
                                }
                                MouseArea {
                                    id: appMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        screenDock.hoveredLabel = appItem.group.name;
                                        screenDock.hoveredItem = appItem;
                                    }
                                    onExited: if (screenDock.hoveredItem === appItem)
                                        screenDock.hoveredItem = null
                                    onClicked: function (mouse) {
                                        screenDock.activateGroup(appItem.group, appItem, mouse.button === Qt.RightButton);
                                    }
                                }
                            }
                        }
                    }
                }

                PopupWindow {
                    id: tooltip
                    visible: screenDock.tooltipReady && !!screenDock.hoveredItem && screenDock.shown && !screenDock.menuKey
                    color: "transparent"
                    grabFocus: false
                    implicitWidth: Math.min(280, tooltipText.implicitWidth + 24)
                    implicitHeight: 34
                    mask: Region {}
                    anchor {
                        window: dockWindow
                        edges: Edges.Top | Edges.Left
                        gravity: Edges.Bottom | Edges.Right
                        adjustment: PopupAdjustment.SlideX
                        rect.x: screenDock.hoveredItem ? Math.round(screenDock.hoveredItem.mapToItem(dockWindow.contentItem, screenDock.hoveredItem.width / 2, 0).x - tooltip.width / 2) : 0
                        rect.y: -tooltip.height - 8
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: root.reduceTransparency ? "#2a2c32" : "#f02a2c32"
                        radius: 9
                        border.color: root.borderColor
                        Text {
                            id: tooltipText
                            anchors.fill: parent
                            anchors.margins: 8
                            text: screenDock.hoveredLabel
                            textFormat: Text.PlainText
                            color: root.textColor
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                PopupWindow {
                    id: contextMenu
                    visible: !!screenDock.menuGroup && screenDock.shown
                    color: "transparent"
                    // Only an explicit click opens this keyboard-focusable popup.
                    grabFocus: true
                    implicitWidth: Math.min(310, screenDock.modelData.width - 24)
                    implicitHeight: Math.min(screenDock.menuRows.length * 34 + 48, screenDock.modelData.height / 2)
                    anchor {
                        window: dockWindow
                        edges: Edges.Top | Edges.Left
                        gravity: Edges.Bottom | Edges.Right
                        adjustment: PopupAdjustment.SlideX
                        rect.x: screenDock.menuAnchor ? Math.round(screenDock.menuAnchor.mapToItem(dockWindow.contentItem, screenDock.menuAnchor.width / 2, 0).x - contextMenu.width / 2) : Math.round((dockWindow.width - contextMenu.width) / 2)
                        rect.y: -contextMenu.height - 6
                    }
                    onVisibleChanged: {
                        if (visible)
                            Qt.callLater(function () {
                                if (contextMenu.visible)
                                    menuContent.forceActiveFocus();
                            });
                    }

                    HyprlandFocusGrab {
                        active: contextMenu.visible
                        windows: [dockWindow, contextMenu]
                        onCleared: screenDock.closeMenu()
                    }

                    Rectangle {
                        id: menuContent
                        anchors.fill: parent
                        color: root.reduceTransparency ? "#25272d" : "#fa25272d"
                        border.color: root.borderColor
                        radius: 12
                        focus: true
                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_Escape)
                                screenDock.closeMenu();
                            else if (event.key === Qt.Key_Down)
                                menuList.incrementCurrentIndex();
                            else if (event.key === Qt.Key_Up)
                                menuList.decrementCurrentIndex();
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                screenDock.triggerRow(screenDock.menuRows[menuList.currentIndex]);
                            else
                                return;
                            event.accepted = true;
                        }

                        Text {
                            x: 12
                            y: 10
                            width: parent.width - 46
                            text: screenDock.menuGroup ? screenDock.menuGroup.name : ""
                            textFormat: Text.PlainText
                            font.pixelSize: 12
                            font.bold: true
                            color: root.secondaryColor
                            elide: Text.ElideRight
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            y: 7
                            text: "×"
                            font.pixelSize: 20
                            color: root.secondaryColor
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: screenDock.closeMenu()
                            }
                        }
                        ListView {
                            id: menuList
                            x: 6
                            y: 36
                            width: parent.width - 12
                            height: parent.height - 42
                            clip: true
                            model: screenDock.menuRows
                            boundsBehavior: Flickable.StopAtBounds
                            keyNavigationWraps: true
                            delegate: Rectangle {
                                id: menuRow
                                required property var modelData
                                required property int index
                                width: menuList.width
                                height: 34
                                radius: 6
                                color: menuMouse.containsMouse || menuList.currentIndex === index ? "#374b65" : "transparent"
                                opacity: modelData.enabled ? 1 : 0.45
                                Accessible.role: Accessible.MenuItem
                                Accessible.name: modelData.label
                                Accessible.onPressAction: screenDock.triggerRow(menuRow.modelData)
                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 9
                                    anchors.rightMargin: 9
                                    text: menuRow.modelData.label
                                    textFormat: Text.PlainText
                                    color: root.textColor
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    id: menuMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: menuRow.modelData.enabled
                                    onEntered: menuList.currentIndex = menuRow.index
                                    onClicked: screenDock.triggerRow(menuRow.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
