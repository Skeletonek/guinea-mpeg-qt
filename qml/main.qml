import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Dialogs"
import "Utils/FormatUtils.js" as FormatUtils
import "Utils/Constants.js" as Constants
import GuineaMpeg 1.0

ApplicationWindow {
    id: appWindow
    width: 1024
    height: 768
    minimumWidth: 1024
    minimumHeight: 768
    visible: true
    title: "GuineaMPEG - FFmpeg Frontend"

    property string currentVideoPath: ""
    property var currentVideoInfo: ({})
    property string currentProfile: "H.264 High"
    property string currentCodec: Constants.codecKeys[0]
    property int videoDuration: 0
    property int startTime: 0
    property int endTime: 0
    property string videoInfoText: "Load a video file to see information"
    property string outputFilePath: ""
    property bool settingTimeline: false
    property url videoSource: ""
    property var videoStreams: []
    property var audioStreams: []
    property var selectedVideoIndices: []
    property var selectedAudioIndices: []

    Component.onCompleted: {
        if (!mpvAvailable)
            mpvWarningDialog.open()
        else if (!ffmpegAvailable)
            ffmpegWarningDialog.open()
        else if (initialFilePath !== "")
            appWindow.loadVideo(initialFilePath)
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

                StackView.onActivated: {
                    controlsPanel.refreshProfiles()
                    appWindow.updateCodec()
                }

                DropArea {
                    anchors.fill: parent
                    onEntered: dragOverlay.visible = true
                    onExited: dragOverlay.visible = false
                    onDropped: function(drop) {
                        dragOverlay.visible = false
                        var url = String(drop.urls[0])
                        if (url.length === 0) return
                        var path = url
                        if (path.startsWith("file://"))
                            path = path.substring(7)
                        appWindow.loadVideo(path, url)
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
                    anchors.margins: 10
                    spacing: 10

                    VideoPreview {
                        id: player
                        width: Math.max(100, parent.width - 300 - parent.spacing)
                        height: parent.height
                        source: appWindow.videoSource
                        hasVideo: currentVideoPath !== ""
                    }

                    ControlsPanel {
                        id: controlsPanel
                        width: 300
                        height: parent.height
                        hostWindow: appWindow
                        playerItem: player

                        onOpenVideoClicked: fileDialog.open()
                        onProfileEditorClicked: {
                            player.pause()
                            stackView.push(profileEditorPage)
                        }
                        onBrowseOutputClicked: {
                            saveDialog.currentFile = "file://" + encodeURI(appWindow.outputFilePath)
                            saveDialog.open()
                        }
                        onViewTranscodeClicked: transcodeDialog.open()
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

    TranscodeDialog {
        id: transcodeDialog
        appWindow: appWindow
    }

    FfmpegWarningDialog {
        id: ffmpegWarningDialog
    }

    MpvWarningDialog {
        id: mpvWarningDialog
    }

    function loadVideo(filePath, fileUrl) {
        currentVideoPath = filePath
        appWindow.videoSource = fileUrl || ("file://" + encodeURI(filePath))

        var info = backend.getVideoInfo(filePath)
        currentVideoInfo = info
        videoDuration = Math.round(info.duration * 1000)
        settingTimeline = true
        startTime = 0
        endTime = videoDuration
        settingTimeline = false
        videoStreams = info.video_streams || []
        audioStreams = info.audio_streams || []
        var vi = []
        for (var v = 0; v < videoStreams.length; v++) vi.push(v)
        selectedVideoIndices = vi
        var ai = []
        for (var a = 0; a < audioStreams.length; a++) ai.push(a)
        selectedAudioIndices = ai

        var name = FormatUtils.getFilename(filePath)
        var fps = FormatUtils.formatFps(info.fps || "0/1")
        videoInfoText = "File: " + name + "\n" +
                      "Duration: " + info.duration.toFixed(1) + "s\n" +
                      "Resolution: " + info.width + "x" + info.height + "\n" +
                      "FPS: " + fps + "\n" +
                      "Video: " + info.codec + "\n" +
                      "Audio: " + (info.audio_codec || "N/A")

        var base = FormatUtils.getBaseFilename(name)
        var dir = FormatUtils.getDirectory(filePath)
        var profileData = {}
        try { profileData = JSON.parse(backend.loadProfile(currentProfile)) } catch(e) {}
        appWindow.outputFilePath = dir + base + "_transcoded." + getExtensionForProfile(profileData)
    }

    function getExtensionForProfile(d) {
        if (d.video_enabled !== false) {
            return Constants.profileExtensions[d.codec] || "webm"
        }
        return Constants.audioExtensions[d.audio_codec] || "ogg"
    }

    function updateCodec() {
        var d
        try {
            d = JSON.parse(backend.loadProfile(currentProfile))
            currentCodec = d.codec || Constants.codecKeys[0]
        } catch(e) {
            currentCodec = Constants.codecKeys[0]
        }
        var ext = getExtensionForProfile(d || {})
        var dot = appWindow.outputFilePath.lastIndexOf(".")
        appWindow.outputFilePath = appWindow.outputFilePath.substring(0, dot >= 0 ? dot : 0) + "." + ext
    }

    function startTranscoding() {
        if (appWindow.outputFilePath === "") {
            videoInfoText = "Please set an output file path first"
            return
        }
        var profile = JSON.parse(backend.loadProfile(currentProfile))
        if (selectedVideoIndices.length > 0)
            profile.video_stream_indices = selectedVideoIndices
        if (selectedAudioIndices.length > 0)
            profile.audio_stream_indices = selectedAudioIndices
        backend.startTranscode(currentVideoPath, appWindow.outputFilePath,
                                    startTime / 1000.0, endTime / 1000.0,
                                    JSON.stringify(profile))
        transcodeDialog.open()
    }
}
