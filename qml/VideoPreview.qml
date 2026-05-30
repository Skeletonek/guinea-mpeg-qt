import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GuineaMpeg 1.0

Rectangle {
    id: root
    color: "black"
    border.color: "#555"
    border.width: 1
    clip: true

    property url source: ""
    property bool hasVideo: false

    property alias playing: player.playing
    property alias position: player.position
    property alias duration: player.duration
    property alias volume: player.volume

    MpvItem {
        id: player
        anchors.fill: parent
        visible: root.hasVideo
        source: root.source
    }

    Text {
        anchors.centerIn: parent
        text: "No video loaded"
        color: "white"
        visible: !root.hasVideo
        font.pixelSize: 18
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 30
        color: "#80000000"
        visible: root.hasVideo

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            Button {
                text: player.playing ? "⏸" : "▶"
                Layout.preferredWidth: 40
                onClicked: {
                    if (player.playing)
                        player.pause()
                    else
                        player.play()
                }
                Layout.fillHeight: true
            }

            Slider {
                from: 0
                to: player.duration
                value: player.position
                onMoved: player.position = value
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            Label {
                text: formatTime(player.position) + " / " + formatTime(player.duration)
                color: "white"
                verticalAlignment: Text.AlignVCenter
                Layout.fillHeight: true
            }

            Label {
                text: "🔊"
                color: "white"
                verticalAlignment: Text.AlignVCenter
                Layout.fillHeight: true
            }

            Slider {
                from: 0
                to: 100
                value: player.volume
                Layout.preferredWidth: 60
                onMoved: player.volume = value
                Layout.fillHeight: true
            }

            Label {
                text: Math.round(player.volume) + "%"
                color: "white"
                Layout.preferredWidth: 30
                verticalAlignment: Text.AlignVCenter
                Layout.fillHeight: true
            }
        }
    }

    function formatTime(ms) {
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        s = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }
}
