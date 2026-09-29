import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "services/Preferences.js" as Preferences

// Compose Omarchy's installed renderer instead of copying or patching it.
// Its widget/popup contract is retained, with only presentation properties changed.
Item {
    id: root
    property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null
    property var barWidgetRegistry: null
    property var barConfig: ({})
    readonly property var renderer: barLoader.item
    readonly property bool barHidden: renderer ? renderer.barHidden : false
    readonly property int barSize: renderer ? renderer.barSize : 26
    readonly property string position: "top"
    readonly property string fontFamily: "sans-serif"
    readonly property var activePopout: renderer ? renderer.activePopout : null
    readonly property string projectPath: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")
    readonly property var presentation: Preferences.presentation(barConfig, preferences.values.macLayout, projectPath + "/components/ActiveApp.qml", projectPath + "/components/AppearanceButton.qml")

    QtObject {
        id: preferences
        readonly property var values: Preferences.normalize(root.barConfig.macDesktop)
        function setValue(key, value) {
            if (!root.shell || !Object.prototype.hasOwnProperty.call(Preferences.defaults(), key))
                return;
            root.shell.mutateShellConfig(function (config) {
                var next = Preferences.normalize(config.bar.macDesktop);
                next[key] = value;
                config.bar.macDesktop = Preferences.normalize(next);
            });
        }
    }

    function configureRenderer() {
        if (!renderer)
            return;
        renderer.omarchyPath = omarchyPath;
        renderer.shell = shell;
        renderer.manifest = manifest;
        renderer.pluginRegistry = pluginRegistry;
        renderer.barWidgetRegistry = barWidgetRegistry;
        renderer.barConfig = presentation;
        renderer.fontFamily = "sans-serif";
        renderer.themeForeground = "#f4f4f7";
        renderer.transparentForeground = "#f4f4f7";
        renderer.foreground = "#f4f4f7";
        renderer.background = preferences.values.reduceTransparency || barConfig.transparent === false ? "#202127" : "#e6202127";
        renderer.urgent = "#79b8ff";
        renderer.foregroundAnimationEnabled = !preferences.values.reduceMotion;
    }
    onShellChanged: configureRenderer()
    onManifestChanged: configureRenderer()
    onBarWidgetRegistryChanged: configureRenderer()
    onPluginRegistryChanged: configureRenderer()
    onPresentationChanged: configureRenderer()
    Connections {
        target: preferences
        function onValuesChanged() {
            root.configureRenderer();
        }
    }

    Loader {
        id: barLoader
        active: root.shell !== null && root.barWidgetRegistry !== null
        source: active ? "file://" + root.omarchyPath + "/shell/plugins/bar/Bar.qml" : ""
        onLoaded: root.configureRenderer()
        onStatusChanged: if (status === Loader.Error) {
            console.error("Mac Desktop: incompatible stock bar renderer; returning to Omarchy bar.");
            if (root.shell)
                root.shell.mutateShellConfig(function (config) {
                    config.bar.id = "omarchy.bar";
                });
        }
    }

    // Host shell routes existing panel shortcuts through its active bar.
    function summonBarWidget(id) {
        return renderer ? renderer.summonBarWidget(id) : false;
    }
    function hideBarWidget(id) {
        return renderer ? renderer.hideBarWidget(id) : false;
    }
    function isBarWidgetOpen(id) {
        return renderer ? renderer.isBarWidgetOpen(id) : false;
    }
    function panelWidgetIdAt(region, index) {
        return renderer ? renderer.panelWidgetIdAt(region, index) : "";
    }
    function moduleWidgets(id) {
        return renderer ? renderer.moduleWidgets(id) : [];
    }
    function toggleTransparency() {
        if (renderer)
            renderer.toggleTransparency();
    }
    function debugBarGeometry() {
        return renderer ? renderer.debugBarGeometry() : [];
    }

    Dock {
        preferences: preferences
    }
    SettingsPanel {
        id: settingsPanel
        preferences: preferences
        projectPath: root.projectPath
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
                version: "0.1.0",
                rendererReady: !!root.renderer,
                preferences: preferences.values
            });
        }
    }
    Timer {
        interval: 1200
        running: root.renderer !== null && root.shell !== null && !preferences.values.onboarded
        onTriggered: {
            preferences.setValue("onboarded", true);
            settingsPanel.open();
        }
    }
}
