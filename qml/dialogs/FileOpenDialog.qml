import QtQuick
import QtQuick.Dialogs

FileDialog {
    id: root
    title: "Select Video File"
    nameFilters: ["Video files (*.mp4 *.mkv *.avi *.mov *.webm)"]

    property QtObject appWindow: null

    onAccepted: {
        var path = String(root.selectedFile)
        if (path.startsWith("file://"))
            path = path.substring(7)
        appWindow.loadVideo(path, root.selectedFile)
    }
}
