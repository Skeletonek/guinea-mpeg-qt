import QtQuick
import QtQuick.Controls

Dialog {
    id: root
    title: "FFmpeg Not Found"
    standardButtons: Dialog.Ok
    modal: true

    Column {
        spacing: 10
        padding: 20

        Label {
            text: "ffmpeg was not found on your system."
            color: "white"
            font.bold: true
        }
        Label {
            text: "GuineaMPEG requires ffmpeg to transcode videos.\n\n"
                + "Install it with your package manager, e.g.:\n"
                + "  sudo pacman -S ffmpeg    (Arch Linux)\n"
                + "  sudo apt install ffmpeg  (Debian/Ubuntu)\n"
                + "  sudo dnf install ffmpeg  (Fedora)"
            color: "white"
            wrapMode: Text.Wrap
            width: 400
        }
    }

    onAccepted: Qt.quit()
}
