pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris

WidgetWindow {
    id: root
    property color surface: "#d91a2029"
    property color border: "#3b9bb9c7"
    property color foreground: "#f3f6fa"
    property color muted: "#aab4c1"
    property var players: Mpris.players ? Mpris.players.values : []
    readonly property var activePlayer: {
        for (var i = 0; i < players.length; i++) if (players[i].isPlaying) return players[i];
        return players.length ? players[0] : null;
    }
    cardWidth: 286
    cardHeight: 126
    topOffset: 24
    leftOffset: Math.max(286, screen ? screen.width - 304 : 286)
    visible: screen !== null

    WidgetCard {
        anchors.fill: parent
        surface: root.surface
        outlineColor: root.border
        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            Rectangle {
                id: artworkBox
                width: 72
                height: 72
                radius: 9
                color: "#33334658"
                clip: true
                Image {
                    id: artwork
                    anchors.fill: parent
                    source: root.activePlayer ? root.activePlayer.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    text: "♪"
                    color: "#93d6e6"
                    font.pixelSize: 28
                    visible: !artwork.visible
                }
            }
            Column {
                width: parent.width - 84
                spacing: 5
                Text {
                    text: "NOW PLAYING"
                    color: "#c69ce8"
                    font.pixelSize: 8
                    font.letterSpacing: 0.9
                }
                Text {
                    width: parent.width
                    text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown track") : "No music player"
                    color: root.foreground
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.activePlayer ? (root.activePlayer.trackArtist || root.activePlayer.identity || "") : "MPRIS players appear here"
                    color: root.muted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                Rectangle {
                    width: parent.width
                    height: 3
                    radius: 2
                    color: "#3b4652"
                    Rectangle {
                        width: parent.width * (root.activePlayer && root.activePlayer.length > 0
                            ? Math.max(0, Math.min(1, root.activePlayer.position / root.activePlayer.length)) : 0)
                        height: parent.height
                        radius: 2
                        color: "#8bd0e1"
                    }
                }
                Row {
                    spacing: 14
                    Text {
                        text: "|◀"
                        color: root.activePlayer && root.activePlayer.canGoPrevious ? root.foreground : root.muted
                        font.pixelSize: 15
                        MouseArea { anchors.fill: parent; onClicked: if (root.activePlayer && root.activePlayer.canGoPrevious) root.activePlayer.previous() }
                    }
                    Text {
                        text: root.activePlayer && root.activePlayer.isPlaying ? "Ⅱ" : "▶"
                        color: root.activePlayer && root.activePlayer.canTogglePlaying ? "#8bd0e1" : root.muted
                        font.pixelSize: 16
                        MouseArea { anchors.fill: parent; onClicked: if (root.activePlayer && root.activePlayer.canTogglePlaying) root.activePlayer.togglePlaying() }
                    }
                    Text {
                        text: "▶|"
                        color: root.activePlayer && root.activePlayer.canGoNext ? root.foreground : root.muted
                        font.pixelSize: 15
                        MouseArea { anchors.fill: parent; onClicked: if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next() }
                    }
                }
            }
        }
    }
}
