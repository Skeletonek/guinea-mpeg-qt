import QtQuick
import QtQuick.Controls

Dialog {
    id: root
    title: qsTr("FFmpeg Not Found")
    standardButtons: Dialog.Ok
    modal: true
    background: Rectangle { color: theme.surface }

    Column {
        spacing: 8
        padding: 16

        Label {
            text: qsTr("ffmpeg was not found on your system.")
            color: theme.text
            font.bold: true
        }
        Label {
            text: qsTr("GuineaMPEG requires ffmpeg to transcode videos.\n\nInstall it with your package manager, e.g.:\n  sudo pacman -S ffmpeg    (Arch Linux)\n  sudo apt install ffmpeg  (Debian/Ubuntu)\n  sudo dnf install ffmpeg  (Fedora)")
            color: theme.text
            wrapMode: Text.Wrap
            width: 400
        }
    }

    onAccepted: Qt.quit()
}
