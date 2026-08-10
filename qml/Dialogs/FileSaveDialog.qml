import QtQuick
import QtQuick.Dialogs

FileDialog {
    id: root
    title: qsTr("Save Transcoded Video As")
    acceptLabel: qsTr("Save")
    fileMode: FileDialog.SaveFile

    property QtObject appWindow: null

    nameFilters: {
        var path = appWindow.outputFilePath
        var dot = path.lastIndexOf(".")
        var ext = dot >= 0 ? path.substring(dot + 1) : "mp4"
        return [ext.toUpperCase() + " (*." + ext + ")"]
    }

    onAccepted: {
        var path = String(root.selectedFile)
        if (path.startsWith("file://"))
            path = decodeURIComponent(path.substring(7))
        appWindow.outputFilePath = path
    }
}
