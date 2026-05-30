import QtQuick
import QtQuick.Dialogs

FileDialog {
    id: root
    title: "Save Transcoded Video As"
    acceptLabel: "Save"
    fileMode: FileDialog.SaveFile

    property QtObject appWindow: null

    nameFilters: {
        var ext = appWindow.getExtensionForCodec(appWindow.currentCodec)
        return [ext.toUpperCase() + " video (*." + ext + ")"]
    }

    onAccepted: {
        var path = String(root.selectedFile)
        if (path.startsWith("file://"))
            path = path.substring(7)
        appWindow.outputFilePath = path
    }
}
