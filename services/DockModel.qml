import QtQuick
import Quickshell
import Quickshell.Wayland
import "DockHelpers.js" as DockHelpers

// One model per Dock instance. All state is bounded by the installed application
// list, current toplevel list and at most 40 pins; no polling or window history.
Scope {
    id: root

    property var preferences: null
    readonly property var values: preferences && preferences.values ? preferences.values : ({})
    readonly property bool canPersist: !!preferences && typeof preferences.setValue === "function"
    readonly property var entries: DesktopEntries.applications.values
    readonly property var storedPins: DockHelpers.cleanPins(values.dockPins)
    // Optional persistence marker distinguishes first run from intentionally
    // empty. Hosts should preserve dockPinsInitialized (default false).
    readonly property var pins: storedPins.length > 0 || values.dockPinsInitialized === true ? storedPins : DockHelpers.defaultPins(entries)
    readonly property var groups: DockHelpers.buildGroups(pins, entries, ToplevelManager.toplevels.values)
    property string launchError: ""

    function groupFor(key) {
        for (var i = 0; i < root.groups.length; ++i) {
            if (root.groups[i].key === key)
                return root.groups[i];
        }
        return null;
    }

    function installedEntry(id) {
        return DockHelpers.entryForId(id, DockHelpers.entryIndex(root.entries));
    }

    function focusWindow(toplevel) {
        // A menu can outlive its selected window; never act on stale objects.
        if (!toplevel || ToplevelManager.toplevels.values.indexOf(toplevel) === -1)
            return false;
        toplevel.activate();
        return true;
    }

    function launch(id) {
        var entry = root.installedEntry(id);
        if (!entry)
            return false;
        var command = DockHelpers.launchCommand(entry.id);
        if (command.length === 0)
            return false;
        root.launchError = "";
        try {
            // This is the requested foreground app, not a detached helper daemon.
            Quickshell.execDetached(command);
            return true;
        } catch (error) {
            root.launchError = "Could not launch " + (entry.name || entry.id);
            console.warn("Mac dock:", root.launchError, String(error));
            return false;
        }
    }

    function savePins(next) {
        if (!root.canPersist)
            return;
        root.preferences.setValue("dockPins", DockHelpers.cleanPins(next));
        root.preferences.setValue("dockPinsInitialized", true);
    }

    function togglePin(key) {
        var group = root.groupFor(key);
        if (!group || !group.entry || !root.canPersist)
            return;
        // Canonicalize old suffix-bearing settings while retaining missing IDs.
        var next = root.pins.map(function (id) {
            var entry = root.installedEntry(id);
            return entry ? entry.id : id;
        });
        if (group.pinned) {
            next = next.filter(function (id) {
                return id !== group.desktopId;
            });
        } else if (next.length < 40) {
            next.push(group.desktopId);
        }
        root.savePins(next);
    }

    function movePin(key, direction) {
        var group = root.groupFor(key);
        if (!group || !group.pinned)
            return;
        var canonical = root.pins.map(function (id) {
            var entry = root.installedEntry(id);
            return entry ? entry.id : id;
        });
        root.savePins(DockHelpers.movePin(canonical, group.desktopId, direction));
    }

    function iconSource(entry) {
        var icon = entry ? String(entry.icon || "") : "";
        if (icon.charAt(0) === "/")
            return "file://" + icon.split("/").map(encodeURIComponent).join("/");
        // Desktop entries specify icon names or absolute paths, not remote URLs.
        if (icon.indexOf("://") !== -1)
            icon = "";
        return Quickshell.iconPath(icon || "application-x-executable", "application-x-executable");
    }
}
