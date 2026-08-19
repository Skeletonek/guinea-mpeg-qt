import GuineaMpeg 1.0
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Utils/FormatUtils.js" as FormatUtils

Rectangle {
    id: root

    property url source: ""
    property bool hasVideo: false
    property int _controlsBarHeight: 30
    property alias playing: player.playing
    property alias position: player.position
    property alias duration: player.duration
    property alias volume: player.volume

    function pause() {
        player.pause();
    }

    function play() {
        player.play();
    }

    color: theme.black
    border.color: theme.widgetBorder
    border.width: 1
    clip: true

    MpvItem {
        id: player

        anchors.fill: parent
        visible: root.hasVideo
        source: root.source
    }

    MouseArea {
        anchors.fill: parent
        anchors.bottomMargin: root._controlsBarHeight
        visible: root.hasVideo
        onClicked: {
            if (player.playing)
                player.pause();
            else
                player.play();
        }
    }

    Text {
        anchors.centerIn: parent
        text: qsTr("No video loaded")
        color: theme.text
        visible: !root.hasVideo
        font.pixelSize: 18
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: root._controlsBarHeight
        color: theme.bg
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
                        player.pause();
                    else
                        player.play();
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
                text: FormatUtils.formatTime(player.position) + " / " + FormatUtils.formatTime(player.duration)
                color: theme.text
                verticalAlignment: Text.AlignVCenter
                Layout.fillHeight: true
            }

            Slider {
                from: 0
                to: 100
                value: player.volume
                Layout.preferredWidth: 60
                onMoved: {
                    player.volume = value;
                    backend.setOption("previewVolume", value);
                }
                Layout.fillHeight: true
            }

            Label {
                text: "🔊"
                color: theme.text
                verticalAlignment: Text.AlignVCenter
                Layout.fillHeight: true
            }

            Label {
                text: Math.round(player.volume) + "%"
                color: theme.text
                Layout.preferredWidth: 30
                verticalAlignment: Text.AlignVCenter
                Layout.fillHeight: true
            }
        }
    }
}
