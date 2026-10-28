import GuineaMpeg 1.0
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Components"
import "Utils/Constants.js" as Constants
import "Utils/FormatUtils.js" as FormatUtils
import "Utils/DataUtils.js" as DataUtils

Rectangle {
    id: root

    property url source: ""
    property bool hasVideo: false
    // Audio file without cover art: mpv renders nothing, so the player must
    // be hidden to avoid showing a stale frame of a previously loaded video
    property bool hasAudioOnly: false
    property string videoPath: ""
    property string profileName: ""
    property int startTimeMs: 0
    property real sourceFps: 0
    property bool previewActive: false
    property bool previewGenerating: false
    property bool previewAvailable: false
    property url previewSource: ""
    property int previewDurationMs: 5000
    property int pendingSeekMs: -1
    property int _seekRetries: 0
    property int _controlsBarHeight: 36
    property double _progress: 0
    property int _totalFrames: 0
    property alias playing: player.playing
    property alias position: player.position
    property alias duration: player.duration
    property alias volume: player.volume
    property var mainWindow: null
    // Playback track selection: indices into mainWindow.videoStreams/audioStreams
    property int _videoStreamIndex: 0
    property int _audioStreamIndex: 0

    function pause() {
        player.pause();
    }

    function play() {
        player.play();
    }

    function generatePreview() {
        player.pause();
        previewFailureBanner.hide();
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
        var durationMs = 5000;
        try {
            const opts = JSON.parse(backend.getOptions());
            if (opts.preview_duration > 0)
                durationMs = opts.preview_duration * 1000;
        } catch (e) {}
        root.previewDurationMs = durationMs;
        root._totalFrames = root.sourceFps > 0 ? Math.round(root.sourceFps * durationMs / 1000) : 0;
        root._progress = 0;
        backend.startPreview(root.videoPath, pj, root.startTimeMs, durationMs, ext);
    }

    function parseProgress() {
        var p = DataUtils.parseFrameProgress(backend.previewOutput, root._totalFrames);
        if (p >= 0 && p > root._progress)
            root._progress = p;
    }

    function cancelGeneration() {
        backend.cancelPreview();
        root.previewGenerating = false;
        previewFailureBanner.hide();
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

    function setPreviewVolume(v) {
        var c = Math.max(0, Math.min(100, v));
        root.volume = c;
        backend.setOption("previewVolume", c);
    }

    function adjustVolume(delta) {
        setPreviewVolume(player.volume + delta);
    }

    function selectPlaybackTrack(kind, index) {
        if (kind === "video")
            root._videoStreamIndex = index;
        else
            root._audioStreamIndex = index;
        // ffprobe stream lists are 0-based per type, mpv track ids are 1-based
        player.setTrack(kind === "video" ? "vid" : "aid", index + 1);
    }

    onSourceChanged: {
        root.previewActive = false;
        root.previewGenerating = false;
        root.previewAvailable = false;
        root.previewSource = "";
        previewFailureBanner.hide();
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
        visible: root.hasVideo && !root.hasAudioOnly
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

        // A new file (or the regenerated preview) starts playing mpv's default
        // tracks, so the selection state resets with it
        onSourceChanged: {
            root._videoStreamIndex = 0;
            root._audioStreamIndex = 0;
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.bottomMargin: root._controlsBarHeight
        visible: root.hasVideo
        onClicked: {
            // Leave the timeline (and any other focused control) so the global
            // seek shortcuts take over again
            root.forceActiveFocus();
            if (player.playing)
                player.pause();
            else
                player.play();
        }
        onWheel: function (wheel) {
            var delta = wheel.angleDelta.y > 0 ? 2 : -2;
            root.adjustVolume(delta);
            wheel.accepted = true;
        }
    }

    // Global seek/volume shortcuts; they yield to text inputs, popups, the timeline (trim nudge) and the splitter handle
    function seekKeysAllowed() {
        if (!root.hasVideo)
            return false;
        if (mainWindow && mainWindow.splitterFocused)
            return false;
        var fi = mainWindow ? mainWindow.activeFocusItem : null;
        while (fi) {
            if (fi instanceof TextInput || fi instanceof TextArea || fi instanceof Popup || fi instanceof TimelineControl)
                return false;
            fi = fi.parent;
        }
        return true;
    }

    function seekBy(deltaMs) {
        root.position = Math.max(0, Math.min(player.duration, player.position + deltaMs));
    }

    Shortcut {
        enabled: root.seekKeysAllowed() && !root.previewGenerating
        sequences: ["Left", "H"]
        onActivated: root.seekBy(-1000)
    }

    Shortcut {
        enabled: root.seekKeysAllowed() && !root.previewGenerating
        sequence: "Ctrl+Left"
        onActivated: root.seekBy(-10000)
    }

    Shortcut {
        enabled: root.seekKeysAllowed() && !root.previewGenerating
        sequence: "Shift+Left"
        onActivated: root.seekBy(-60000)
    }

    Shortcut {
        enabled: root.seekKeysAllowed() && !root.previewGenerating
        sequences: ["Right", "L"]
        onActivated: root.seekBy(1000)
    }

    Shortcut {
        enabled: root.seekKeysAllowed() && !root.previewGenerating
        sequence: "Ctrl+Right"
        onActivated: root.seekBy(10000)
    }

    Shortcut {
        enabled: root.seekKeysAllowed() && !root.previewGenerating
        sequence: "Shift+Right"
        onActivated: root.seekBy(60000)
    }

    Shortcut {
        enabled: root.seekKeysAllowed()
        sequences: ["Down", "J"]
        onActivated: root.adjustVolume(-2)
    }

    Shortcut {
        enabled: root.seekKeysAllowed()
        sequences: ["Up", "K"]
        onActivated: root.adjustVolume(2)
    }

    Shortcut {
        enabled: root.previewGenerating && root.seekKeysAllowed()
        sequence: "Esc"
        onActivated: root.cancelGeneration()
    }

    Text {
        anchors.centerIn: parent
        text: "🎵"
        color: theme.text
        visible: root.hasVideo && root.hasAudioOnly
        font.pixelSize: Constants.audioNoteIconSize
    }

    function volumeIconKey() {
        if (player.muted)
            return "audio-volume-muted";
        if (player.volume >= 50)
            return "audio-volume-high";
        return player.volume > 0 ? "audio-volume-medium" : "audio-volume-low";
    }

    Text {
        anchors.centerIn: parent
        text: qsTr("No video loaded")
        color: theme.text
        visible: !root.hasVideo
        font.pixelSize: Constants.noVideoPlaceholderSize
    }

    Rectangle {
        id: controlsBar

        anchors.bottom: parent.bottom
        width: parent.width
        height: root._controlsBarHeight
        color: theme.bg
        visible: root.hasVideo

        RowLayout {
            id: controlsRow

            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            IconButton {
                text: player.playing ? qsTr("Pause") : qsTr("Play")
                icon.name: player.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                icon.source: player.playing ? "/media/icons/media-playback-pause.png" : "/media/icons/media-playback-start.png"
                onClicked: {
                    if (player.playing)
                        player.pause();
                    else
                        player.play();
                }
                Layout.preferredWidth: 40
                Layout.fillHeight: true
            }

            Slider {
                from: 0
                to: player.duration
                value: player.position
                onMoved: root.position = value
                Layout.fillWidth: true
                Layout.fillHeight: true

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function (wheel) {
                        var delta = wheel.angleDelta.y > 0 ? 1000 : -1000;
                        root.position = Math.max(0, Math.min(player.duration, player.position + delta));
                        wheel.accepted = true;
                    }
                }
            }

            Label {
                text: FormatUtils.formatTimePrecise(player.position, root.sourceFps) + " / " + FormatUtils.formatTimePrecise(player.duration, root.sourceFps)
                color: theme.text
                verticalAlignment: Text.AlignVCenter
                Layout.fillHeight: true
            }

            IconButton {
                text: qsTr("Regenerate")
                icon.name: "view-refresh-symbolic"
                icon.source: "/media/icons/view-refresh.png"
                visible: root.previewActive
                enabled: !root.previewGenerating
                Layout.preferredWidth: 40
                Layout.fillHeight: true
                onClicked: root.generatePreview()
            }

            Button {
                text: root.previewActive ? qsTr("Preview Mode") : qsTr("Source Mode")
                enabled: root.previewActive || !root.previewGenerating
                Layout.fillHeight: true
                onClicked: root.togglePreview()

                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: root.previewActive ? qsTr("Playing a short clip encoded with the current settings. Click to return to the original source video.") : qsTr("Playing the original source video. Click to switch to a short clip encoded with the current settings.")
            }

            IconButton {
                id: streamButton

                flat: true
                text: qsTr("Playback Streams")
                icon.name: "view-media-track-symbolic"
                icon.source: "/media/icons/view-media-track.png"
                visible: root.hasVideo
                    && ((mainWindow && mainWindow.videoStreams.length > 1) || (mainWindow && mainWindow.audioStreams.length > 1))
                enabled: !root.previewGenerating
                onClicked: playbackStreamsPopup.visible ? playbackStreamsPopup.close() : playbackStreamsPopup.open()
                Layout.preferredWidth: 40
                Layout.fillHeight: true
            }

            IconButton {
                flat: true
                text: player.muted ? qsTr("Unmute") : qsTr("Mute")
                icon.name: root.volumeIconKey() + "-symbolic"
                icon.source: "/media/icons/" + root.volumeIconKey() + ".png"
                onClicked: player.toggleMute()
                Layout.preferredWidth: 40
                Layout.fillHeight: true
            }

            Slider {
                from: 0
                to: 100
                value: player.volume
                Layout.preferredWidth: 110
                onMoved: root.setPreviewVolume(value)
                Layout.fillHeight: true

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function (wheel) {
                        var delta = wheel.angleDelta.y > 0 ? 2 : -2;
                        root.adjustVolume(delta);
                        wheel.accepted = true;
                    }
                }
            }

            Label {
                text: Math.round(player.volume) + "%"
                color: theme.text
                Layout.preferredWidth: 25
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

    // Modal with a transparent dimmer: a non-modal popup's close-on-press races with the button's click and re-opens it
    Popup {
        id: playbackStreamsPopup

        parent: root
        // Bindings, not onAboutToShow: the popup must be placed after its content height is measured
        x: controlsRow.x + streamButton.x + streamButton.width - width
        y: root.height - root._controlsBarHeight - implicitHeight - 8
        width: Constants.dialogWidthSmall
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 8
        Overlay.modal: Rectangle {
            color: "transparent"
        }

        background: Rectangle {
            color: theme.bg
            border.color: theme.widgetBorder
            border.width: 1
        }

        Column {
            spacing: 8

            Label {
                text: qsTr("Video")
                color: theme.textMuted
                font.bold: true
                font.pixelSize: 14
                visible: mainWindow && mainWindow.videoStreams.length > 1
            }

            StreamSelector {
                streams: mainWindow ? mainWindow.videoStreams : []
                kind: "video"
                selection: [root._videoStreamIndex]
                onToggled: function (index, checked) {
                    if (checked)
                        root.selectPlaybackTrack("video", index);
                }
            }

            Label {
                text: qsTr("Audio")
                color: theme.textMuted
                font.bold: true
                font.pixelSize: 14
                visible: mainWindow && mainWindow.audioStreams.length > 1
            }

            StreamSelector {
                streams: mainWindow ? mainWindow.audioStreams : []
                kind: "audio"
                selection: [root._audioStreamIndex]
                onToggled: function (index, checked) {
                    if (checked)
                        root.selectPlaybackTrack("audio", index);
                }
            }
        }
    }

    InfoBanner {
        id: previewFailureBanner

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root._controlsBarHeight + 8
        text: qsTr("Preview generation failed")
        subText: backend.lastPreviewError
        autoHideMs: 8000
        visible: false
        z: 10
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
            id: previewBusyLabel

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: previewSpinner.bottom
            anchors.topMargin: 8
            text: qsTr("Generating preview…")
            color: theme.text
            font.pixelSize: Constants.previewGeneratingTextSize
        }

        RowLayout {
            id: progressRow

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: previewBusyLabel.bottom
            anchors.topMargin: 16
            width: Math.min(parent.width - 32, Constants.dialogWidthMedium)
            spacing: 8

            ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: 1
                value: root._progress
            }

            Label {
                text: Math.round(root._progress * 100) + "%"
                color: theme.text
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
            }
        }

        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: progressRow.bottom
            anchors.topMargin: 8
            text: qsTr("Cancel")
            onClicked: root.cancelGeneration()
        }
    }

    Connections {
        target: backend

        function onPreviewOutputUpdated() {
            root.parseProgress();
        }

        function onPreviewGenerated(path) {
            var url = DataUtils.toFileUrl(path);
            // The preview reuses one fixed file: when the player already shows
            // this URL the source binding won't re-fire, so reload explicitly.
            var needsReload = root.previewActive && String(root.previewSource) === String(url);
            root.previewGenerating = false;
            root.previewSource = url;
            root.previewAvailable = true;
            root.previewActive = true;
            if (needsReload)
                player.reload();
        }

        function onPreviewFailed() {
            root.previewGenerating = false;
            root.previewAvailable = false;
            root.previewActive = false;
            previewFailureBanner.show();
        }
    }
}
