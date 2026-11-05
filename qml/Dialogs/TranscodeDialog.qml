import "../Components"
import "../Utils/DataUtils.js" as DataUtils
import "../Utils/FormatUtils.js" as FormatUtils
import GuineaMpeg 1.0
import "../Utils/Constants.js" as Constants
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AppDialog {
    id: root

    property var mainWindow: null
    property double _progress: 0
    property double _totalFrames: 0
    // Combined history (finished jobs) + queue (active/waiting jobs)
    property var entries: []
    property int selectedIndex: -1
    // Holds between finishing a queued job and launching the next one
    readonly property bool _queuePending: mainWindow !== null && mainWindow.transcodeQueue.length > 0

    function recalcProgress() {
        _progress = 0;
        var job = mainWindow ? mainWindow.activeJob : null;
        if (!job) {
            _totalFrames = 0;
            return;
        }
        var fps = job.targetFps > 0 ? job.targetFps : job.sourceFps;
        _totalFrames = fps > 0 ? Math.round(fps * job.durationMs / 1000) : 0;
    }

    function rebuildEntries() {
        var list = [];
        var hist = mainWindow ? mainWindow.transcodeHistory : [];
        for (var i = 0; i < hist.length; i++)
            list.push({
                "status": hist[i].status,
                "output": hist[i].output,
                "log": hist[i].log
            });
        var queue = mainWindow ? mainWindow.transcodeQueue : [];
        for (var j = 0; j < queue.length; j++)
            list.push({
                "status": j === 0 ? (backend.transcoding ? "running" : "starting") : "waiting",
                "output": queue[j].output,
                "queueIndex": j,
                "log": ""
            });
        entries = list;
        if (selectedIndex >= list.length)
            selectedIndex = list.length - 1;
    }

    function selectDefault() {
        var hist = mainWindow ? mainWindow.transcodeHistory : [];
        if (backend.transcoding && mainWindow && mainWindow.transcodeQueue.length > 0)
            selectedIndex = hist.length;
        else if (hist.length > 0)
            selectedIndex = hist.length - 1;
        else
            selectedIndex = -1;
    }

    function statusText(status) {
        switch (status) {
        case "completed":
            return qsTr("Completed");
        case "failed":
            return qsTr("Failed");
        case "cancelled":
            return qsTr("Cancelled");
        case "running":
            return qsTr("Running");
        case "starting":
            return qsTr("Starting");
        default:
            return qsTr("Waiting");
        }
    }

    function statusColor(status) {
        if (status === "failed")
            return Constants.errorColor;
        if (status === "running" || status === "starting")
            return theme.accent;
        return status === "completed" ? theme.text : theme.textSecondary;
    }

    function currentLogText() {
        if (selectedIndex < 0 || selectedIndex >= entries.length)
            return "";
        var e = entries[selectedIndex];
        // The running job's log streams live from the backend buffer
        return e.status === "running" || e.status === "starting" ? backend.transcodeOutput : e.log;
    }

    function parseProgress() {
        // Buffer holds only the active job's output (cleared between jobs)
        var p = DataUtils.parseFrameProgress(backend.transcodeOutput, _totalFrames);
        if (p >= 0 && p > _progress)
            _progress = p;
    }

    centered: false
    modal: false
    closePolicy: Popup.CloseOnEscape
    // Preferred size from Constants, clamped to the main window (16 margin per side)
    width: mainWindow ? Math.min(Constants.dialogWidthTranscode, mainWindow.width - 32) : Constants.dialogWidthTranscode
    height: mainWindow ? Math.min(Constants.dialogHeightTranscode, mainWindow.height - 32) : Constants.dialogHeightTranscode
    x: mainWindow ? Math.round((mainWindow.width - width) / 2) : 0
    y: mainWindow ? Math.round((mainWindow.height - height) / 2) : 0
    onAboutToShow: {
        rebuildEntries();
        selectDefault();
        recalcProgress();
    }
    onSelectedIndexChanged: {
        transcodeFlickable.wasAtBottom = true;
        transcodeFlickable.contentY = Math.max(0, transcodeFlickable.contentHeight - transcodeFlickable.height);
    }

    Connections {
        function onActiveJobChanged() {
            root.rebuildEntries();
            root.selectDefault();
            recalcProgress();
        }

        function onTranscodeQueueChanged() {
            root.rebuildEntries();
        }

        function onTranscodeHistoryChanged() {
            root.rebuildEntries();
        }

        target: mainWindow
    }

    Connections {
        function onTranscodeOutputUpdated() {
            parseProgress();
        }

        target: backend
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            ListView {
                id: jobList

                Layout.preferredWidth: Math.round(root.width / 3)
                Layout.fillHeight: true
                visible: root.entries.length > 0
                spacing: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.entries

                delegate: Rectangle {
                    width: jobList.width
                    height: rowLayout.implicitHeight + 8
                    radius: 4
                    color: index === root.selectedIndex ? theme.surface : "transparent"

                    RowLayout {
                        id: rowLayout

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Label {
                            text: index + 1 + "."
                            color: theme.textSecondary
                            font.pixelSize: 12
                        }

                        Label {
                            text: FormatUtils.getFilename(modelData.output)
                            color: root.statusColor(modelData.status)
                            font.pixelSize: 12
                            font.bold: modelData.status === "running"
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }

                        Label {
                            text: root.statusText(modelData.status)
                            color: root.statusColor(modelData.status)
                            font.pixelSize: 12
                        }

                        Button {
                            visible: modelData.status === "waiting"
                            text: "\u2715"
                            flat: true
                            implicitWidth: 24
                            implicitHeight: 24
                            ToolTip.text: qsTr("Remove from queue")
                            ToolTip.visible: hovered
                            onClicked: {
                                if (mainWindow)
                                    mainWindow.removeQueuedJob(modelData.queueIndex);
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedIndex = index
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: theme.bg

                Flickable {
                    id: transcodeFlickable

                    property bool wasAtBottom: true

                    anchors.fill: parent
                    anchors.margins: 4
                    contentHeight: outputDisplay.contentHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    onContentYChanged: {
                        if (height <= 0)
                            return;

                        wasAtBottom = (contentY >= contentHeight - height - 1);
                    }
                    onContentHeightChanged: {
                        // Clamped to bounds: an out-of-bounds contentY trips the Flickable's
                        // bounds fixup, which then misreads as a user scroll and stops autoscroll
                        if (height > 0 && wasAtBottom)
                            contentY = Math.max(0, contentHeight - height);
                    }
                    onHeightChanged: {
                        if (height > 0 && wasAtBottom && contentHeight > 0)
                            contentY = Math.max(0, contentHeight - height);
                    }

                    TextEdit {
                        id: outputDisplay

                        // Reserve room so the vertical scrollbar doesn't overlap text
                        width: parent.width - 16
                        text: root.currentLogText()
                        readOnly: true
                        font.family: "monospace"
                        font.pixelSize: 12
                        color: theme.text
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        textFormat: TextEdit.PlainText
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ProgressBar {
                id: progressBar

                Layout.fillWidth: true
                from: 0
                to: 1
                value: _progress
            }

            Label {
                text: Math.round(_progress * 100) + "%"
                color: theme.text
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: (backend.transcoding || root._queuePending) ? qsTr("ffmpeg is running...")
                                                                  : qsTr("Done. You can close this window.")
                color: (backend.transcoding || root._queuePending) ? theme.textSecondary : theme.accent
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: qsTr("Clear")
                visible: !backend.transcoding && (backend.transcodeOutput !== "" || (mainWindow && mainWindow.transcodeHistory.length > 0))
                onClicked: {
                    if (mainWindow)
                        mainWindow.transcodeHistory = [];

                    backend.clearTranscodeOutput();
                    root.rebuildEntries();
                    root.selectDefault();
                    recalcProgress();
                }
            }

            Button {
                text: qsTr("Cancel")
                visible: backend.transcoding
                onClicked: mainWindow.cancelActiveTranscode()
            }
        }
    }

    title: {
        var n = mainWindow ? mainWindow.transcodeQueue.length : 0;
        if (backend.transcoding || root._queuePending) {
            if (backend.transcoding && n > 1)
                return qsTr("Transcoding... (1 of %1)").arg(n);
            return qsTr("Transcoding...");
        }

        return qsTr("Transcoding Complete");
    }

    footer: Loader {
        active: !styleDrawsHeaderClose
        sourceComponent: DialogButtonBox {
            Button {
                text: qsTr("Close")
                onClicked: root.close()
            }
        }
    }
}
