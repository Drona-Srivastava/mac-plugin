// Pure dock identity/order helpers. DesktopEntry.id is already suffix-free:
// org.telegram.desktop is an ID whose actual filename ends in .desktop.desktop.
// Never strip a suffix before trying an exact ID match.

function validId(value) {
    return typeof value === "string" && value.length > 0 && value.length < 256
            && value.charAt(0) !== "-" && !/[\x00-\x1f\x7f/\\]/.test(value);
}

function cleanPins(values) {
    var result = [];
    if (!Array.isArray(values)) return result;
    for (var i = 0; i < values.length && result.length < 40; ++i) {
        if (validId(values[i]) && result.indexOf(values[i]) === -1)
            result.push(values[i]);
    }
    return result;
}

function keyFor(value) {
    return String(value || "").toLowerCase();
}

function entryIndex(entries) {
    var index = { ids: Object.create(null), folded: Object.create(null), classes: Object.create(null) };
    for (var i = 0; i < entries.length; ++i) {
        var entry = entries[i];
        if (!entry || !validId(entry.id)) continue;
        index.ids[entry.id] = entry;
        var folded = keyFor(entry.id);
        // Ambiguous case-insensitive/class matches are deliberately not guessed.
        index.folded[folded] = index.folded[folded] === undefined ? entry : null;
        if (entry.startupClass) {
            var startup = keyFor(entry.startupClass);
            index.classes[startup] = index.classes[startup] === undefined ? entry : null;
        }
    }
    return index;
}

function entryForId(id, index) {
    if (!validId(id)) return null;
    if (index.ids[id]) return index.ids[id];
    if (index.folded[keyFor(id)]) return index.folded[keyFor(id)];
    if (id.slice(-8).toLowerCase() === ".desktop") {
        var withoutSuffix = id.slice(0, -8);
        return index.ids[withoutSuffix] || index.folded[keyFor(withoutSuffix)] || null;
    }
    return null;
}

function entryForApp(appId, index) {
    return entryForId(appId, index) || index.classes[keyFor(appId)] || null;
}

function defaultPins(entries) {
    var candidates = entries.filter(function(entry) {
        return entry && validId(entry.id) && !entry.noDisplay;
    }).slice().sort(function(a, b) {
        return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
    });
    var categories = ["FileManager", "WebBrowser", "TerminalEmulator"];
    var result = [];
    for (var c = 0; c < categories.length; ++c) {
        for (var i = 0; i < candidates.length; ++i) {
            if (candidates[i].categories && candidates[i].categories.indexOf(categories[c]) !== -1
                    && result.indexOf(candidates[i].id) === -1) {
                result.push(candidates[i].id);
                break;
            }
        }
    }
    // Minimal installations may not provide any of the conventional categories.
    if (result.length === 0 && candidates.length > 0) result.push(candidates[0].id);
    return result;
}

function buildGroups(pins, entries, toplevels) {
    var index = entryIndex(entries);
    var groups = [];
    var byKey = Object.create(null);
    function add(key, entry, appId, pinned) {
        if (byKey[key]) return byKey[key];
        var group = {
            key: key,
            desktopId: entry ? entry.id : "",
            entry: entry,
            name: entry ? (entry.name || entry.id) : (appId || "Application"),
            pinned: pinned,
            windows: []
        };
        groups.push(group);
        byKey[key] = group;
        return group;
    }
    var normalized = cleanPins(pins);
    for (var p = 0; p < normalized.length; ++p) {
        var pin = entryForId(normalized[p], index);
        // Missing entries stay in preferences (e.g. temporarily uninstalled),
        // but cannot become a fake or broken launcher in the dock.
        if (pin) add("desktop:" + pin.id, pin, pin.id, true);
    }
    var pinnedCount = groups.length;
    for (var w = 0; w < toplevels.length; ++w) {
        var top = toplevels[w];
        if (!top) continue;
        var appId = top.appId || (top.parent ? top.parent.appId : "") || "";
        var app = entryForApp(appId, index);
        // Anonymous windows must not collapse into an invented application.
        var key = app ? "desktop:" + app.id : appId ? "app:" + keyFor(appId) : "window:" + w;
        add(key, app, appId, false).windows.push(top);
    }
    var running = groups.slice(pinnedCount).sort(function(a, b) {
        var aName = keyFor(a.name), bName = keyFor(b.name);
        return aName < bName ? -1 : aName > bName ? 1 : a.key < b.key ? -1 : a.key > b.key ? 1 : 0;
    });
    return groups.slice(0, pinnedCount).concat(running);
}

function movePin(pins, id, direction) {
    var result = cleanPins(pins);
    var index = result.indexOf(id);
    var destination = index + (direction < 0 ? -1 : 1);
    if (index < 0 || destination < 0 || destination >= result.length) return result;
    var swap = result[destination];
    result[destination] = id;
    result[index] = swap;
    return result;
}

function launchCommand(id) {
    // argv only, never a shell string or a desktop Exec parser. gtk-launch
    // preserves desktop field-code, DBus activation and terminal semantics.
    return validId(id) ? ["uwsm-app", "--", "gtk-launch", id + ".desktop"] : [];
}
