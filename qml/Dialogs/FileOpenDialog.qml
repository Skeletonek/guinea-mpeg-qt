import "../Utils/DataUtils.js" as DataUtils
import QtQuick
import QtQuick.Dialogs

FileDialog {
    id: root

    property var appWindow: null

    title: qsTr("Select Video File")
    nameFilters: [
        qsTr("Video files (*.mp4 *.mkv *.avi *.mov *.webm *.m4v *.3gp *.3g2 *.flv *.mpg *.mpeg *.m2ts *.ts *.vob *.ogv *.divx *.asf *.f4v *.mts *.m2v *.mxf *.dv *.wmv *.rm)"),
        qsTr("Audio files (*.mp3 *.flac *.ogg *.opus *.wav *.aac *.m4a *.wma *.aiff *.aif *.mka *.ac3 *.dts *.amr *.mid *.midi *.ape *.wv *.caf *.au *.mp2 *.tta)"),
        qsTr("All files (*)")
    ]
    onAccepted: {
        var path = DataUtils.toLocalPath(root.selectedFile);
        appWindow.loadVideo(path, root.selectedFile);
    }
}
