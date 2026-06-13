import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property QtObject hostWindow: null
    property Item playerItem: null

    property int _profileRevision: 0

    function refreshProfiles() {
        _profileRevision++
    }

    signal openVideoClicked()
    signal profileEditorClicked()
    signal browseOutputClicked()
    signal viewTranscodeClicked()
    signal aboutClicked()

    ScrollView {
        id: rightPanelFlickable
        anchors.top: parent.top
        anchors.bottom: aboutButton.top
        anchors.bottomMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Column {
            id: column
            spacing: 12
            width: rightPanelFlickable.availableWidth

            Label {
                text: "Input File"
                font.bold: true
                font.pixelSize: 16
                color: theme.text
            }

            Button {
                text: "Open Video..."
                onClicked: root.openVideoClicked()
                width: parent.width
            }

            Label {
                text: "Video Information"
                font.bold: true
                font.pixelSize: 16
                color: theme.text
            }

            TextArea {
                id: videoInfoDisplay
                readOnly: true
                text: hostWindow ? hostWindow.videoInfoText : ""
                wrapMode: TextArea.Wrap
                height: 100
                width: parent.width
                color: theme.text
                background: Rectangle { color: theme.bg }
            }

            Label {
                text: "Stream Selection"
                font.bold: true
                font.pixelSize: 16
                color: theme.text
                visible: (hostWindow && hostWindow.videoStreams.length > 1)
                         || (hostWindow && hostWindow.audioStreams.length > 1)
            }

            Label {
                text: "Video"
                color: theme.textMuted
                font.bold: true
                font.pixelSize: 14
                visible: hostWindow && hostWindow.videoStreams.length > 1
            }

            Column {
                spacing: 2
                width: parent.width
                visible: hostWindow && hostWindow.videoStreams.length > 1

                Repeater {
                    model: hostWindow ? hostWindow.videoStreams.length : 0

                    delegate: CheckBox {
                        checked: hostWindow ? hostWindow.selectedVideoIndices.indexOf(index) >= 0 : false
                        text: {
                            if (!hostWindow) return ""
                            var s = hostWindow.videoStreams[index]
                            var fps = ""
                            if (s.fps) {
                                var parts = String(s.fps).split("/")
                                fps = parts.length === 2
                                    ? (parseInt(parts[0]) / parseInt(parts[1])).toFixed(1)
                                    : s.fps
                            }
                            return s.width + "x" + s.height + " " + s.codec + " " + fps + "fps"
                        }
                        onCheckedChanged: {
                            if (!hostWindow) return
                            var arr = hostWindow.selectedVideoIndices.slice()
                            var pos = arr.indexOf(index)
                            if (checked && pos < 0) arr.push(index)
                            else if (!checked && pos >= 0) arr.splice(pos, 1)
                            hostWindow.selectedVideoIndices = arr
                        }
                    }
                }
            }

            Label {
                text: "Audio"
                color: theme.textMuted
                font.bold: true
                font.pixelSize: 14
                visible: hostWindow && hostWindow.audioStreams.length > 1
            }

            Column {
                spacing: 2
                width: parent.width
                visible: hostWindow && hostWindow.audioStreams.length > 1

                Repeater {
                    model: hostWindow ? hostWindow.audioStreams.length : 0

                    delegate: CheckBox {
                        checked: hostWindow ? hostWindow.selectedAudioIndices.indexOf(index) >= 0 : false
                        text: {
                            if (!hostWindow) return ""
                            var s = hostWindow.audioStreams[index]
                            return s.language || "Stream " + (index + 1) + ": " + s.codec
                        }
                        onCheckedChanged: {
                            if (!hostWindow) return
                            var arr = hostWindow.selectedAudioIndices.slice()
                            var pos = arr.indexOf(index)
                            if (checked && pos < 0) arr.push(index)
                            else if (!checked && pos >= 0) arr.splice(pos, 1)
                            hostWindow.selectedAudioIndices = arr
                        }
                    }
                }
            }

            Label {
                text: "Transcoding Profile"
                font.bold: true
                font.pixelSize: 16
                color: theme.text
            }

            ComboBox {
                id: profileSelector
                model: {
                    _profileRevision
                    var p = backend.availableProfiles()
                    try { return JSON.parse(p) } catch(e) { return [] }
                }
                onCurrentTextChanged: {
                    if (hostWindow) {
                        hostWindow.currentProfile = currentText
                        hostWindow.updateCodec()
                    }
                }
                width: parent.width
            }

            Button {
                text: "Profile Editor"
                onClicked: root.profileEditorClicked()
                width: parent.width
            }

            Label {
                text: "Timeline Selection"
                font.bold: true
                font.pixelSize: 16
                color: theme.text
            }

            TimelineControl {
                id: timeline
                width: parent.width
                height: 80
                videoDuration: hostWindow ? hostWindow.videoDuration : 0
                startTime: hostWindow ? hostWindow.startTime : 0
                endTime: hostWindow ? hostWindow.endTime : 0
                onStartTimeChanged: {
                    if (!hostWindow || hostWindow.settingTimeline) return
                    hostWindow.startTime = startTime
                    if (playerItem) playerItem.position = startTime
                }
                onEndTimeChanged: {
                    if (!hostWindow || hostWindow.settingTimeline) return
                    hostWindow.endTime = endTime
                    if (playerItem) playerItem.position = endTime
                }
            }

            Label {
                text: "Output File"
                font.bold: true
                font.pixelSize: 14
                color: theme.text
            }

            Row {
                spacing: 5
                width: parent.width

                TextField {
                    id: outputPathField
                    text: hostWindow ? hostWindow.outputFilePath : ""
                    placeholderText: "Output path..."
                    onTextChanged: {
                        if (hostWindow) hostWindow.outputFilePath = text
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

            Button {
                text: "Start Transcoding"
                enabled: hostWindow && hostWindow.currentVideoPath !== "" && hostWindow.endTime > hostWindow.startTime
                onClicked: {
                    if (playerItem) playerItem.pause()
                    if (hostWindow) hostWindow.startTranscoding()
                }
                width: parent.width
            }

            Label {
                text: "Transcoding in progress... (click to view)"
                color: theme.accent
                visible: backend.transcoding
                width: parent.width
                wrapMode: Text.WordWrap
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.viewTranscodeClicked()
                }
            }
        }
    }

    Button {
        id: aboutButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        width: 48
        height: 48
        icon.name: "help-about-symbolic"
        icon.source: "/media/icons/info.png"
        icon.width: 32
        icon.height: 32
        display: Button.IconOnly
        onClicked: root.aboutClicked()
    }
}
