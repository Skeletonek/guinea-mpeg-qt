import "../Components"
import "../Utils/Constants.js" as Constants
import "../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15

AppDialog {
    id: root

    property var profileNames: []
    property string defaultCheckedName: ""
    property int selectedCount: 0

    signal exportFinished(int count)

    function refreshCount() {
        var n = 0;
        for (var i = 0; i < profilesModel.count; i++)
            if (profilesModel.get(i).checked) {
                n++;
            }
        selectedCount = n;
    }

    function setAll(checked) {
        for (var i = 0; i < profilesModel.count; i++)
            profilesModel.setProperty(i, "checked", checked);
        refreshCount();
    }

    function selectedNames() {
        var arr = [];
        for (var i = 0; i < profilesModel.count; i++)
            if (profilesModel.get(i).checked) {
                arr.push(profilesModel.get(i).name);
            }
        return arr;
    }

    function suggestedFileName() {
        var n = selectedNames();
        var base = n.length === 1 ? n[0] : "GuineaMPEG_Profiles";
        return base + ".toml";
    }

    title: qsTr("Export Profiles")
    width: Constants.dialogWidthLarge
    contentImplicitHeight: mainLayout.implicitHeight
    onOpened: {
        profilesModel.clear();
        for (var i = 0; i < root.profileNames.length; i++)
            profilesModel.append({
                "name": root.profileNames[i],
                "checked": root.profileNames[i] === root.defaultCheckedName
            });
        root.refreshCount();
    }

    ListModel {
        id: profilesModel
    }

    FileDialog {
        id: fileDialog

        title: qsTr("Export Profiles To")
        fileMode: FileDialog.SaveFile
        acceptLabel: qsTr("Export")
        nameFilters: [qsTr("TOML files (*.toml)")]
        onAccepted: {
            var path = DataUtils.toLocalPath(fileDialog.selectedFile);
            if (path.toLowerCase().lastIndexOf(".toml") !== path.length - 5)
                path += ".toml";

            if (backend.exportProfiles(path, JSON.stringify(root.selectedNames()))) {
                root.close();
                root.exportFinished(root.selectedNames().length);
            } else {
                errorLabel.visible = true;
            }
        }
    }

    ColumnLayout {
        id: mainLayout

        anchors.fill: parent
        spacing: 8

        Label {
            text: root.profileNames.length === 0 ? qsTr("No user-created profiles to export.") : qsTr("Select profiles to export:")
            color: theme.text
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        ScrollView {
            id: scroll

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(360, Math.max(80, root.profileNames.length * 32 + 8))
            visible: root.profileNames.length > 0
            clip: true

            Column {
                width: scroll.availableWidth

                Repeater {
                    model: profilesModel

                    delegate: CheckBox {
                        text: model.name
                        width: parent.width
                        checked: model.checked
                        onClicked: {
                            profilesModel.setProperty(index, "checked", checked);
                            root.refreshCount();
                        }
                    }
                }
            }
        }

        Label {
            id: errorLabel

            text: qsTr("Export failed. Please check the destination path.")
            color: Constants.errorColor
            visible: false
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    footer: DialogButtonBox {
        Button {
            text: qsTr("Select All")
            visible: root.profileNames.length > 0
            onClicked: root.setAll(true)
        }

        Button {
            text: qsTr("Select None")
            visible: root.profileNames.length > 0
            onClicked: root.setAll(false)
        }

        Button {
            text: qsTr("Cancel")
            onClicked: root.reject()
        }

        Button {
            text: qsTr("Export\u2026")
            highlighted: true
            enabled: root.selectedCount > 0
            onClicked: {
                var name = encodeURIComponent(root.suggestedFileName());
                var folder = fileDialog.currentFolder;
                fileDialog.currentFile = (folder && String(folder).indexOf("undefined") < 0) ? folder + "/" + name : name;
                fileDialog.open();
            }
        }
    }
}
