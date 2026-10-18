import "../Utils/DataUtils.js" as DataUtils
import "../Utils/FormatUtils.js" as FormatUtils
import GuineaMpeg 1.0
import "../Utils/Constants.js" as Constants
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root

    property var appWindow: null
    property double _progress: 0
    property double _totalFrames: 0
    // Combined history (finished jobs) + queue (active/waiting jobs)
    property var entries: []
    property int selectedIndex: -1

    function recalcProgress() {
        _progress = 0;
        var job = appWindow ? appWindow.activeJob : null;
        if (!job) {
            _totalFrames = 0;
            return;
        }
        var fps = job.targetFps > 0 ? job.targetFps : job.sourceFps;
        _totalFrames = fps > 0 ? Math.round(fps * job.durationMs / 1000) : 0;
    }

    function rebuildEntries() {
        var list = [];
        var hist = appWindow ? appWindow.transcodeHistory : [];
        for (var i = 0; i < hist.length; i++)
            list.push({
                "status": hist[i].status,
                "output": hist[i].output,
                "log": hist[i].log
            });
        var queue = appWindow ? appWindow.transcodeQueue : [];
        for (var j = 0; j < queue.length; j++)
            list.push({
                "status": j === 0 ? (backend.transcoding ? "running" : "starting") : "waiting",
                "output": queue[j].output,
                "log": ""
            });
        entries = list;
        if (selectedIndex >= list.length)
            selectedIndex = list.length - 1;
    }

    function selectDefault() {
        var hist = appWindow ? appWindow.transcodeHistory : [];
        if (backend.transcoding && appWindow && appWindow.transcodeQueue.length > 0)
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

    modal: false
    closePolicy: Popup.CloseOnEscape
    // Preferred size from Constants, clamped to the main window (16 margin per side)
    width: appWindow ? Math.min(Constants.dialogWidthTranscode, appWindow.width - 32) : Constants.dialogWidthTranscode
    height: appWindow ? Math.min(Constants.dialogHeightTranscode, appWindow.height - 32) : Constants.dialogHeightTranscode
    x: appWindow ? Math.round((appWindow.width - width) / 2) : 0
    y: appWindow ? Math.round((appWindow.height - height) / 2) : 0
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

        target: appWindow
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
                        if (height > 0 && wasAtBottom)
                            contentY = contentHeight - height;
                    }
                    onHeightChanged: {
                        if (height > 0 && wasAtBottom && contentHeight > 0)
                            contentY = contentHeight - height;
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
                text: backend.transcoding ? qsTr("ffmpeg is running...") : qsTr("Done. You can close this window.")
                color: backend.transcoding ? theme.textSecondary : theme.accent
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: qsTr("Clear")
                visible: !backend.transcoding && (backend.transcodeOutput !== "" || (appWindow && appWindow.transcodeHistory.length > 0))
                onClicked: {
                    if (appWindow)
                        appWindow.transcodeHistory = [];

                    backend.clearTranscodeOutput();
                    root.rebuildEntries();
                    root.selectDefault();
                    recalcProgress();
                }
            }

            Button {
                text: qsTr("Cancel")
                visible: backend.transcoding
                onClicked: appWindow.cancelActiveTranscode()
            }
        }
    }

    background: Rectangle {
        color: theme.bg
    }

    header: Rectangle {
        height: 36
        color: theme.surface

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 4
            spacing: 4

            Label {
                text: {
                    var n = appWindow ? appWindow.transcodeQueue.length : 0;
                    if (backend.transcoding)
                        return n > 1 ? qsTr("Transcoding... (1 of %1)").arg(n) : qsTr("Transcoding...");

                    return qsTr("Transcoding Complete");
                }
                color: theme.textHeader
                font.bold: true
                elide: Text.ElideRight
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: "\u2715"
                flat: true
                implicitWidth: 28
                implicitHeight: 28
                onClicked: root.close()
            }
        }
    }
}
