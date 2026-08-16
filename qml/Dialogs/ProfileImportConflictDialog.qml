import "../Utils/Centering.js" as Utils
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: root

    property string importPath: ""
    property var conflicts: []

    signal importFinished(var summary)
    signal importFailed(string message)

    function doImport(overwrite) {
        var summary = {
        };
        try {
            summary = JSON.parse(backend.importProfiles(root.importPath, overwrite));
        } catch (e) {
        }
        root.close();
        if (summary.error)
            root.importFailed(summary.error);
        else
            root.importFinished(summary);
    }

    title: qsTr("Overwrite Existing Profiles?")
    modal: true
    width: 460
    padding: 16
    topPadding: 8
    implicitHeight: implicitHeaderHeight + mainLayout.implicitHeight + implicitFooterHeight + 24
    Component.onCompleted: Utils.centerInParent(root)
    onOpened: Utils.centerInParent(root)

    ColumnLayout {
        id: mainLayout

        anchors.fill: parent
        spacing: 8

        Label {
            text: qsTr("The following profiles already exist and would be overwritten:")
            color: theme.text
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Frame {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(220, Math.max(60, root.conflicts.length * 26 + 12))
            Layout.maximumHeight: 240

            ScrollView {
                id: scroll

                anchors.fill: parent
                clip: true

                Column {
                    width: scroll.availableWidth

                    Repeater {
                        model: root.conflicts

                        delegate: Label {
                            text: "\u2022 " + modelData
                            color: theme.text
                            wrapMode: Text.ElideRight
                            width: parent.width
                        }

                    }

                }

            }

        }

        Label {
            text: qsTr("\"Skip duplicates\" keeps your existing profiles and imports only the new ones. \"Import all\" replaces them.")
            color: theme.textMuted
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

    }

    footer: DialogButtonBox {
        Button {
            text: qsTr("Skip duplicates")
            onClicked: root.doImport(false)
        }

        Button {
            text: qsTr("Import all")
            highlighted: true
            onClicked: root.doImport(true)
        }

        Button {
            text: qsTr("Cancel")
            onClicked: root.reject()
        }

    }

}
