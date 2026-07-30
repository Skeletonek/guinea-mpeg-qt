import QtQuick
import QtQuick.Controls

Dialog {
    id: root
    title: qsTr("MPV Video Backend Not Available")
    standardButtons: Dialog.Ok
    modal: true
    background: Rectangle { color: theme.surface }

    Column {
        spacing: 10
        padding: 20

        Label {
            text: qsTr("The MPV video player backend could not be initialized.")
            color: theme.text
            font.bold: true
        }
        Label {
            text: qsTr("GuineaMPEG requires libmpv to preview videos.\n\nInstall it with your package manager, e.g.:\n  sudo pacman -S mpv    (Arch Linux)\n  sudo apt install libmpv-dev  (Debian/Ubuntu)\n  sudo dnf install mpv-libs  (Fedora)")
            color: theme.text
            wrapMode: Text.Wrap
            width: 400
        }
    }

    onAccepted: Qt.quit()
}
