import "../Utils/DataUtils.js" as DataUtils
import QtQuick
import QtQuick.Dialogs

FileDialog {
    id: root

    property var mainWindow: null

    title: qsTr("Save Transcoded Video As")
    acceptLabel: qsTr("Save")
    fileMode: FileDialog.SaveFile
    nameFilters: {
        var path = mainWindow.outputFilePath;
        var dot = path.lastIndexOf(".");
        var ext = dot >= 0 ? path.substring(dot + 1) : "mp4";
        return [ext.toUpperCase() + " (*." + ext + ")"];
    }
    onAccepted: {
        var path = DataUtils.toLocalPath(root.selectedFile);
        mainWindow.outputFilePath = path;
    }
}
