import QtQuick
import QtQuick.Dialogs

FileDialog {
    id: root
    title: qsTr("Select Video File")
    nameFilters: [qsTr("Media files (*.mp4 *.mkv *.avi *.mov *.webm *.mp3 *.flac *.ogg *.opus *.wav *.aac *.m4a *.wma)")]

    property QtObject appWindow: null

    onAccepted: {
        var path = String(root.selectedFile)
        if (path.startsWith("file://"))
            path = path.substring(7)
        appWindow.loadVideo(path, root.selectedFile)
    }
}
