import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia

ApplicationWindow {
    id: appWindow
    width: 1024
    height: 768
    visible: true
    title: qsTr("GuineaMPEG - FFmpeg Frontend")

    property string currentVideoPath: ""
    property var currentVideoInfo: ({})
    property string currentProfile: "av1_high"
    property int videoDuration: 0
    property int startTime: 0
    property int endTime: 0
    property string videoInfoText: "Load a video file to see information"
    property string outputFilePath: ""
    property bool scrubbing: false
    property url videoSource: ""

    menuBar: MenuBar {
        Menu {
            title: qsTr("File")
            MenuItem { text: qsTr("Open Video..."); onTriggered: fileDialog.open() }
            MenuItem { text: qsTr("Exit"); onTriggered: Qt.quit() }
        }
        Menu {
            title: qsTr("Help")
            MenuItem { text: qsTr("About"); onTriggered: aboutDialog.open() }
        }
    }

    MediaPlayer {
        id: player
        source: appWindow.videoSource

        audioOutput: AudioOutput {
            id: audioOutput
            volume: 1.0
        }
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
                color: "#1e1e1e"

                Component.onCompleted: player.videoOutput = videoOutput

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    // Video preview area
                    Rectangle {
                        width: Math.max(100, parent.width - 300 - parent.spacing)
                        height: parent.height
                        color: "black"
                        border.color: "#555"
                        border.width: 1
                        clip: true

                        VideoOutput {
                            id: videoOutput
                            anchors.fill: parent
                            visible: currentVideoPath !== ""
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "No video loaded"
                            color: "white"
                            visible: currentVideoPath === ""
                            font.pixelSize: 18
                        }

                        // Playback controls overlay
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 30
                            color: "#80000000"
                            visible: currentVideoPath !== ""

                            Row {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4

                                Button {
                                    text: player.playbackState === MediaPlayer.PlayingState ? "⏸" : "▶"
                                    width: 40
                                    height: parent.height
                                    onClicked: {
                                        if (player.playbackState === MediaPlayer.PlayingState)
                                            player.pause()
                                        else
                                            player.play()
                                    }
                                }

                                Slider {
                                    id: seekSlider
                                    from: 0
                                    to: player.duration
                                    value: player.position
                                    width: parent.width - 120
                                    height: parent.height
                                    onMoved: player.position = value
                                }

                                Label {
                                    text: formatTime(player.position) + " / " + formatTime(player.duration)
                                    color: "white"
                                    height: parent.height
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }

                    // Controls panel
                    ScrollView {
                        width: 300
                        height: parent.height

                        Column {
                            spacing: 12
                            width: parent.width

                            Label {
                                text: "Video Information"
                                font.bold: true
                                font.pixelSize: 16
                                color: "white"
                            }

                            TextArea {
                                id: videoInfoDisplay
                                readOnly: true
                                text: appWindow.videoInfoText
                                wrapMode: TextArea.Wrap
                                height: 100
                                color: "white"
                            }

                            Label {
                                text: "Transcoding Profile"
                                font.bold: true
                                font.pixelSize: 16
                                color: "white"
                            }

                            ComboBox {
                                id: profileSelector
                                model: {
                                    var p = backend.availableProfiles()
                                    try { return JSON.parse(p) } catch(e) { return [] }
                                }
                                onCurrentTextChanged: currentProfile = currentText
                                width: parent.width
                            }

                            Button {
                                text: "Edit Profile..."
                                onClicked: stackView.push(profileEditorPage)
                                width: parent.width
                            }

                            Label {
                                text: "Timeline Selection"
                                font.bold: true
                                font.pixelSize: 16
                                color: "white"
                            }

                            TimelineControl {
                                id: timeline
                                width: parent.width
                                height: 80
                                videoDuration: appWindow.videoDuration
                                startTime: appWindow.startTime
                                endTime: appWindow.endTime
                                onStartTimeChanged: {
                                    scrubbing = true
                                    appWindow.startTime = startTime
                                    player.position = startTime
                                    scrubbing = false
                                }
                                onEndTimeChanged: {
                                    scrubbing = true
                                    appWindow.endTime = endTime
                                    player.position = endTime
                                    scrubbing = false
                                }
                            }

                            Label {
                                text: "Volume"
                                font.bold: true
                                font.pixelSize: 14
                                color: "white"
                            }

                            Row {
                                spacing: 8
                                width: parent.width

                                Slider {
                                    id: volumeSlider
                                    from: 0
                                    to: 100
                                    value: audioOutput.volume * 100
                                    width: parent.width - 40
                                    height: 30
                                    onMoved: audioOutput.volume = value / 100.0
                                }

                                Label {
                                    text: Math.round(volumeSlider.value) + "%"
                                    color: "white"
                                    width: 30
                                    height: 30
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Label {
                                text: "Output File"
                                font.bold: true
                                font.pixelSize: 14
                                color: "white"
                            }

                            Row {
                                spacing: 5
                                width: parent.width

                                TextField {
                                    id: outputPathField
                                    text: appWindow.outputFilePath
                                    placeholderText: "Output path..."
                                    onTextChanged: appWindow.outputFilePath = text
                                    width: parent.width - 40 - parent.spacing
                                }

                                Button {
                                    id: browseButton
                                    text: "..."
                                    width: 40
                                    onClicked: saveDialog.open()
                                }
                            }

                            Button {
                                text: "Start Transcoding"
                                enabled: currentVideoPath !== "" && endTime > startTime
                                onClicked: startTranscoding()
                                width: parent.width
                            }
                        }
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

    FileDialog {
        id: fileDialog
        title: "Select Video File"
        nameFilters: ["Video files (*.mp4 *.mkv *.avi *.mov *.webm)"]
        onAccepted: {
            appWindow.videoSource = fileDialog.selectedFile
            var path = String(fileDialog.selectedFile)
            if (path.startsWith("file://"))
                path = path.substring(7)
            loadVideo(path)
        }
    }

    FileDialog {
        id: saveDialog
        title: "Save Transcoded Video As"
        acceptLabel: "Save"
        fileMode: FileDialog.SaveFile
        nameFilters: ["MP4 video (*.mp4)", "MKV video (*.mkv)", "WebM video (*.webm)", "All files (*)"]
        onAccepted: {
            var path = String(saveDialog.selectedFile)
            if (path.startsWith("file://"))
                path = path.substring(7)
            appWindow.outputFilePath = path
        }
    }

    Dialog {
        id: aboutDialog
        title: "About GuineaMPEG"
        standardButtons: Dialog.Ok

        Column {
            spacing: 10
            padding: 20
            Label { text: "GuineaMPEG"; font.pixelSize: 20; font.bold: true; color: "white" }
            Label { text: "FFmpeg Frontend with Rust Core"; color: "white" }
            Label { text: "Version 0.1"; color: "white" }
        }
    }

    Dialog {
        id: transcodeDialog
        title: backend.transcoding ? "Transcoding..." : "Transcoding Complete"
        modal: false
        standardButtons: Dialog.Close
        closePolicy: Popup.CloseOnEscape
        width: 700
        height: 500

        onAboutToShow: {
            x = (appWindow.width - width) / 2
            y = (appWindow.height - height) / 2
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                TextArea {
                    id: transcodeOutputDisplay
                    text: backend.transcodeOutput
                    readOnly: true
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: "white"
                    background: Rectangle { color: "#1e1e1e" }
                    onTextChanged: {
                        if (transcodeOutputDisplay.contentHeight > transcodeOutputDisplay.height)
                            transcodeOutputDisplay.cursorPosition = transcodeOutputDisplay.length - 1
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
                    text: "Close"
                    onClicked: transcodeDialog.close()
                }
            }
        }
    }

    function loadVideo(filePath) {
        currentVideoPath = filePath

        var info = backend.getVideoInfo(filePath)
        currentVideoInfo = info
        videoDuration = Math.round(info.duration * 1000)
        endTime = videoDuration

        videoInfoText = "Duration: " + info.duration.toFixed(1) + "s\n" +
                      "Resolution: " + info.width + "x" + info.height + "\n" +
                      "Codec: " + info.codec

        // Default output path (same dir, suffixed with _transcoded)
        var idx = filePath.lastIndexOf("/")
        var name = idx >= 0 ? filePath.substring(idx + 1) : filePath
        var dot = name.lastIndexOf(".")
        var base = dot >= 0 ? name.substring(0, dot) : name
        var dir = idx >= 0 ? filePath.substring(0, idx + 1) : ""
        appWindow.outputFilePath = dir + base + "_transcoded.mp4"

        player.play()
    }

    function startTranscoding() {
        if (appWindow.outputFilePath === "") {
            videoInfoText = "Please set an output file path first"
            return
        }
        var profileJson = backend.loadProfile(currentProfile)
        backend.startTranscode(currentVideoPath, appWindow.outputFilePath,
                                    startTime / 1000.0, endTime / 1000.0,
                                    profileJson)
        transcodeDialog.open()
    }

    function formatTime(ms) {
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        s = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }
}
