import GuineaMpeg 1.0
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Utils/FormatUtils.js" as FormatUtils
import "Utils/DataUtils.js" as DataUtils

Rectangle {
    id: root

    property url source: ""
    property bool hasVideo: false
    property string videoPath: ""
    property string profileName: ""
    property int startTimeMs: 0
    property bool previewActive: false
    property bool previewGenerating: false
    property bool previewAvailable: false
    property url previewSource: ""
    property int pendingSeekMs: -1
    property int _seekRetries: 0
    property int _controlsBarHeight: 36
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

    function generatePreview() {
        player.pause();
        var pj = backend.loadProfile(root.profileName);
        if (!pj)
            return;
        var ext = "";
        try {
            ext = DataUtils.getExtensionForProfile(JSON.parse(pj));
        } catch (e) {
            ext = "";
        }
        root.previewAvailable = false;
        root.previewGenerating = true;
        backend.startPreview(root.videoPath, pj, root.startTimeMs, 5000, ext);
    }

    function togglePreview() {
        if (root.previewActive) {
            root.pendingSeekMs = root.startTimeMs;
            root.previewActive = false;
            return;
        }
        root.pendingSeekMs = -1;
        if (root.previewAvailable) {
            root.previewActive = true;
            return;
        }
        root.generatePreview();
    }

    onSourceChanged: {
        root.previewActive = false;
        root.previewGenerating = false;
        root.previewAvailable = false;
        root.previewSource = "";
        backend.cancelPreview();
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
        source: root.previewActive ? root.previewSource : root.source

        onDurationChanged: {
            if (root.pendingSeekMs >= 0 && duration > 0) {
                position = root.pendingSeekMs;
                root._seekRetries = 0;
            }
        }

        onPositionChanged: {
            if (root.pendingSeekMs < 0 || duration <= 0)
                return;
            if (position < 500 && root.pendingSeekMs > 1000 && root._seekRetries < 5) {
                position = root.pendingSeekMs;
                root._seekRetries++;
            } else {
                root.pendingSeekMs = -1;
            }
        }
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

            Button {
                text: root.previewActive ? qsTr("Preview Mode") : qsTr("Source Mode")
                enabled: root.previewActive || !root.previewGenerating
                Layout.fillHeight: true
                onClicked: root.togglePreview()
            }

            Button {
                text: qsTr("Regenerate")
                visible: root.previewActive
                enabled: !root.previewGenerating
                Layout.fillHeight: true
                onClicked: root.generatePreview()
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

    Rectangle {
        id: previewBusy

        anchors.fill: parent
        color: theme.black
        opacity: 0.7
        visible: root.previewGenerating

        BusyIndicator {
            id: previewSpinner

            running: root.previewGenerating
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -16
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: previewSpinner.bottom
            anchors.topMargin: 8
            text: qsTr("Generating preview…")
            color: theme.text
            font.pixelSize: 14
        }
    }

    Connections {
        target: backend

        function onPreviewGenerated(path) {
            root.previewGenerating = false;
            root.previewSource = "file://" + encodeURI(path);
            root.previewAvailable = true;
            root.previewActive = true;
        }

        function onPreviewFailed() {
            root.previewGenerating = false;
            root.previewAvailable = false;
            root.previewActive = false;
        }
    }
}
