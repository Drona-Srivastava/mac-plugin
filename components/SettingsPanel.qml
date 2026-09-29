import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var preferences
    required property string projectPath
    property string output: "The bar and dock are active. Application appearance and wallpaper are optional."
    property bool confirmApply: false
    visible: false
    color: "transparent"
    implicitWidth: 430
    implicitHeight: Math.min(690, screen ? screen.height - 90 : 690)
    anchors {
        top: true
        right: true
    }
    margins {
        top: 42
        right: 16
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "drona-mac-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function open() {
        var monitor = Hyprland.focusedMonitor;
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            if (monitor && screens[i].name === monitor.name) {
                screen = screens[i];
                break;
            }
        }
        visible = true;
        content.forceActiveFocus();
    }
    function toggle() {
        if (visible)
            visible = false;
        else
            open();
    }
    function runAppearance(action) {
        if (appearance.running)
            return;
        confirmApply = false;
        output = "Working…";
        appearance.command = ["python3", projectPath + "/scripts/appearance", action, "--yes"];
        appearance.running = true;
    }

    function summarize(text) {
        try {
            var report = JSON.parse(text);
            var result = "Appearance: " + String(report.result || "unknown").replace(/-/g, " ") + ".";
            if (report.error)
                result += "\n" + report.error;
            if (report.message)
                result += "\n" + report.message;
            if (report.conflicts && report.conflicts.length)
                result += "\nLater edits were preserved. Review scripts/appearance status before retrying.";
            if (report.skipped && report.skipped.length)
                result += "\nSkipped: " + report.skipped.map(function (item) {
                    return item.adapter + ": " + item.reason;
                }).join("; ");
            if (report.journal && report.result === "applied")
                result += "\nRestore information saved outside the plugin checkout.";
            return result;
        } catch (error) {
            return text.trim();
        }
    }

    Process {
        id: appearance
        stdout: StdioCollector {
            onStreamFinished: if (text.trim())
                root.output = root.summarize(text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                root.output += "\n" + text.trim()
        }
        onExited: function (exitCode) {
            if (exitCode !== 0)
                root.output += "\nNo success assumed. Review the report before retrying.";
        }
    }

    Rectangle {
        id: content
        anchors.fill: parent
        radius: 22
        color: root.preferences.values.reduceTransparency ? "#24252c" : "#f524252c"
        border.color: "#38ffffff"
        border.width: 1
        focus: true
        Keys.onEscapePressed: root.visible = false

        ScrollView {
            anchors.fill: parent
            anchors.margins: 22
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: parent.width
                spacing: 16
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "\ue900"
                        font.family: "omarchy"
                        font.pixelSize: 25
                        color: "#eeeeF4"
                    }
                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Mac Desktop"
                            color: "#f5f5f7"
                            font.family: "sans-serif"
                            font.pixelSize: 21
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "DARK APPEARANCE · PREVIEW 0.1.1"
                            color: "#a5a6b1"
                            font.family: "sans-serif"
                            font.pixelSize: 10
                            font.letterSpacing: 1
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    ActionButton {
                        label: "×"
                        onClicked: root.visible = false
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: "Your Omarchy logo, shortcuts and window styling stay exactly as they are. Widgets are coming later."
                    color: "#b9bac4"
                    font.family: "sans-serif"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#20ffffff"
                }
                ToggleRow {
                    title: "Show dock"
                    checked: root.preferences.values.dockEnabled
                    onToggled: root.preferences.setValue("dockEnabled", !checked)
                }
                ToggleRow {
                    title: "Automatically hide dock"
                    checked: root.preferences.values.dockAutoHide
                    onToggled: root.preferences.setValue("dockAutoHide", !checked)
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Dock icon size"
                        color: "#eeeeF4"
                        font.family: "sans-serif"
                        font.pixelSize: 13
                        Layout.fillWidth: true
                    }
                    ActionButton {
                        label: "−"
                        onClicked: root.preferences.setValue("dockSize", root.preferences.values.dockSize - 4)
                    }
                    Text {
                        text: root.preferences.values.dockSize
                        color: "#b9bac4"
                        font.pixelSize: 12
                    }
                    ActionButton {
                        label: "+"
                        onClicked: root.preferences.setValue("dockSize", root.preferences.values.dockSize + 4)
                    }
                }
                ToggleRow {
                    title: "Mac-style bar arrangement"
                    checked: root.preferences.values.macLayout
                    onToggled: root.preferences.setValue("macLayout", !checked)
                }
                ToggleRow {
                    title: "Reduce transparency"
                    checked: root.preferences.values.reduceTransparency
                    onToggled: root.preferences.setValue("reduceTransparency", !checked)
                }
                ToggleRow {
                    title: "Reduce motion"
                    checked: root.preferences.values.reduceMotion
                    onToggled: root.preferences.setValue("reduceMotion", !checked)
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#20ffffff"
                }
                Text {
                    text: "Desktop appearance"
                    color: "#f5f5f7"
                    font.family: "sans-serif"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: root.confirmApply ? "Apply dark GTK/Nautilus and shell colours? A restore journal is saved first. No Hyprland or shortcut changes. The bundled wallpaper is a separate manual option." : "Optional, reversible dark colours for stock panels and GTK apps. The existing file manager and applications are kept."
                    color: "#b9bac4"
                    font.family: "sans-serif"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    ActionButton {
                        label: root.confirmApply ? "Confirm apply" : "Apply appearance…"
                        primary: true
                        enabled: !appearance.running
                        onClicked: {
                            if (root.confirmApply)
                                root.runAppearance("apply");
                            else
                                root.confirmApply = true;
                        }
                    }
                    ActionButton {
                        label: root.confirmApply ? "Cancel" : "Restore"
                        enabled: !appearance.running
                        onClicked: {
                            if (root.confirmApply)
                                root.confirmApply = false;
                            else
                                root.runAppearance("restore");
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.output
                    textFormat: Text.PlainText
                    color: "#aeb2c3"
                    font.family: "sans-serif"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#20ffffff"
                }
                ActionButton {
                    label: "Return to Omarchy bar"
                    onClicked: Quickshell.execDetached(["bash", root.projectPath + "/scripts/return-to-stock"])
                }
                Text {
                    Layout.fillWidth: true
                    text: "Restore appearance first to undo external colours. Returning also reloads the shell to reset panel routing (only while unlocked)."
                    color: "#a5a6b1"
                    font.family: "sans-serif"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    component ActionButton: Rectangle {
        property string label: ""
        property bool primary: false
        signal clicked
        implicitWidth: textLabel.implicitWidth + 22
        implicitHeight: 32
        radius: 8
        opacity: enabled ? 1 : 0.45
        color: primary ? (pointer.containsMouse ? "#529bf4" : "#367ddd") : (pointer.containsMouse ? "#48505e" : "#383c48")
        activeFocusOnTab: true
        border.width: activeFocus ? 2 : 0
        border.color: "#acd2ff"
        Text {
            id: textLabel
            anchors.centerIn: parent
            text: parent.label
            color: "white"
            font.family: "sans-serif"
            font.pixelSize: 12
        }
        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
        Keys.onSpacePressed: clicked()
        Keys.onReturnPressed: clicked()
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.onPressAction: clicked()
    }
    component ToggleRow: RowLayout {
        id: toggle
        property string title: ""
        property bool checked: false
        signal toggled
        Layout.fillWidth: true
        Text {
            text: toggle.title
            color: "#eeeeF4"
            font.family: "sans-serif"
            font.pixelSize: 13
            Layout.fillWidth: true
        }
        Rectangle {
            implicitWidth: 36
            implicitHeight: 22
            radius: 11
            color: toggle.checked ? "#4389ee" : "#565864"
            activeFocusOnTab: true
            border.width: activeFocus ? 2 : 0
            border.color: "#bcd9ff"
            Rectangle {
                x: toggle.checked ? 17 : 3
                y: 3
                width: 16
                height: 16
                radius: 8
                color: "#f8f8fa"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggle.toggled()
            }
            Keys.onSpacePressed: toggle.toggled()
            Accessible.role: Accessible.CheckBox
            Accessible.name: toggle.title
            Accessible.checked: toggle.checked
            Accessible.onToggleAction: toggle.toggled()
        }
    }
}
