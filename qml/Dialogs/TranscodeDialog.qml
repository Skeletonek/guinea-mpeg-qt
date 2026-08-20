import "../Utils/FormatUtils.js" as FormatUtils
import GuineaMpeg 1.0
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root

    property var appWindow: null
    property int _lastOutputLen: 0
    property double _progress: 0
    property double _totalFrames: 0

    function recalcProgress() {
        _lastOutputLen = 0;
        _progress = 0;
        var job = appWindow ? appWindow.activeJob : null;
        if (!job) {
            _totalFrames = 0;
            return;
        }
        var fps = job.targetFps > 0 ? job.targetFps : job.sourceFps;
        _totalFrames = fps > 0 ? Math.round(fps * job.durationMs / 1000) : 0;
    }

    function parseProgress() {
        var fullText = backend.transcodeOutput;
        var newText = fullText.slice(_lastOutputLen);
        _lastOutputLen = fullText.length;
        var re = /frame=\s*(\d+)/g;
        var match, lastMatch;
        while ((match = re.exec(newText)) !== null)
            lastMatch = match;
        if (!lastMatch)
            return;

        var frame = parseInt(lastMatch[1]);
        if (_totalFrames > 0) {
            var p = Math.min(frame / _totalFrames, 1);
            if (p > _progress)
                _progress = p;
        }
    }

    modal: false
    closePolicy: Popup.CloseOnEscape
    width: 700
    height: 500
    onAboutToShow: {
        x = (appWindow.width - width) / 2;
        y = (appWindow.height - height) / 2;
        recalcProgress();
    }

    Connections {
        function onActiveJobChanged() {
            recalcProgress();
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

        Column {
            id: queueStrip

            Layout.fillWidth: true
            spacing: 4
            visible: appWindow && appWindow.transcodeQueue.length > 0

            Repeater {
                model: appWindow ? appWindow.transcodeQueue : []

                delegate: RowLayout {
                    width: queueStrip.width
                    spacing: 8

                    Label {
                        text: index + 1 + "."
                        color: theme.textSecondary
                        font.pixelSize: 12
                    }

                    Label {
                        text: FormatUtils.getFilename(modelData.output)
                        color: index === 0 ? theme.accent : theme.text
                        font.pixelSize: 12
                        font.bold: index === 0
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }

                    Label {
                        text: index === 0 ? (backend.transcoding ? qsTr("Running") : qsTr("Starting")) : qsTr("Waiting")
                        color: index === 0 ? theme.accent : theme.textSecondary
                        font.pixelSize: 12
                    }
                }
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

                    width: parent.width
                    text: backend.transcodeOutput
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
                text: qsTr("Cancel")
                visible: backend.transcoding
                onClicked: backend.cancelTranscode()
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
