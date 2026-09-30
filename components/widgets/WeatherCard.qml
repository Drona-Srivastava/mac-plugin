import QtQuick
import Quickshell
import Quickshell.Io

WidgetWindow {
    id: root
    property color surface: "#d91a2029"
    property color border: "#3b9bb9c7"
    property color foreground: "#f3f6fa"
    property color muted: "#aab4c1"
    property string weatherUnit: "metric"
    property string locationName: ""
    property string currentText: "Checking forecast..."
    property string conditionText: ""
    property string rangeText: ""
    property bool hasResult: false
    property double latitude: NaN
    property double longitude: NaN
    cardHeight: 88
    topOffset: 138
    visible: screen !== null
    onWeatherUnitChanged: if (root.visible) root.refresh()

    function loadLocation(raw) {
        try {
            var location = JSON.parse(String(raw || "{}"));
            root.locationName = typeof location.name === "string" ? location.name : "";
            var lat = parseFloat(location.latitude);
            var lon = parseFloat(location.longitude);
            root.latitude = isFinite(lat) ? lat : NaN;
            root.longitude = isFinite(lon) ? lon : NaN;
        } catch (error) {
            root.latitude = NaN;
            root.longitude = NaN;
        }
        if (root.visible) refresh();
    }

    function refresh() {
        if (isFinite(latitude) && isFinite(longitude)) {
            var units = weatherUnit === "imperial" ? "fahrenheit" : "celsius";
            var url = "https://api.open-meteo.com/v1/forecast?latitude=" + encodeURIComponent(latitude)
                + "&longitude=" + encodeURIComponent(longitude)
                + "&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min"
                + "&temperature_unit=" + units + "&forecast_days=1&timezone=auto";
            forecastProcess.command = ["curl", "-fsS", "--max-time", "5", url];
            forecastProcess.running = true;
        } else if (!statusProcess.running) {
            statusProcess.command = ["omarchy-weather-status"];
            statusProcess.running = true;
        }
    }

    function describeCode(code) {
        if (code === 0) return "Clear sky";
        if (code === 1) return "Mostly clear";
        if (code === 2) return "Partly cloudy";
        if (code === 3) return "Overcast";
        if (code === 45 || code === 48) return "Fog";
        if (code >= 51 && code <= 57) return "Drizzle";
        if (code >= 61 && code <= 67) return "Rain";
        if (code >= 71 && code <= 77) return "Snow";
        if (code >= 80 && code <= 82) return "Showers";
        if (code >= 85 && code <= 86) return "Snow showers";
        if (code >= 95) return "Thunderstorm";
        return "Conditions unavailable";
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.loadLocation(text())
        onFileChanged: reload()
        onLoadFailed: if (root.visible) root.refresh()
    }
    Process {
        id: forecastProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var report = JSON.parse(String(text || "{}"));
                    var current = report.current;
                    var daily = report.daily;
                    if (!current || !daily || !daily.temperature_2m_max || !daily.temperature_2m_min)
                        throw new Error("Incomplete forecast");
                    var suffix = root.weatherUnit === "imperial" ? "°F" : "°C";
                    root.currentText = Math.round(current.temperature_2m) + suffix;
                    root.conditionText = root.describeCode(Number(current.weather_code));
                    root.rangeText = "H " + Math.round(daily.temperature_2m_max[0]) + "°  ·  L "
                        + Math.round(daily.temperature_2m_min[0]) + "°";
                    root.hasResult = true;
                } catch (error) {
                    if (!root.hasResult) root.currentText = "Forecast unavailable";
                }
            }
        }
    }
    Process {
        id: statusProcess
        stdout: StdioCollector {
            onStreamFinished: {
                var result = String(text || "").trim();
                if (isFinite(root.latitude) && isFinite(root.longitude)) return;
                if (result) {
                    root.currentText = result;
                    root.conditionText = "Set a city in Omarchy Weather for highs and lows";
                    root.rangeText = "";
                    root.hasResult = true;
                } else if (!root.hasResult) {
                    root.currentText = "Set a location in Omarchy Weather";
                }
            }
        }
    }
    Timer {
        interval: 1800000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    WidgetCard {
        anchors.fill: parent
        surface: root.surface
        outlineColor: root.border
        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 3
            Text {
                text: root.locationName
                    ? root.locationName.toUpperCase() + " · OPEN-METEO"
                    : "WEATHER · OMARCHY"
                color: "#7bc8df"
                font.pixelSize: 8
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Row {
                width: parent.width
                spacing: 8
                Text {
                    text: root.currentText
                    color: root.foreground
                    font.family: "sans-serif"
                    font.pixelSize: 18
                    font.weight: Font.Medium
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text { text: root.conditionText; color: root.muted; font.pixelSize: 9 }
                    Text { text: root.rangeText; color: root.muted; font.pixelSize: 9 }
                }
            }
        }
    }
}
