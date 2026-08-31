import "../Components" as Components
import QtQuick

Components.WarningDialog {
    id: root

    title: qsTr("MPV Video Backend Not Available")
    headline: qsTr("The MPV video player backend could not be initialized.")
    body: qsTr("GuineaMPEG requires libmpv to preview videos.\n\nInstall it with your package manager, e.g.:\n  sudo pacman -S mpv    (Arch Linux)\n  sudo apt install libmpv-dev  (Debian/Ubuntu)\n  sudo dnf install mpv-libs  (Fedora)")
    onAccepted: Qt.quit()
}
