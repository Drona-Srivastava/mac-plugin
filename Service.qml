import QtQuick
import "services/Preferences.js" as Preferences

// The service owns persistent desktop layer surfaces independently of the bar.
Item {
    id: root
    property var shell: null

    readonly property var preferences: {
        var config = shell && shell.barConfig ? shell.barConfig.macDesktop : null;
        return Preferences.normalize(config);
    }

    DesktopWidgets {
        preferences: root.preferences
    }
}
