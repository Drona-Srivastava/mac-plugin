import QtQuick
import Quickshell
import Quickshell.Io
import "renderer" as Native
import "components"
import "services/Preferences.js" as Preferences

// Inherit the scoped local clone directly so Omarchy's active bar is the actual
// renderer. No nested stock-bar Loader or cross-instance component contexts.
Native.Bar {
    id: macRoot
    readonly property string projectPath: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")

    fontFamily: "sans-serif"
    themeForeground: "#f4f4f7"
    transparentForeground: "#f4f4f7"
    foreground: "#f4f4f7"
    background: preferences.values.reduceTransparency ? "#252631" : "#59202032"
    urgent: "#79b8ff"
    foregroundAnimationEnabled: !preferences.values.reduceMotion
    toggleAppearanceTransparency: function () {
        preferences.setValue("reduceTransparency", !preferences.values.reduceTransparency);
    }
    transformBarConfig: function (config) {
        return Preferences.presentation(config, Preferences.normalize(config.macDesktop).macLayout, macRoot.projectPath + "/components/ActiveApp.qml", macRoot.projectPath + "/components/AppearanceButton.qml");
    }

    QtObject {
        id: preferences
        readonly property var values: Preferences.normalize(macRoot.barConfig.macDesktop)
        function setValue(key, value) {
            if (!macRoot.shell || !Object.prototype.hasOwnProperty.call(Preferences.defaults(), key))
                return;
            macRoot.shell.mutateShellConfig(function (config) {
                var next = Preferences.normalize(config.bar.macDesktop);
                next[key] = value;
                config.bar.macDesktop = Preferences.normalize(next);
            });
        }
    }
    Connections {
        target: preferences
        function onValuesChanged() {
            Qt.callLater(macRoot.applyBarConfig);
        }
    }

    Dock {
        preferences: preferences
    }
    SettingsPanel {
        id: settingsPanel
        preferences: preferences
        projectPath: macRoot.projectPath
    }
    IpcHandler {
        target: "drona-mac"
        function settings(): void {
            settingsPanel.toggle();
        }
        function closeSettings(): void {
            settingsPanel.visible = false;
        }
        function setPreference(key: string, valueJson: string): string {
            if (!Object.prototype.hasOwnProperty.call(Preferences.defaults(), key))
                return "unknown setting";
            try {
                var value = JSON.parse(valueJson);
                var expected = Preferences.defaults()[key];
                if (Array.isArray(expected) ? !Array.isArray(value) : typeof expected !== typeof value)
                    return "invalid type";
                preferences.setValue(key, value);
                return "ok";
            } catch (error) {
                return "invalid JSON";
            }
        }
        function status(): string {
            return JSON.stringify({
                version: "0.1.1",
                rendererReady: true,
                widgetCount: macRoot.moduleSlots.length,
                audioPanelReady: !!macRoot.findPanelWidget("omarchy.audio"),
                preferences: preferences.values
            });
        }
    }
    // Omarchy 4.0.4 can retain component contexts owned by the previous bar.
    // If its configured logo widget is blank after settling, request ONE bounded
    // catalog rescan. The helper's runtime-only cooldown prevents reload loops.
    Timer {
        interval: 1800
        running: macRoot.shell !== null && macRoot.surfacesEnabled
        onTriggered: {
            var configured = ["left", "center", "right"].some(function (section) {
                var entries = macRoot.barConfig.layout ? macRoot.barConfig.layout[section] || [] : [];
                return entries.some(function (entry) {
                    return Preferences.entryId(entry) === "omarchy.menu";
                });
            });
            var ready = macRoot.moduleWidgets("omarchy.menu").some(function (widget) {
                return widget && widget.implicitWidth > 0;
            });
            if (configured && !ready) {
                console.warn("Mac Desktop: refreshing stale widget catalog after bar switch.");
                Quickshell.execDetached(["python3", macRoot.projectPath + "/scripts/refresh-widget-catalog"]);
            } else if (ready) {
                Quickshell.execDetached(["python3", macRoot.projectPath + "/scripts/refresh-widget-catalog", "--reset"]);
            }
        }
    }
    Timer {
        interval: 4000
        running: macRoot.shell !== null && !preferences.values.onboarded
        onTriggered: {
            preferences.setValue("onboarded", true);
            settingsPanel.open();
        }
    }
}
