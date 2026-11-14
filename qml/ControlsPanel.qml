import "Components"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Utils/Constants.js" as Constants
import "Utils/DataUtils.js" as DataUtils
import "Utils/FormatUtils.js" as FormatUtils

Item {
    id: root

    property var hostWindow: null
    property var playerItem: null

    // Media information: first video/audio stream of the previewed file
    readonly property bool _hasVideo: hostWindow !== null && hostWindow.currentVideoPath !== ""
    readonly property var _videoStream: _hasVideo && hostWindow.videoStreams.length > 0 ? hostWindow.videoStreams[0] : null
    readonly property var _audioStream: _hasVideo && hostWindow.audioStreams.length > 0 ? hostWindow.audioStreams[0] : null
    readonly property string _durationText: _hasVideo ? (hostWindow.currentVideoInfo.duration || 0).toFixed(3) : ""

    signal openVideoClicked
    signal addFilesClicked
    signal profileEditorClicked
    signal browseOutputClicked
    signal viewTranscodeClicked
    signal settingsClicked
    signal aboutClicked

    function refreshProfiles() {
        profileSelector.model = DataUtils.parseProfileRows(backend.availableProfiles());
        var idx = profileSelector.indexOfProfile(hostWindow ? hostWindow.currentProfile : "");
        if (idx < 0)
            idx = profileSelector.firstProfileIndex();
        profileSelector.currentIndex = idx;
    }

    function _batchMode() {
        return hostWindow && (hostWindow.batchFiles || []).length > 1;
    }

    function _batchFiles() {
        return hostWindow ? (hostWindow.batchFiles || []) : [];
    }

    function _currentComboIndex() {
        var files = _batchFiles();
        var current = hostWindow ? hostWindow.currentVideoPath : "";
        for (var i = 0; i < files.length; i++) {
            if (files[i].path === current)
                return i;
        }
        return 0;
    }

    function _fileLabels() {
        var files = _batchFiles();
        var labels = [];
        for (var i = 0; i < files.length; i++)
            labels.push((i + 1) + ". " + FormatUtils.getFilename(files[i].path));
        return labels;
    }

    function _applyTrim(kind, value) {
        if (!hostWindow)
            return;
        if ((hostWindow.batchFiles || []).length > 1 && !hostWindow.batchTrimAcknowledged) {
            hostWindow.requestTrimWarning();
            return;
        }
        if (kind === "start") {
            hostWindow.startTime = value;
            if (playerItem)
                playerItem.position = value;
        } else {
            hostWindow.endTime = value;
            if (playerItem)
                playerItem.position = value;
        }
    }

    Flickable {
        id: rightPanelFlickable

        anchors.top: parent.top
        anchors.bottom: updateBanner.visible ? updateBanner.top : aboutButton.top
        anchors.bottomMargin: 4
        width: parent.width
        contentHeight: column.height
        clip: true

        Column {
            id: column

            spacing: 8
            width: rightPanelFlickable.width - (vbar.visible ? vbar.width : 0)

            Label {
                text: qsTr("Input File")
                font.bold: true
                font.pixelSize: 16
                color: theme.text
            }

            Row {
                spacing: 8
                width: parent.width

                Button {
                    text: qsTr("Open File...")
                    onClicked: root.openVideoClicked()
                    width: (parent.width - parent.spacing) / 2
                }

                Button {
                    text: qsTr("Add Files...")
                    enabled: hostWindow && hostWindow.currentVideoPath !== ""
                    onClicked: root.addFilesClicked()
                    width: (parent.width - parent.spacing) / 2
                }
            }

            Label {
                text: qsTr("Media Information")
                font.bold: true
                font.pixelSize: 16
                color: theme.text
                topPadding: 8
            }

            ComboBox {
                id: fileSwitcher

                visible: root._batchMode()
                model: root._fileLabels()
                currentIndex: root._currentComboIndex()
                width: parent.width
                onActivated: {
                    var files = root._batchFiles();
                    if (currentIndex >= 0 && currentIndex < files.length && files[currentIndex].path !== (hostWindow ? hostWindow.currentVideoPath : ""))
                        hostWindow.switchPreview(files[currentIndex].path);
                    currentIndex = Qt.binding(function () {
                        return root._currentComboIndex();
                    });
                }
            }

            Flickable {
                id: videoInfoScroll

                width: parent.width
                height: Math.max(Math.min(videoInfoLayout.implicitHeight, 160), 120)
                contentHeight: videoInfoLayout.implicitHeight
                clip: true

                ColumnLayout {
                    id: videoInfoLayout

                    width: videoInfoScroll.width - (infoVbar.visible ? infoVbar.width : 0)
                    spacing: 4

                    Label {
                        text: root._hasVideo ? qsTr("File: %1").arg(FormatUtils.getFilename(hostWindow.currentVideoPath))
                                             : qsTr("Load a video file to see information")
                        color: theme.text
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Label {
                        visible: root._hasVideo
                        text: qsTr("Duration: %1s").arg(root._durationText)
                        color: theme.text
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        visible: root._hasVideo
                        Layout.fillWidth: true
                        // Qt 6.12: a nested layout's implicit maximum width caps it at
                        // its content width, so fillWidth alone never stretches it.
                        Layout.maximumWidth: Number.POSITIVE_INFINITY
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: qsTr("Video")
                                font.bold: true
                                color: theme.text
                            }

                            Label {
                                text: qsTr("Codec: %1").arg(root._videoStream ? root._videoStream.codec : "N/A")
                                color: theme.text
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: qsTr("Resolution: %1").arg(root._videoStream ? root._videoStream.width + "x" + root._videoStream.height : "N/A")
                                color: theme.text
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: qsTr("FPS: %1").arg(root._videoStream ? FormatUtils.formatFps(root._videoStream.fps) : "N/A")
                                color: theme.text
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: qsTr("Bitrate: %1").arg(root._videoStream ? FormatUtils.formatBitrate(root._videoStream.bitrate) : "N/A")
                                color: theme.text
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: qsTr("Pixel format: %1").arg(root._videoStream ? root._videoStream.pix_fmt || "?" : "N/A")
                                color: theme.text
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: qsTr("Color: %1").arg(root._videoStream ? FormatUtils.formatColor(root._videoStream) : "N/A")
                                color: theme.text
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: qsTr("Audio")
                                font.bold: true
                                color: theme.text
                            }

                            Label {
                                text: qsTr("Codec: %1").arg(root._audioStream ? root._audioStream.codec : "N/A")
                                color: theme.text
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: qsTr("Sample rate: %1").arg(root._audioStream ? FormatUtils.formatSampleRate(root._audioStream.sample_rate) : "N/A")
                                color: theme.text
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: qsTr("Channels: %1").arg(root._audioStream ? FormatUtils.formatChannels(root._audioStream.channels) : "N/A")
                                color: theme.text
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: qsTr("Bitrate: %1").arg(root._audioStream ? FormatUtils.formatBitrate(root._audioStream.bitrate) : "N/A")
                                color: theme.text
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    id: infoVbar

                    policy: ScrollBar.AsNeeded
                }
            }

            Label {
                text: qsTr("Stream Selection")
                font.bold: true
                font.pixelSize: 16
                color: theme.text
                topPadding: 8
                visible: (hostWindow && hostWindow.videoStreams.length > 1) || (hostWindow && hostWindow.audioStreams.length > 1)
            }

            Label {
                text: qsTr("Video")
                color: theme.textMuted
                font.bold: true
                font.pixelSize: 14
                visible: hostWindow && hostWindow.videoStreams.length > 1
            }

            Column {
                spacing: 4
                width: parent.width
                visible: hostWindow && hostWindow.videoStreams.length > 1

                StreamSelector {
                    streams: hostWindow ? hostWindow.videoStreams : []
                    kind: "video"
                    selection: hostWindow ? hostWindow.selectedVideoIndices : []
                    onToggled: function (index, checked) {
                        if (hostWindow)
                            hostWindow.selectedVideoIndices = DataUtils.toggleSelection(index, checked, hostWindow.selectedVideoIndices);
                    }
                }
            }

            Label {
                text: qsTr("Audio")
                color: theme.textMuted
                font.bold: true
                font.pixelSize: 14
                visible: hostWindow && hostWindow.audioStreams.length > 1
            }

            Column {
                spacing: 4
                width: parent.width
                visible: hostWindow && hostWindow.audioStreams.length > 1

                StreamSelector {
                    streams: hostWindow ? hostWindow.audioStreams : []
                    kind: "audio"
                    selection: hostWindow ? hostWindow.selectedAudioIndices : []
                    onToggled: function (index, checked) {
                        if (hostWindow)
                            hostWindow.selectedAudioIndices = DataUtils.toggleSelection(index, checked, hostWindow.selectedAudioIndices);
                    }
                }
            }

            Label {
                text: qsTr("Transcoding Profile")
                font.bold: true
                font.pixelSize: 16
                color: theme.text
                topPadding: 8
            }

            ProfileComboBox {
                id: profileSelector

                onCurrentTextChanged: {
                    if (isHeaderRow(currentIndex))
                        return;

                    if (hostWindow) {
                        hostWindow.currentProfile = currentText;
                        hostWindow.updateCodec();
                    }
                }
                width: parent.width
            }

            Button {
                text: qsTr("Profile Editor")
                onClicked: root.profileEditorClicked()
                width: parent.width
            }

            Label {
                text: qsTr("Timeline Selection")
                font.bold: true
                font.pixelSize: 16
                color: theme.text
                topPadding: 8
            }

            TimelineControl {
                id: timeline

                width: parent.width
                height: 80
                mainWindow: hostWindow
                videoDuration: hostWindow ? hostWindow.videoDuration : 0
                startTime: hostWindow ? hostWindow.startTime : 0
                endTime: hostWindow ? hostWindow.endTime : 0
                onStartTimeChanged: {
                    if (!hostWindow || hostWindow.settingTimeline)
                        return;

                    root._applyTrim("start", timeline.startTime);
                }
                onEndTimeChanged: {
                    if (!hostWindow || hostWindow.settingTimeline)
                        return;

                    root._applyTrim("end", timeline.endTime);
                }
                onTrimRequested: function (kind, value) {
                    root._applyTrim(kind, value);
                }
            }

            Label {
                text: root._batchMode() ? qsTr("Output Directory") : qsTr("Output File")
                font.bold: true
                font.pixelSize: 14
                color: theme.text
                topPadding: 8
            }

            Row {
                spacing: 8
                width: parent.width

                TextField {
                    id: outputPathField

                    visible: !root._batchMode()
                    text: hostWindow ? hostWindow.outputFilePath : ""
                    placeholderText: qsTr("Output path...")
                    onTextChanged: {
                        if (hostWindow)
                            hostWindow.outputFilePath = text;
                    }
                    width: parent.width - 40 - parent.spacing
                }

                TextField {
                    id: outputDirectoryField

                    visible: root._batchMode()
                    text: hostWindow ? hostWindow.outputDirectory : ""
                    placeholderText: qsTr("Empty = next to each source file")
                    onTextChanged: {
                        if (hostWindow)
                            hostWindow.outputDirectory = text;
                    }
                    width: parent.width - 40 - parent.spacing
                }

                Button {
                    id: browseButton

                    text: "..."
                    width: 40
                    onClicked: root.browseOutputClicked()
                }
            }

            Label {
                id: previewEstimate

                property bool hasPreview: backend.lastPreviewSize > 0
                property bool stale: hasPreview && (hostWindow.previewProfile !== hostWindow.currentProfile)
                property bool hasTrim: hostWindow && (hostWindow.endTime - hostWindow.startTime) > 0
                readonly property real previewSeconds: backend.lastPreviewDurationMs / 1000
                text: hasPreview && hasTrim ? qsTr("Estimated size: %1 (based on %2s preview)").arg(FormatUtils.formatSize(backend.lastPreviewSize * (hostWindow.endTime - hostWindow.startTime) / backend.lastPreviewDurationMs)).arg(previewSeconds) : ""
                color: theme.text
                font.pixelSize: 12
                opacity: stale ? 0.5 : 1.0
                visible: text !== ""
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Label {
                text: qsTr("Preview outdated — regenerate preview to refresh estimate")
                color: theme.accent
                font.pixelSize: 12
                visible: previewEstimate.stale
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Row {
                spacing: 8
                width: parent.width

                Button {
                    id: startButton

                    text: {
                        var n = hostWindow ? hostWindow.batchFiles.length : 0;
                        if (backend.transcoding)
                            return qsTr("Add to Transcoding Queue");
                        return n > 1 ? qsTr("Start Transcoding (%1 files)").arg(n) : qsTr("Start Transcoding");
                    }
                    enabled: hostWindow && hostWindow.currentVideoPath !== "" && hostWindow.endTime > hostWindow.startTime
                    onClicked: {
                        if (playerItem)
                            playerItem.pause();

                        if (hostWindow)
                            hostWindow.startTranscoding();
                    }
                    width: parent.width - logButton.width - parent.spacing
                }

                IconButton {
                    id: logButton

                    text: qsTr("Transcoding log")
                    icon.name: "view-list-text-symbolic"
                    icon.source: "/media/icons/log.png"
                    enabled: backend.transcoding || backend.transcodeOutput !== "" || (hostWindow && hostWindow.transcodeHistory.length > 0)
                    onClicked: root.viewTranscodeClicked()
                    width: 40
                    height: startButton.height
                }
            }

            Label {
                readonly property bool hasLog: backend.transcodeOutput !== ""
                readonly property bool hasResult: !backend.transcoding && hostWindow && !hostWindow.transcodeResultSeen && (hostWindow.transcodeHistory.length > 0 || hasLog)
                readonly property bool hasFailures: hostWindow && hostWindow.batchFailedCount > 0
                readonly property string resultText: hasFailures ? (hostWindow.batchJobCount > 1 ? qsTr("%1 of %2 jobs failed").arg(hostWindow.batchFailedCount).arg(hostWindow.batchJobCount) : qsTr("Transcoding failed")) : qsTr("Transcoding complete")
                text: backend.transcoding ? (hostWindow && hostWindow.transcodeQueue.length > 1 ? qsTr("Transcoding in progress... (%1 queued)").arg(hostWindow.transcodeQueue.length - 1) : qsTr("Transcoding in progress...")) : (hasResult ? resultText : "")
                color: hasFailures ? Constants.errorColor : theme.accent
                font.pixelSize: 12
                visible: backend.transcoding || hasResult
                width: parent.width
                wrapMode: Text.WordWrap
            }
        }

        ScrollBar.vertical: ScrollBar {
            id: vbar

            policy: ScrollBar.AsNeeded
        }
    }

    UpdateBanner {
        id: updateBanner

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: settingsButton.top
        anchors.bottomMargin: 8
        height: visible ? implicitHeight : 0
        z: 10
    }

    Button {
        id: settingsButton

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: 48
        height: 48
        icon.name: "preferences-system-symbolic"
        icon.source: "/media/icons/settings.png"
        icon.width: 32
        icon.height: 32
        display: Button.IconOnly
        ToolTip.text: qsTr("Settings")
        ToolTip.visible: hovered
        onClicked: root.settingsClicked()
    }

    Button {
        id: aboutButton

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 48
        height: 48
        icon.name: "help-about-symbolic"
        icon.source: "/media/icons/info.png"
        icon.width: 32
        icon.height: 32
        display: Button.IconOnly
        ToolTip.text: qsTr("About")
        ToolTip.visible: hovered
        onClicked: root.aboutClicked()
    }
}
