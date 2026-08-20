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
        anchors.bottomMargin: root._controlsBarHeight
        visible: root.hasVideo
        source: root.source
    }

    MouseArea {
        anchors.fill: parent
        anchors.bottomMargin: root._controlsBarHeight
        visible: root.hasVideo
        onClicked: {
            keyCatcher.forceActiveFocus();
            if (player.playing)
                player.pause();
            else
                player.play();
        }
        onWheel: function (wheel) {
            var delta = wheel.angleDelta.y > 0 ? 2 : -2;
            player.volume = Math.max(0, Math.min(100, player.volume + delta));
            backend.setOption("previewVolume", player.volume);
            wheel.accepted = true;
        }
    }

    Item {
        id: keyCatcher

        anchors.fill: parent
        anchors.bottomMargin: root._controlsBarHeight
        visible: root.hasVideo
        activeFocusOnTab: true

        Keys.onPressed: function (event) {
            var seekStep = 1000;
            if (event.modifiers & Qt.ControlModifier)
                seekStep = 10000;
            else if (event.modifiers & Qt.ShiftModifier)
                seekStep = 60000;
            var seekDelta = 0;
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H)
                seekDelta = -seekStep;
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_L)
                seekDelta = seekStep;
            if (seekDelta !== 0) {
                player.position = Math.max(0, Math.min(player.duration, player.position + seekDelta));
                event.accepted = true;
                return;
            }
            var volumeDelta = 0;
            if (event.key === Qt.Key_Down || event.key === Qt.Key_J)
                volumeDelta = -2;
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_K)
                volumeDelta = 2;
            if (volumeDelta !== 0) {
                player.volume = Math.max(0, Math.min(100, player.volume + volumeDelta));
                backend.setOption("previewVolume", player.volume);
                event.accepted = true;
            }
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

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function (wheel) {
                        var delta = wheel.angleDelta.y > 0 ? 1000 : -1000;
                        player.position = Math.max(0, Math.min(player.duration, player.position + delta));
                        wheel.accepted = true;
                    }
                }
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

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function (wheel) {
                        var delta = wheel.angleDelta.y > 0 ? 2 : -2;
                        player.volume = Math.max(0, Math.min(100, player.volume + delta));
                        backend.setOption("previewVolume", player.volume);
                        wheel.accepted = true;
                    }
                }
            }

            Label {
                text: player.muted ? "🔇" : "🔊"
                color: theme.text
                verticalAlignment: Text.AlignVCenter
                Layout.fillHeight: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: player.toggleMute()
                }
            }

            Label {
                text: Math.round(player.volume) + "%"
                color: theme.text
                Layout.preferredWidth: 30
                verticalAlignment: Text.AlignVCenter
                Layout.fillHeight: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: player.toggleMute()
                }
            }
        }
    }
}
