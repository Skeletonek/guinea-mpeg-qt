import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: "About GuineaMPEG"
    standardButtons: Dialog.Ok
    width: 380

    ColumnLayout {
        spacing: 6
        anchors.fill: parent
        anchors.margins: 20

        Label { text: "GuineaMPEG"; font.pixelSize: 20; font.bold: true; color: "white" }
        Label { text: "FFmpeg Frontend with Rust Core"; color: "#aaa"; font.pixelSize: 12 }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#555"
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        Label { text: "Version: " + buildInfo.version; color: "white" }
        Label { text: "Author: " + buildInfo.author; color: "white" }
        Label { text: "License: " + buildInfo.license; color: "white" }
        Label { text: "Distro: " + buildInfo.distroName; color: "white" }
        Label { text: "Package: " + buildInfo.packageTarget; color: "#888"; font.pixelSize: 11 }
        Label { text: "Build: " + buildInfo.buildDate; color: "#888"; font.pixelSize: 11 }
        Label { text: "Copyright © " + buildInfo.copyright; color: "#888"; font.pixelSize: 11 }
    }
}
