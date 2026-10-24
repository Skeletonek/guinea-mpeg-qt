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
    property string outputFilePath: ""
    // Chosen output directory for the batch; empty = next to each source file
    property string outputDirectory: ""
    property bool settingTimeline: false
    property url videoSource: ""
    property var videoStreams: []
    property var audioStreams: []
    property var selectedVideoIndices: []
    property var selectedAudioIndices: []
    property var transcodeQueue: []
    property var activeJob: null
    // currentVideoPath is the previewed member of batchFiles
    property var batchFiles: []
    // Global trim warning acknowledged (set on Continue, reset when Open File replaces the batch)
    property bool batchTrimAcknowledged: false
    // Jobs staged while the overwrite confirmation is open
    property var pendingResult: null
    // Session-only log history of finished jobs (capped, oldest dropped first)
    property var transcodeHistory: []
    readonly property int maxTranscodeHistory: 100
    // Outcome flags for the active job, consumed when it finishes
    property bool lastJobSuccess: false
    property bool jobEndSeen: false
    property bool jobCancelRequested: false
    // Result label on the controls panel stays until the user opens the transcoding log
    property bool transcodeResultSeen: true
    // Outcome counts of the latest batch (jobs queued after the previous batch fully drained)
    property int batchJobCount: 0
    property int batchFailedCount: 0
    property string previewProfile: ""

    function _findBatchIndex(files, path) {
        for (var i = 0; i < files.length; i++) {
            if (files[i].path === path)
                return i;
        }
        return -1;
    }

    function showQueueStatus(message) {
        if (message === "")
            return;
        queueBanner.text = message;
        queueBanner.show();
    }

    function _loadPreview(filePath, fileUrl, preloadedInfo, resetTrim) {
        backend.resetPreview();
        var info = preloadedInfo || backend.getVideoInfo(filePath) || {};
        currentVideoPath = filePath;
        currentVideoInfo = info;
        appWindow.videoSource = fileUrl || DataUtils.toFileUrl(filePath);
        videoDuration = Math.round(info.duration * 1000);
        if (resetTrim) {
            settingTimeline = true;
            startTime = 0;
            endTime = videoDuration;
            settingTimeline = false;
        }
        videoStreams = info.video_streams || [];
        audioStreams = info.audio_streams || [];
        if (resetTrim) {
            var vi = [];
            for (var v = 0; v < videoStreams.length; v++)
                vi.push(v);
            selectedVideoIndices = vi;
            var ai = [];
            for (var a = 0; a < audioStreams.length; a++)
                ai.push(a);
            selectedAudioIndices = ai;
        }
        var name = FormatUtils.getFilename(filePath);
        var base = FormatUtils.getBaseFilename(name);
        var dir = FormatUtils.getDirectory(filePath);
        var profileData = {};
        try {
            profileData = JSON.parse(backend.loadProfile(currentProfile));
        } catch (e) {}
        appWindow.outputFilePath = dir + base + "_transcoded." + DataUtils.getExtensionForProfile(profileData, filePath);
        var files = batchFiles.slice();
        var entry = {
            "path": filePath,
            "info": info
        };
        var idx = _findBatchIndex(files, filePath);
        if (idx >= 0)
            files[idx] = entry;
        else
            files = files.concat([entry]);
        batchFiles = files;
    }

    function loadVideo(filePath, fileUrl) {
        _loadPreview(filePath, fileUrl, null, true);
    }

    // Switches the previewed file without resetting the global trim or stream selection
    function switchPreview(filePath) {
        _loadPreview(filePath, undefined, null, false);
    }

    // Loads paths into the batch. replace=true starts a fresh batch (Open File),
    // otherwise appends (Add Files/multi-drop); switchToNew previews the first new file
    function openFiles(paths, replace, switchToNew) {
        var wasEmpty = appWindow.batchFiles.length === 0;
        var list = replace ? [] : appWindow.batchFiles.slice();
        var firstEntry = null;
        var skipped = 0;
        var duplicates = 0;
        for (var i = 0; i < paths.length; i++) {
            var info = backend.getVideoInfo(paths[i]) || {};
            if (!info.duration) {
                skipped++;
                continue;
            }
            if (_findBatchIndex(list, paths[i]) >= 0) {
                duplicates++;
                continue;
            }
            var entry = {
                "path": paths[i],
                "info": info
            };
            list = list.concat([entry]);
            if (firstEntry === null)
                firstEntry = entry;
        }
        if (firstEntry === null) {
            showQueueStatus(skipped > 0 ? qsTr("Could not open %1 file(s)").arg(skipped) : "");
            return;
        }
        batchFiles = list;
        if (replace)
            batchTrimAcknowledged = false;
        if (replace || wasEmpty) {
            _loadPreview(firstEntry.path, undefined, firstEntry.info, true);
        } else if (switchToNew && firstEntry.path !== appWindow.currentVideoPath) {
            switchPreview(firstEntry.path);
        }
        var notes = [];
        if (skipped > 0)
            notes.push(qsTr("%1 skipped (not readable)").arg(skipped));
        if (duplicates > 0)
            notes.push(qsTr("%1 already open").arg(duplicates));
        showQueueStatus(notes.join(", "));
    }

    function updateCodec() {
        var d;
        try {
            d = JSON.parse(backend.loadProfile(currentProfile));
            currentCodec = d.codec || Constants.codecKeys[0];
        } catch (e) {
            currentCodec = Constants.codecKeys[0];
        }
        var ext = DataUtils.getExtensionForProfile(d || {}, appWindow.currentVideoPath);
        var dot = appWindow.outputFilePath.lastIndexOf(".");
        appWindow.outputFilePath = appWindow.outputFilePath.substring(0, dot >= 0 ? dot : 0) + "." + ext;
    }

    function requestTrimWarning() {
        trimWarningDialog.open();
    }

    function normalizedOutputDir() {
        var d = appWindow.outputDirectory;
        if (d === "")
            return "";
        return d.endsWith("/") ? d : d + "/";
    }

    function buildBatchJobs() {
        var files = appWindow.batchFiles;
        var profile;
        try {
            profile = JSON.parse(backend.loadProfile(appWindow.currentProfile));
        } catch (e) {
            return null;
        }
        // Outputs of waiting/running jobs reserve name slots
        var taken = {};
        if (appWindow.activeJob)
            taken[appWindow.activeJob.output] = true;
        for (var qi = 0; qi < appWindow.transcodeQueue.length; qi++)
            taken[appWindow.transcodeQueue[qi].output] = true;
        var jobs = [];
        var tooShort = 0;
        for (var i = 0; i < files.length; i++) {
            var f = files[i];
            var durMs = Math.round((f.info.duration || 0) * 1000);
            var s = Math.max(appWindow.startTime, 0);
            var e = Math.min(appWindow.endTime, durMs);
            if (e - s <= 0) {
                // No overlap with the trim window: file is transcoded at its full length
                s = 0;
                e = durMs;
            }
            if (e - s <= 0) {
                tooShort++;
                continue;
            }
            var out;
            if (files.length > 1) {
                var dir = appWindow.normalizedOutputDir();
                if (dir === "")
                    dir = FormatUtils.getDirectory(f.path);
                var name = FormatUtils.getFilename(f.path);
                out = dir + FormatUtils.getBaseFilename(name) + "_transcoded." + DataUtils.getExtensionForProfile(profile, f.path);
            } else {
                out = appWindow.outputFilePath;
            }
            var pf = {};
            for (var k in profile)
                pf[k] = profile[k];
            // Copy stream selection to every file, clamped to what the file has
            var vStreams = f.info.video_streams || [];
            var aStreams = f.info.audio_streams || [];
            var vIdx = appWindow.selectedVideoIndices.filter(function (vi) {
                return vi < vStreams.length;
            });
            if (vIdx.length > 0)
                pf.video_stream_indices = vIdx;
            var aIdx = appWindow.selectedAudioIndices.filter(function (ai) {
                return ai < aStreams.length;
            });
            if (aIdx.length > 0)
                pf.audio_stream_indices = aIdx;
            var job = {
                "input": f.path,
                "output": out,
                "start": s / 1000,
                "end": e / 1000,
                "profile": JSON.stringify(pf),
                "targetFps": profile.framerate || 0,
                "sourceFps": FormatUtils.fpsToDecimal(f.info.fps || "") || 0,
                "durationMs": e - s
            };
            job.output = DataUtils.uniquePath(out, taken);
            taken[job.output] = true;
            jobs.push(job);
        }
        return {
            "jobs": jobs,
            "tooShort": tooShort
        };
    }

    function startTranscoding() {
        if (appWindow.outputFilePath === "") {
            showQueueStatus(qsTr("Please set an output file path first"));
            return;
        }
        var result = buildBatchJobs();
        if (result === null)
            return;
        var existing = [];
        for (var i = 0; i < result.jobs.length; i++) {
            if (backend.fileExists(result.jobs[i].output))
                existing = existing.concat([result.jobs[i].output]);
        }
        if (existing.length > 0) {
            pendingResult = result;
            overwriteDialog.filePaths = existing;
            overwriteDialog.open();
            return;
        }
        enqueueJobs(result);
    }

    function enqueueJobs(result) {
        if (result.jobs.length > 0) {
            if (activeJob === null && transcodeQueue.length === 0) {
                batchJobCount = 0;
                batchFailedCount = 0;
            }
            transcodeQueue = transcodeQueue.concat(result.jobs);
            processTranscodeQueue();
            transcodeDialog.open();
        }
        var notes = [];
        if (result.jobs.length > 0)
            notes.push(qsTr("Added %1 file(s) to the queue").arg(result.jobs.length));
        if (result.tooShort > 0)
            notes.push(qsTr("%1 skipped (empty trim range)").arg(result.tooShort));
        showQueueStatus(notes.length > 0 ? notes.join(", ") : qsTr("No new files to queue"));
    }

    function removeQueuedJob(queueIndex) {
        if (queueIndex < 0 || queueIndex >= transcodeQueue.length)
            return;
        if (activeJob !== null && queueIndex === 0)
            return;
        transcodeQueue = transcodeQueue.slice(0, queueIndex).concat(transcodeQueue.slice(queueIndex + 1));
    }

    function cancelActiveTranscode() {
        jobCancelRequested = true;
        backend.cancelTranscode();
    }

    function processTranscodeQueue() {
        if (activeJob !== null || transcodeQueue.length === 0)
            return;

        var job = transcodeQueue[0];
        activeJob = job;
        jobCancelRequested = false;
        jobEndSeen = false;
        lastJobSuccess = false;
        backend.startTranscode(job.input, job.output, job.start, job.end, job.profile);
    }

    width: Constants.windowDefaultWidth
    height: Constants.windowDefaultHeight
    minimumWidth: Constants.windowMinWidth
    minimumHeight: Constants.windowMinHeight
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
                        var urls = drop.urls;
                        if (urls.length === 0)
                            return;

                        var paths = [];
                        for (var i = 0; i < urls.length; i++)
                            paths.push(DataUtils.toLocalPath(urls[i]));
                        // Single drop replaces like Open File; multi-drop appends
                        appWindow.openFiles(paths, urls.length === 1, urls.length > 1);
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
                        hasAudioOnly: (appWindow.currentVideoInfo.audio_streams || []).length > 0 && (appWindow.currentVideoInfo.video_streams || []).length === 0
                        videoPath: appWindow.currentVideoPath
                        profileName: appWindow.currentProfile
                        startTimeMs: appWindow.startTime
                        sourceFps: FormatUtils.fpsToDecimal(appWindow.currentVideoInfo.fps || "") || 0
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
                            onPressed: function (mouse) {
                                _panelStartX = splitterMouse.mapToItem(null, mouse.x, 0).x;
                                _panelStartWidth = controlsPanel.width;
                            }
                            onPositionChanged: function (mouse) {
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
                        onAddFilesClicked: addFilesDialog.open()
                        onProfileEditorClicked: {
                            player.pause();
                            stackView.push(profileEditorPage);
                        }
                        onBrowseOutputClicked: {
                            if (appWindow.batchFiles.length > 1) {
                                var startDir = appWindow.outputDirectory !== "" ? appWindow.outputDirectory : FormatUtils.getDirectory(appWindow.currentVideoPath);
                                var dir = backend.chooseOutputDirectory(startDir);
                                if (dir !== "")
                                    appWindow.outputDirectory = dir;
                            } else {
                                saveDialog.currentFile = DataUtils.toFileUrl(appWindow.outputFilePath);
                                saveDialog.open();
                            }
                        }
                        onViewTranscodeClicked: {
                            transcodeResultSeen = true;
                            transcodeDialog.open();
                        }
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

        mainWindow: appWindow
    }

    FileOpenDialog {
        id: addFilesDialog

        mainWindow: appWindow
        appendMode: true
    }

    FileSaveDialog {
        id: saveDialog

        mainWindow: appWindow
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

    // Transient feedback for open/queue actions (replaces the old persistent
    // status label); floats above dialogs since queueing opens TranscodeDialog
    InfoBanner {
        id: queueBanner

        parent: Overlay.overlay
        z: 1000
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 16
        width: Math.min(Math.max(0, parent.width - 32), 480)
        autoHideMs: 3000
        visible: false
    }

    OptionsDialog {
        id: optionsDialog
    }

    TranscodeDialog {
        id: transcodeDialog

        mainWindow: appWindow
    }

    OverwriteConfirmDialog {
        id: overwriteDialog

        onOverwriteRequested: appWindow.enqueueJobs(appWindow.pendingResult)
    }

    TrimWarningDialog {
        id: trimWarningDialog

        batchCount: appWindow.batchFiles.length

        onConfirmed: appWindow.batchTrimAcknowledged = true
    }

    FfmpegWarningDialog {
        id: ffmpegWarningDialog
    }

    MpvWarningDialog {
        id: mpvWarningDialog
    }

    Connections {
        function onTranscodeFinished(success) {
            lastJobSuccess = success;
            jobEndSeen = true;
        }

        function onTranscodingChanged() {
            if (backend.transcoding)
                return;

            // Defer to next event loop to avoid reentrancy inside
            // QProcess::finished (backend.cpp:connectOutputCapture).
            Qt.callLater(function () {
                var queueDrained = false;
                if (transcodeQueue.length > 0) {
                    // No transcodeFinished on cancel or spawn failure — both map to "failed" otherwise
                    var status = jobCancelRequested ? "cancelled" : (jobEndSeen && lastJobSuccess ? "completed" : "failed");
                    var finishedJob = transcodeQueue[0];
                    transcodeHistory = transcodeHistory.concat([{
                            "output": finishedJob.output,
                            "status": status,
                            "log": backend.transcodeOutput
                        }]);
                    if (transcodeHistory.length > maxTranscodeHistory)
                        transcodeHistory = transcodeHistory.slice(transcodeHistory.length - maxTranscodeHistory);
                    batchJobCount++;
                    if (status !== "completed")
                        batchFailedCount++;
                    // The buffer holds one job at a time; the history entry keeps its log
                    backend.clearTranscodeOutput();
                    transcodeQueue = transcodeQueue.slice(1);
                    activeJob = null;
                }
                processTranscodeQueue();
                queueDrained = (activeJob === null && transcodeQueue.length === 0);
                // Surface the result label only when the whole queue has drained
                transcodeResultSeen = queueDrained ? transcodeDialog.visible : true;
                if (queueDrained) {
                    var failed = appWindow.batchFailedCount > 0;
                    var title = failed ? qsTr("Transcoding Failed") : qsTr("Transcoding Complete");
                    var body;
                    if (appWindow.batchJobCount > 1) {
                        if (failed)
                            body = qsTr("%1 of %2 jobs failed").arg(appWindow.batchFailedCount).arg(appWindow.batchJobCount);
                        else
                            body = qsTr("All %1 jobs completed").arg(appWindow.batchJobCount);
                    } else {
                        body = failed ? qsTr("Transcoding exited with an error") : qsTr("Your video has been transcoded successfully.");
                    }
                    backend.sendNotification(title, body);
                }
            });
        }

        function onPreviewGenerated(path) {
            appWindow.previewProfile = appWindow.currentProfile;
        }

        target: backend
    }
}
