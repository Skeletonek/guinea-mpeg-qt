import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: "About GuineaMPEG"
    standardButtons: Dialog.Ok
    width: 380
    padding: 0
    implicitHeight: implicitHeaderHeight + mainLayout.implicitHeight + implicitFooterHeight + 24

    Component.onCompleted: centerInParent()
    onOpened: centerInParent()
    function centerInParent() {
        if (parent) {
            x = Math.round((parent.width - width) / 2)
            y = Math.round((parent.height - height) / 2)
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 8
        spacing: 6

        RowLayout {
            spacing: 12
            ColumnLayout {
                Label { text: "GuineaMPEG"; font.pixelSize: 20; font.bold: true; color: theme.text }
                Label { text: "FFmpeg Frontend with Rust Core"; color: theme.textSecondary; font.pixelSize: 12 }
            }
            Item { Layout.fillWidth: true }
            Image {
                source: "/media/logo/logo.png"
                sourceSize.width: 80
                sourceSize.height: 80
                fillMode: Image.PreserveAspectFit
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.widgetBorder
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        Label { text: "Version: " + buildInfo.version; color: theme.text }
        Label { text: "Author: " + buildInfo.author; color: theme.text }
        Label { text: "License: " + buildInfo.license; color: theme.text }
        Label { text: "OS name: " + buildInfo.distroName; color: theme.text }
        Label { text: "Package: " + buildInfo.packageTarget; color: theme.textMuted; font.pixelSize: 11 }
        Label { text: "Build: " + buildInfo.buildDate; color: theme.textMuted; font.pixelSize: 11 }
        Label { text: "Copyright © " + buildInfo.copyright; color: theme.textMuted; font.pixelSize: 11 }
    }
}
