import "../Utils/DataUtils.js" as DataUtils
import QtQuick
import QtQuick.Dialogs

FileDialog {
    id: root

    property var appWindow: null

    title: qsTr("Select Video File")
    nameFilters: [qsTr("Media files (*.mp4 *.mkv *.avi *.mov *.webm *.mp3 *.flac *.ogg *.opus *.wav *.aac *.m4a *.wma)")]
    onAccepted: {
        var path = DataUtils.toLocalPath(root.selectedFile);
        appWindow.loadVideo(path, root.selectedFile);
    }
}
