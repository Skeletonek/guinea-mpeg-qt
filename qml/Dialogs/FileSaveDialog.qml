import QtQuick
import QtQuick.Dialogs
import "../Utils/DataUtils.js" as DataUtils

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
        var path = DataUtils.toLocalPath(root.selectedFile)
        appWindow.outputFilePath = path
    }
}
