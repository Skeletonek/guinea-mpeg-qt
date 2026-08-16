import QtQuick
import QtQuick.Dialogs
import "../Utils/DataUtils.js" as DataUtils

FileDialog {
    id: root
    title: qsTr("Select Video File")
    nameFilters: [qsTr("Media files (*.mp4 *.mkv *.avi *.mov *.webm *.mp3 *.flac *.ogg *.opus *.wav *.aac *.m4a *.wma)")]

    property QtObject appWindow: null

    onAccepted: {
        var path = DataUtils.toLocalPath(root.selectedFile)
        appWindow.loadVideo(path, root.selectedFile)
    }
}
