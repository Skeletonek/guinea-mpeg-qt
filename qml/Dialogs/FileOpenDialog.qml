import "../Utils/DataUtils.js" as DataUtils
import QtQuick
import QtQuick.Dialogs

FileDialog {
    id: root

    property var mainWindow: null
    // append=false starts a fresh batch on accept (Open File), append=true extends it (Add Files)
    property bool appendMode: false

    readonly property string videoExts: "*.mp4 *.mkv *.avi *.mov *.webm *.m4v *.3gp *.3g2 *.flv *.mpg *.mpeg *.m2ts *.ts *.vob *.ogv *.divx *.asf *.f4v *.mts *.m2v *.mxf *.dv *.wmv *.rm"
    readonly property string audioExts: "*.mp3 *.flac *.ogg *.opus *.wav *.aac *.m4a *.wma *.aiff *.aif *.mka *.ac3 *.dts *.amr *.mid *.midi *.ape *.wv *.caf *.au *.mp2 *.tta"

    fileMode: FileDialog.OpenFiles
    title: qsTr("Select Media Files")
    nameFilters: [qsTr("Media files (%1 %2)").arg(root.videoExts).arg(root.audioExts), qsTr("Video files (%1)").arg(root.videoExts), qsTr("Audio files (%1)").arg(root.audioExts), qsTr("All files (*)")]
    onAccepted: {
        var paths = [];
        var urls = root.selectedFiles;
        for (var i = 0; i < urls.length; i++)
            paths.push(DataUtils.toLocalPath(urls[i]));
        mainWindow.openFiles(paths, !root.appendMode);
    }
}
