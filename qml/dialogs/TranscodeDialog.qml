import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GuineaMpeg 1.0

Dialog {
    id: root
    modal: false
    closePolicy: Popup.CloseOnEscape
    width: 700
    height: 500

    property QtObject appWindow: null

    header: Rectangle {
        height: 36
        color: "#2d2d2d"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 4
            spacing: 4

            Label {
                text: backend.transcoding ? "Transcoding..." : "Transcoding Complete"
                color: "#eee"
                font.bold: true
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "✕"
                flat: true
                implicitWidth: 28
                implicitHeight: 28
                onClicked: root.close()
            }
        }
    }

    onAboutToShow: {
        x = (appWindow.width - width) / 2
        y = (appWindow.height - height) / 2
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1e1e1e"

            Flickable {
                id: transcodeFlickable
                anchors.fill: parent
                anchors.margins: 4
                contentHeight: outputDisplay.contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                property bool wasAtBottom: true

                onContentYChanged: {
                    if (height <= 0) return
                    wasAtBottom = (contentY >= contentHeight - height - 1)
                }

                onContentHeightChanged: {
                    if (height > 0 && wasAtBottom)
                        contentY = contentHeight - height
                }

                onHeightChanged: {
                    if (height > 0 && wasAtBottom && contentHeight > 0)
                        contentY = contentHeight - height
                }

                TextEdit {
                    id: outputDisplay
                    width: parent.width
                    text: backend.transcodeOutput
                    readOnly: true
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: "white"
                    wrapMode: TextEdit.Wrap
                    selectByMouse: false
                    textFormat: TextEdit.PlainText
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: backend.transcoding ? "ffmpeg is running..." : "Done. You can close this window."
                color: backend.transcoding ? "#aaa" : "#4a9eff"
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Cancel"
                visible: backend.transcoding
                onClicked: backend.cancelTranscode()
            }
        }
    }
}
