import "Components"
import "Dialogs"
import GuineaMpeg 1.0
import QtQuick
import QtQuick.Controls
import "Utils/Constants.js" as Constants
import "Utils/DataUtils.js" as DataUtils
import "Utils/FormatUtils.js" as FormatUtils

ApplicationWindow {
    id: appWindow

    property string currentVideoPath: ""
    property var currentVideoInfo: ({})
    property string currentProfile: "H.264 High"
    property string currentCodec: Constants.codecKeys[0]
    property int videoDuration: 0
    property int startTime: 0
    property int endTime: 0
    property string videoInfoText: qsTr("Load a video file to see information")
    property string outputFilePath: ""
    property bool settingTimeline: false
    property url videoSource: ""
    property var videoStreams: []
    property var audioStreams: []
    property var selectedVideoIndices: []
    property var selectedAudioIndices: []
    property var transcodeQueue: []
    property var activeJob: null

    function loadVideo(filePath, fileUrl) {
        currentVideoPath = filePath;
        appWindow.videoSource = fileUrl || ("file://" + encodeURI(filePath));
        var info = backend.getVideoInfo(filePath);
        currentVideoInfo = info;
        videoDuration = Math.round(info.duration * 1000);
        settingTimeline = true;
        startTime = 0;
        endTime = videoDuration;
        settingTimeline = false;
        videoStreams = info.video_streams || [];
        audioStreams = info.audio_streams || [];
        var vi = [];
        for (var v = 0; v < videoStreams.length; v++)
            vi.push(v);
        selectedVideoIndices = vi;
        var ai = [];
        for (var a = 0; a < audioStreams.length; a++)
            ai.push(a);
        selectedAudioIndices = ai;
        var name = FormatUtils.getFilename(filePath);
        var fps = FormatUtils.formatFps(info.fps || "0/1");
        videoInfoText = qsTr("File: %1\nDuration: %2s\nResolution: %3x%4\nFPS: %5\nVideo: %6\nAudio: %7").arg(name).arg(info.duration.toFixed(1)).arg(info.width).arg(info.height).arg(fps).arg(info.codec).arg(info.audio_codec || "N/A");
        var base = FormatUtils.getBaseFilename(name);
        var dir = FormatUtils.getDirectory(filePath);
        var profileData = {};
        try {
            profileData = JSON.parse(backend.loadProfile(currentProfile));
        } catch (e) {}
        appWindow.outputFilePath = dir + base + "_transcoded." + getExtensionForProfile(profileData);
    }

    function getExtensionForProfile(d) {
        if (d.container)
            return d.container;

        if (d.video_enabled !== false)
            return Constants.profileExtensions[d.codec] || "webm";

        return Constants.audioExtensions[d.audio_codec] || "ogg";
    }

    function updateCodec() {
        var d;
        try {
            d = JSON.parse(backend.loadProfile(currentProfile));
            currentCodec = d.codec || Constants.codecKeys[0];
        } catch (e) {
            currentCodec = Constants.codecKeys[0];
        }
        var ext = getExtensionForProfile(d || {});
        var dot = appWindow.outputFilePath.lastIndexOf(".");
        appWindow.outputFilePath = appWindow.outputFilePath.substring(0, dot >= 0 ? dot : 0) + "." + ext;
    }

    function startTranscoding() {
        if (appWindow.outputFilePath === "") {
            videoInfoText = qsTr("Please set an output file path first");
            return;
        }
        if (backend.fileExists(appWindow.outputFilePath)) {
            overwriteDialog.filePath = appWindow.outputFilePath;
            overwriteDialog.open();
            return;
        }
        enqueueTranscoding();
    }

    function enqueueTranscoding() {
        var profile = JSON.parse(backend.loadProfile(currentProfile));
        if (selectedVideoIndices.length > 0)
            profile.video_stream_indices = selectedVideoIndices;

        if (selectedAudioIndices.length > 0)
            profile.audio_stream_indices = selectedAudioIndices;

        var job = {
            "input": currentVideoPath,
            "output": appWindow.outputFilePath,
            "start": startTime / 1000,
            "end": endTime / 1000,
            "profile": JSON.stringify(profile),
            "targetFps": profile.framerate || 0,
            "sourceFps": FormatUtils.fpsToDecimal(currentVideoInfo.fps || "") || 0,
            "durationMs": endTime - startTime
        };
        transcodeQueue = transcodeQueue.concat([job]);
        processTranscodeQueue();
    }

    function processTranscodeQueue() {
        if (activeJob !== null || transcodeQueue.length === 0)
            return;

        var job = transcodeQueue[0];
        activeJob = job;
        backend.startTranscode(job.input, job.output, job.start, job.end, job.profile);
        transcodeDialog.open();
    }

    width: 1024
    height: 800
    minimumWidth: 900
    minimumHeight: 700
    visible: true
    title: "GuineaMPEG"
    Component.onCompleted: {
        if (!mpvAvailable)
            mpvWarningDialog.open();
        else if (!ffmpegAvailable)
            ffmpegWarningDialog.open();
        else if (initialFilePath !== "")
            appWindow.loadVideo(initialFilePath);
    }

    StackView {
        id: stackView

        anchors.fill: parent
        initialItem: mainPage

        Component {
            id: mainPage

            Rectangle {
                width: stackView.width
                height: stackView.height
                color: theme.bg
                property int _panelWidth: Constants.controlsPanelDefaultWidth
                property bool _panelCollapsed: false
                property int _panelStartWidth: 0
                property int _panelStartX: 0
                StackView.onActivated: {
                    controlsPanel.refreshProfiles();
                    appWindow.updateCodec();
                }

                DropArea {
                    anchors.fill: parent
                    onEntered: dragOverlay.visible = true
                    onExited: dragOverlay.visible = false
                    onDropped: function (drop) {
                        dragOverlay.visible = false;
                        var url = String(drop.urls[0]);
                        if (url.length === 0)
                            return;

                        var path = DataUtils.toLocalPath(url);
                        appWindow.loadVideo(path, url);
                    }
                }

                Rectangle {
                    id: dragOverlay

                    anchors.fill: parent
                    color: theme.accent
                    opacity: 0.15
                    visible: false
                    border.color: theme.accent
                    border.width: 3
                    z: 100
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 0

                    VideoPreview {
                        id: player

                        width: Math.max(100, parent.width - splitterHandle.width - controlsPanel.width)
                        height: parent.height
                        source: appWindow.videoSource
                        hasVideo: currentVideoPath !== ""
                    }

                    Item {
                        id: splitterHandle

                        width: Constants.splitterHandleWidth
                        height: parent.height
                        activeFocusOnTab: true

                        Rectangle {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 1
                            color: "transparent"
                        }

                        Label {
                            anchors.centerIn: parent
                            text: "«"
                            color: theme.accent
                            font.bold: true
                            font.pixelSize: 12
                            visible: _panelCollapsed
                            rotation: 0
                        }

                        MouseArea {
                            id: splitterMouse

                            anchors.fill: parent
                            cursorShape: _panelCollapsed ? Qt.PointingHandCursor : Qt.SplitHCursor
                            onPressed: function(mouse) {
                                _panelStartX = splitterMouse.mapToItem(null, mouse.x, 0).x;
                                _panelStartWidth = controlsPanel.width;
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed || _panelCollapsed)
                                    return;

                                var newW = _panelStartWidth - Math.round(splitterMouse.mapToItem(null, mouse.x, 0).x - _panelStartX);
                                if (newW < Constants.controlsPanelCollapseThreshold) {
                                    _panelCollapsed = true;
                                    _panelWidth = 0;
                                } else {
                                    _panelWidth = Math.min(newW, Constants.controlsPanelMaxWidth);
                                }
                            }
                            onReleased: {
                                if (!_panelCollapsed && _panelWidth < Constants.controlsPanelMinWidth)
                                    _panelWidth = Constants.controlsPanelMinWidth;
                            }
                            onClicked: {
                                if (_panelCollapsed) {
                                    _panelCollapsed = false;
                                    _panelWidth = Constants.controlsPanelMinWidth;
                                }
                            }
                            onDoubleClicked: {
                                if (!_panelCollapsed) {
                                    _panelCollapsed = true;
                                    _panelWidth = 0;
                                }
                            }
                        }

                        Keys.onLeftPressed: {
                            if (_panelCollapsed)
                                return;

                            _panelWidth = Math.min(Constants.controlsPanelMaxWidth, _panelWidth + 16);
                        }
                        Keys.onRightPressed: {
                            if (_panelCollapsed) {
                                _panelCollapsed = false;
                                _panelWidth = Constants.controlsPanelMinWidth;
                                return;
                            }
                            if (_panelWidth <= Constants.controlsPanelMinWidth) {
                                _panelCollapsed = true;
                                _panelWidth = 0;
                                return;
                            }
                            _panelWidth = Math.max(Constants.controlsPanelMinWidth, _panelWidth - 16);
                        }
                    }

                    ControlsPanel {
                        id: controlsPanel

                        width: _panelWidth
                        height: parent.height
                        visible: !_panelCollapsed
                        hostWindow: appWindow
                        playerItem: player
                        onOpenVideoClicked: fileDialog.open()
                        onProfileEditorClicked: {
                            player.pause();
                            stackView.push(profileEditorPage);
                        }
                        onBrowseOutputClicked: {
                            saveDialog.currentFile = "file://" + encodeURI(appWindow.outputFilePath);
                            saveDialog.open();
                        }
                        onViewTranscodeClicked: transcodeDialog.open()
                        onSettingsClicked: optionsDialog.open()
                        onAboutClicked: aboutDialog.open()
                    }
                }
            }
        }

        Component {
            id: profileEditorPage

            ProfileEditor {
                profileName: currentProfile
                onBack: stackView.pop()
            }
        }
    }

    FileOpenDialog {
        id: fileDialog

        appWindow: appWindow
    }

    FileSaveDialog {
        id: saveDialog

        appWindow: appWindow
    }

    AboutDialog {
        id: aboutDialog
    }

    InfoBanner {
        id: copyBanner

        x: aboutDialog.x + (aboutDialog.width - width) / 2
        y: aboutDialog.y + aboutDialog.height + 8
        z: 300
        width: aboutDialog.width
        text: qsTr("Copied to clipboard")
        autoHideMs: 2000
        visible: false
    }

    OptionsDialog {
        id: optionsDialog
    }

    TranscodeDialog {
        id: transcodeDialog

        appWindow: appWindow
    }

    OverwriteConfirmDialog {
        id: overwriteDialog

        onOverwriteRequested: enqueueTranscoding()
    }

    FfmpegWarningDialog {
        id: ffmpegWarningDialog
    }

    MpvWarningDialog {
        id: mpvWarningDialog
    }

    Connections {
        function onTranscodingChanged() {
            if (backend.transcoding)
                return;

            if (transcodeQueue.length > 0) {
                transcodeQueue = transcodeQueue.slice(1);
                activeJob = null;
            }
            processTranscodeQueue();
        }

        target: backend
    }
}
