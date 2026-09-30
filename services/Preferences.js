// Pure, deterministic settings normalization; also exercised by Node tests.
function defaults() {
    return {
        dockEnabled: true, dockAutoHide: true, dockSize: 48, dockPins: [], dockPinsInitialized: false,
        dockMonitor: "", reduceMotion: false, reduceTransparency: false,
        desktopWidgetsEnabled: true, use24HourClock: true,
        weatherEnabled: true, weatherUnit: "metric", calendarEnabled: true, systemEnabled: true, musicEnabled: true,
        macLayout: true, onboarded: false
    };
}

function normalize(raw) {
    var result = defaults();
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) return result;
    Object.keys(result).forEach(function(key) {
        if (typeof result[key] === "boolean" && typeof raw[key] === "boolean") result[key] = raw[key];
    });
    if (typeof raw.dockSize === "number" && isFinite(raw.dockSize))
        result.dockSize = Math.max(32, Math.min(72, Math.round(raw.dockSize)));
    if (typeof raw.dockMonitor === "string") result.dockMonitor = raw.dockMonitor;
    if (["metric", "imperial"].indexOf(raw.weatherUnit) !== -1) result.weatherUnit = raw.weatherUnit;
    if (Array.isArray(raw.dockPins)) {
        result.dockPins = raw.dockPins.filter(function(id, index, all) {
            return typeof id === "string" && id.length > 0 && id.length < 256 && all.indexOf(id) === index;
        }).slice(0, 40);
    }
    return result;
}

function entryId(entry) { return typeof entry === "string" ? entry : String(entry && entry.id || ""); }

// Presentation-only layout. Never overwrite the user's saved widget layout.
function presentation(config, macLayout, appSource, settingsSource) {
    var result = JSON.parse(JSON.stringify(config || {}));
    var source = result.layout || {};
    result.layout = {};
    ["left", "center", "right"].forEach(function(section) {
        result.layout[section] = Array.isArray(source[section]) ? source[section] : [];
    });
    result.position = "top";
    result.transparent = false; // The surface itself uses a controlled alpha.
    var layout = result.layout;
    if (macLayout) {
        var clocks = [];
        ["left", "center", "right"].forEach(function(section) {
            layout[section] = layout[section].filter(function(entry) {
                if (entryId(entry) === "omarchy.clock") { clocks.push(entry); return false; }
                return true;
            });
        });
        result.centerAnchor = "";
        var hasMenu = ["left", "center", "right"].some(function(section) {
            return layout[section].some(function(entry) { return entryId(entry) === "omarchy.menu"; });
        });
        if (!hasMenu) layout.left.unshift({id: "omarchy.menu"});
        var menuIndex = layout.left.findIndex(function(entry) { return entryId(entry) === "omarchy.menu"; });
        layout.left.splice(Math.max(0, menuIndex + 1), 0, {id: "drona.mac.active-app", type: "qml", source: appSource});
        layout.right = layout.right.concat([{id: "drona.mac.appearance", type: "qml", source: settingsSource}], clocks);
    } else {
        layout.right.push({id: "drona.mac.appearance", type: "qml", source: settingsSource});
    }
    return result;
}
