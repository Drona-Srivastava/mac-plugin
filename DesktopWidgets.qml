import QtQuick
import Quickshell
import "components/widgets"

Scope {
    id: root
    required property var preferences

    readonly property bool enabled: preferences.desktopWidgetsEnabled !== false
    readonly property bool reducedTransparency: preferences.reduceTransparency === true
    readonly property color surface: reducedTransparency ? "#252a33" : "#d91a2029"
    readonly property color border: "#3b9bb9c7"
    readonly property color foreground: "#f3f6fa"
    readonly property color muted: "#aab4c1"

    readonly property var targetScreen: {
        var screens = Quickshell.screens;
        if (screens.length === 0) return null;
        var name = String(preferences.dockMonitor || "");
        for (var i = 0; i < screens.length; ++i) {
            if (name && screens[i].name === name) return screens[i];
        }
        return screens[0];
    }

    readonly property bool visibleWidgets: enabled && targetScreen !== null

    ClockCard {
        screen: root.targetScreen
        visible: root.visibleWidgets
        surface: root.surface
        border: root.border
        foreground: root.foreground
        muted: root.muted
        use24Hour: root.preferences.use24HourClock !== false
    }
    WeatherCard {
        screen: root.targetScreen
        visible: root.visibleWidgets && root.preferences.weatherEnabled
        surface: root.surface
        border: root.border
        foreground: root.foreground
        muted: root.muted
        weatherUnit: root.preferences.weatherUnit
    }
    CalendarCard {
        screen: root.targetScreen
        visible: root.visibleWidgets && root.preferences.calendarEnabled
        surface: root.surface
        border: root.border
        foreground: root.foreground
        muted: root.muted
    }
    SystemCard {
        screen: root.targetScreen
        visible: root.visibleWidgets && root.preferences.systemEnabled
        surface: root.surface
        border: root.border
        foreground: root.foreground
        muted: root.muted
    }
    MusicCard {
        screen: root.targetScreen
        visible: root.visibleWidgets && root.preferences.musicEnabled
        surface: root.surface
        border: root.border
        foreground: root.foreground
        muted: root.muted
    }
}
