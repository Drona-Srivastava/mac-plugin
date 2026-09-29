import QtQuick
import Quickshell

// Copied into a temporary shell root by scripts/smoke-test.
ShellRoot {
    id: root
    property bool loaded: false
    property var rendererComponent: null
    QtObject {
        id: fakeShell
        function mutateShellConfig(mutator) {
            return false;
        }
        function firstPartyServiceFor(id) {
            return null;
        }
        function pluginShellForBarEntry(owner, name) {
            return null;
        }
    }
    QtObject {
        id: catalog
        property var widgets: ({})
        property int revision: 0
        function metadataFor(id) {
            return null;
        }
    }
    Loader {
        id: loader
        Component.onCompleted: setSource("file://" + Quickshell.env("MAC_PLUGIN_SOURCE") + "/Bar.qml", {
            barConfig: {
                layout: {
                    left: [],
                    center: [],
                    right: []
                },
                macDesktop: {
                    onboarded: true,
                    dockEnabled: false
                }
            }
        })
        onLoaded: {
            // Leave shell unset: no replacement bar or desktop surface is mapped.
            root.rendererComponent = Qt.createComponent("file://" + item.omarchyPath + "/shell/plugins/bar/Bar.qml");
            root.loaded = true;
        }
        onStatusChanged: if (status === Loader.Error) {
            console.error("MAC_PLUGIN_SMOKE_FAILED");
            Qt.quit();
        }
    }
    Timer {
        interval: 2500
        running: true
        onTriggered: {
            if (!root.loaded || !root.rendererComponent || root.rendererComponent.status !== Component.Ready)
                console.error("MAC_PLUGIN_SMOKE_FAILED", root.rendererComponent ? root.rendererComponent.errorString() : "not loaded");
            else
                console.log("MAC_PLUGIN_SMOKE_OK");
            Qt.quit();
        }
    }
}
