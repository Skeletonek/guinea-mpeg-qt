import "../Utils/Centering.js" as Utils
import QtMultimedia
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root

    property bool easterEggActivated: false
    property var konamiSequence: [Qt.Key_Up, Qt.Key_Up, Qt.Key_Down, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_Left, Qt.Key_Right, Qt.Key_B, Qt.Key_A]
    property int konamiIndex: 0

    function spawnLettuce() {
        if (easterEggActivated)
            return ;

        easterEggActivated = true;
        lettuceItem.visible = true;
        lettuceItem.x = Math.round((root.width - 64) / 2);
        lettuceItem.y = root.height - 64 - implicitFooterHeight - 16;
    }

    function hideLettuce() {
        lettuceItem.visible = false;
    }

    function checkLettuceDrop(lettuce) {
        var pos = lettuce.mapToItem(guineaPigItem, 0, 0);
        var lx = pos.x;
        var ly = pos.y;
        var rx = lx + lettuce.width;
        var ry = ly + lettuce.height;
        if (rx > 0 && lx < guineaPigItem.width && ry > 0 && ly < guineaPigItem.height)
            eatSound.play();

        hideLettuce();
    }

    function technicalInfo() {
        var lines = [];
        lines.push("GuineaMPEG " + buildInfo.version);
        lines.push("Author: " + buildInfo.author);
        lines.push("License: " + buildInfo.license);
        lines.push("OS: " + buildInfo.distroName);
        lines.push("Architecture: " + buildInfo.cpuArch);
        lines.push("Package: " + buildInfo.packageTarget);
        lines.push("Build: " + buildInfo.buildDate);
        lines.push("Qt: " + buildInfo.qtVersion);
        lines.push("FFmpeg: " + ffmpegVersion);
        lines.push("mpv: " + mpvVersion);
        return lines.join("\n");
    }

    title: qsTr("About GuineaMPEG")
    width: 430
    padding: 16
    topPadding: 8
    implicitHeight: implicitHeaderHeight + mainLayout.implicitHeight + implicitFooterHeight + 24
    Component.onCompleted: Utils.centerInParent(root)
    onOpened: {
        Utils.centerInParent(root);
        keyCatcher.forceActiveFocus();
    }

    SoundEffect {
        id: eatSound

        source: "/media/audio/guinea.wav"
    }

    Item {
        id: keyCatcher

        focus: true
        width: 0
        height: 0
        Keys.onPressed: function(event) {
            if (!easterEggActivated) {
                if (event.key === konamiSequence[konamiIndex]) {
                    konamiIndex++;
                    if (konamiIndex === konamiSequence.length) {
                        konamiIndex = 0;
                        spawnLettuce();
                    }
                } else {
                    konamiIndex = 0;
                }
            }
            event.accepted = false;
        }
    }

    Item {
        id: overlay

        anchors.fill: parent
        z: 999

        Item {
            id: lettuceItem

            visible: false
            width: 64
            height: 64
            z: 100

            Image {
                anchors.fill: parent
                source: "/media/images/lettuce.png"
                sourceSize.width: 64
                sourceSize.height: 64
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                anchors.fill: parent
                drag.target: parent
                cursorShape: Qt.OpenHandCursor
                onReleased: checkLettuceDrop(lettuceItem)
                onCanceled: hideLettuce()
            }

        }

    }

    ColumnLayout {
        id: mainLayout

        anchors.fill: parent
        spacing: 8

        RowLayout {
            spacing: 8

            ColumnLayout {
                Label {
                    text: "GuineaMPEG"
                    font.pixelSize: 20
                    font.bold: true
                    color: theme.text
                }

                Label {
                    text: qsTr("FFmpeg Frontend with Rust Core")
                    color: theme.textSecondary
                    font.pixelSize: 12
                }

            }

            Item {
                Layout.fillWidth: true
            }

            Item {
                id: guineaPigItem

                implicitWidth: 80
                implicitHeight: 80

                Image {
                    anchors.fill: parent
                    source: "/media/logo/logo.png"
                    sourceSize.width: 80
                    sourceSize.height: 80
                    fillMode: Image.PreserveAspectFit
                }

            }

        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.widgetBorder
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                spacing: 8

                Label {
                    text: qsTr("Version: %1").arg(buildInfo.version)
                    color: theme.text
                }

                Label {
                    text: qsTr("Author: %1").arg(buildInfo.author)
                    color: theme.text

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally("https://www.skeletonek.com/")
                    }

                }

                Label {
                    text: qsTr("License: %1").arg(buildInfo.license)
                    color: theme.text
                }

                Label {
                    text: qsTr("OS name: %1").arg(buildInfo.distroName)
                    color: theme.text
                }

                Label {
                    text: qsTr("Package: %1").arg(buildInfo.packageTarget)
                    color: theme.textMuted
                    font.pixelSize: 11
                }

                Label {
                    text: qsTr("Architecture: %1").arg(buildInfo.cpuArch)
                    color: theme.textMuted
                    font.pixelSize: 11
                }

                Label {
                    text: qsTr("Build: %1").arg(buildInfo.buildDate)
                    color: theme.textMuted
                    font.pixelSize: 11
                }

                Label {
                    text: "Copyright © " + buildInfo.copyright
                    color: theme.textMuted
                    font.pixelSize: 11
                }

            }

            Item {
                Layout.fillWidth: true
            }

            Image {
                source: "/media/logo/skeletonek.jpg"
                sourceSize.width: 80
                sourceSize.height: 80
                fillMode: Image.PreserveAspectFit
                Layout.alignment: Qt.AlignTop
            }

        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.widgetBorder
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        Label {
            text: "Qt: %1".arg(buildInfo.qtVersion)
            color: theme.textMuted
            font.pixelSize: 11
        }

        Label {
            text: ffmpegVersion
            color: theme.textMuted
            font.pixelSize: 11
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Label {
            text: mpvVersion
            color: theme.textMuted
            font.pixelSize: 11
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Item {
            Layout.fillHeight: true
        }

    }

    footer: Item {
        implicitWidth: root.width
        implicitHeight: copyButton.implicitHeight + 16

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            Button {
                id: copyButton

                text: qsTr("Copy")
                onClicked: {
                    backend.copyToClipboard(technicalInfo());
                    copyBanner.show();
                }
            }

            Button {
                text: qsTr("OK")
                onClicked: root.accept()
            }

        }

    }

}
