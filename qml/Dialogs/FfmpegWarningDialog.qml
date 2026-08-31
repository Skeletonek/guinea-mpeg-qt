import "../Components" as Components
import QtQuick

Components.WarningDialog {
    id: root

    title: qsTr("FFmpeg Not Found")
    headline: qsTr("ffmpeg was not found on your system.")
    body: qsTr("GuineaMPEG requires ffmpeg to transcode videos.\n\nInstall it with your package manager, e.g.:\n  sudo pacman -S ffmpeg    (Arch Linux)\n  sudo apt install ffmpeg  (Debian/Ubuntu)\n  sudo dnf install ffmpeg  (Fedora)")
    onAccepted: Qt.quit()
}
