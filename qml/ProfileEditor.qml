import "Components"
import "Dialogs"
import "ProfileEditor"
import "Utils/Constants.js" as Constants
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "Utils/DataUtils.js" as DataUtils

Rectangle {
    id: root

    property string profileName: ""
    property bool _loading: false
    property var _defaultNames: []
    property string _loadedProfileName: ""
    property bool _isDefaultProfile: _defaultNames.indexOf(_loadedProfileName) >= 0
    property var _profileNames: []
    property bool advancedMode: false

    signal back

    function buildCurrentData() {
        return DataUtils.buildProfileData(videoPanel.getData(), audioPanel.getData(), advancedPanel.getData());
    }

    function updatePreview() {
        if (_loading)
            return;

        var data = buildCurrentData();
        var json = JSON.stringify(data);
        var raw = backend.generateCommandPreview(json);
        if (raw) {
            var args = JSON.parse(raw);
            if (args && args.length > 0) {
                advancedPanel.setPreview("ffmpeg " + args.join(" "));
                return;
            }
        }
        advancedPanel.setPreview(qsTr("Failed to generate preview"));
    }

    function enterAdvancedMode() {
        if (_loading || root.advancedMode)
            return;

        var snapshot = buildCurrentData();
        _loading = true;
        var raw = backend.generateCommandPreview(JSON.stringify(snapshot));
        var args = [];
        if (raw)
            args = JSON.parse(raw);

        advancedPanel.setCommand(DataUtils.advancedTemplateFromArgs(args));
        advancedPanel.setContainer(snapshot.container);
        root.advancedMode = true;
        _loading = false;
    }

    function exitAdvancedMode() {
        if (!root.advancedMode)
            return;

        exitAdvancedDialog.open();
    }

    function confirmExitAdvanced() {
        _loading = true;
        root.advancedMode = false;
        advancedPanel.setCommand("");
        _loading = false;
        updatePreview();
    }

    function resetToNew() {
        _loadedProfileName = "";
        root.advancedMode = false;
        profileNameField.text = "";
        profileNameField.placeholderText = "Enter profile name...";
        profileSelector.currentIndex = -1;
        _loading = true;
        videoPanel.setData({
            "codec": "h264",
            "video_enabled": true,
            "rate_control": "crf",
            "preset": null,
            "tune": null,
            "pixel_format": null,
            "resolution": null,
            "framerate": null,
            "tile_rows": null,
            "tile_columns": null,
            "enable_qm": null,
            "crf": null,
            "bitrate": null
        });
        audioPanel.setData({
            "audio_enabled": true,
            "audio_bitrate": "128k",
            "audio_channels": null,
            "audio_sample_rate": null,
            "audio_codec": null
        });
        advancedPanel.setData({
            "extra_args": []
        });
        _loading = false;
        updatePreview();
    }

    function loadProfile(name) {
        _loading = true;
        var raw = backend.loadProfile(name);
        var d = JSON.parse(raw);
        if (!d) {
            if (_profileNames.length > 0) {
                loadProfile(_profileNames[0]);
                return;
            }
            resetToNew();
            _loading = false;
            return;
        }
        _loadedProfileName = name;
        profileNameField.text = name;
        videoPanel.setData(d);
        audioPanel.setData(d);
        advancedPanel.setData(d);
        root.advancedMode = !!(d.custom_command && d.custom_command !== "");
        for (var i = 0; i < _profileNames.length; i++) {
            if (_profileNames[i] === name) {
                profileSelector.currentIndex = i;
                break;
            }
        }
        _loading = false;
        var previewRaw = backend.generateCommandPreview(JSON.stringify(d));
        if (previewRaw) {
            var args = JSON.parse(previewRaw);
            if (args && args.length > 0)
                advancedPanel.setPreview("ffmpeg " + args.join(" "));
        }
    }

    function restoreDefaults() {
        backend.restoreDefaultProfiles();
        _loading = true;
        _profileNames = JSON.parse(backend.availableProfiles());
        if (_profileNames.length > 0)
            loadProfile(_profileNames[0]);
        else
            resetToNew();
        _loading = false;
    }

    function leftGroupWidth() {
        return groupWidth([backBtn, profileCaption, profileSelector, newBtn, saveBtn, restoreDeleteBtn, advancedBtn]);
    }

    function groupWidth(items) {
        var w = 0;
        var count = 0;
        for (var i = 0; i < items.length; i++) {
            if (!items[i].visible)
                continue;

            if (count > 0)
                w += toolbar.spacing;

            w += items[i].width;
            count++;
        }
        return w;
    }

    function showNotification(msg, clr) {
        notifyBanner.text = msg;
        notifyBanner.accentColor = clr || theme.accent;
        notifyBanner.show();
    }

    function saveCurrent() {
        var name = profileNameField.text.trim();
        if (!name) {
            profileNameField.placeholderText = qsTr("Name is required!");
            return;
        }
        var data = buildCurrentData();
        data.name = name;
        backend.saveProfile(name, JSON.stringify(data));
        _defaultNames = JSON.parse(backend.defaultProfileNames());
        _loading = true;
        _profileNames = JSON.parse(backend.availableProfiles());
        _loadedProfileName = name;
        profileSelector.currentIndex = _profileNames.indexOf(name);
        _loading = false;
        showNotification(qsTr("Profile \"%1\" saved").arg(name), theme.accent);
    }

    function deleteCurrent() {
        var deletedName = _loadedProfileName;
        backend.deleteProfile(deletedName);
        _loading = true;
        _profileNames = JSON.parse(backend.availableProfiles());
        if (_profileNames.length > 0)
            loadProfile(_profileNames[0]);
        else
            resetToNew();
        _loading = false;
        showNotification(qsTr("Profile \"%1\" deleted").arg(deletedName), Constants.errorColor);
    }

    function restoreSingleProfile() {
        var restoredName = _loadedProfileName;
        backend.deleteProfile(restoredName);
        _loading = true;
        _profileNames = JSON.parse(backend.availableProfiles());
        loadProfile(restoredName);
        _loading = false;
        showNotification(qsTr("Profile \"%1\" restored to defaults").arg(restoredName), theme.accent);
    }

    function handleImportSummary(summary) {
        _loading = true;
        _profileNames = JSON.parse(backend.availableProfiles());
        _defaultNames = JSON.parse(backend.defaultProfileNames());
        if (_loadedProfileName !== "" && _profileNames.indexOf(_loadedProfileName) >= 0)
            loadProfile(_loadedProfileName);
        else if (_profileNames.length > 0)
            loadProfile(_profileNames[0]);
        else
            resetToNew();
        _loading = false;
        var imported = summary.imported ? summary.imported.length : 0;
        var overwritten = summary.overwritten ? summary.overwritten.length : 0;
        var skipped = summary.skipped ? summary.skipped.length : 0;
        var msg = qsTr("Imported %1, overwritten %2, skipped %3 profile(s)").arg(imported).arg(overwritten).arg(skipped);
        showNotification(msg, theme.accent);
    }

    color: theme.bg
    onProfileNameChanged: _loadedProfileName = profileName
    Component.onCompleted: {
        _loading = true;
        _profileNames = JSON.parse(backend.availableProfiles());
        _defaultNames = JSON.parse(backend.defaultProfileNames());
        Qt.callLater(function () {
            loadProfile(profileName);
            _loading = false;
        });
    }

    InfoBanner {
        id: notifyBanner

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        z: 200
        width: Math.min(Math.max(0, parent.width - 16), 480)
        autoHideMs: 3000
        visible: false
    }

    Flickable {
        id: editorFlickable

        anchors.fill: parent
        anchors.margins: 8
        contentHeight: mainColumn.height + 30
        clip: true

        Column {
            id: mainColumn

            width: editorFlickable.width - (editorScrollBar.visible ? editorScrollBar.width : 0)
            spacing: 16

            RowLayout {
                width: parent.width

                Label {
                    text: qsTr("Profile Editor")
                    font.bold: true
                    font.pixelSize: 20
                    color: theme.text
                    bottomPadding: 4
                }
            }

            Flow {
                id: toolbar

                width: parent.width
                spacing: 8

                Button {
                    id: backBtn

                    text: qsTr("\u2190 Back")
                    onClicked: back()
                }

                Label {
                    id: profileCaption

                    text: qsTr("Profile:")
                    color: theme.textSecondary
                    font.pixelSize: 14
                    height: backBtn.height
                    verticalAlignment: Text.AlignVCenter
                }

                ComboBox {
                    id: profileSelector

                    width: 300
                    model: root._profileNames
                    displayText: currentIndex < 0 ? qsTr("New profile") : currentText
                    onCurrentTextChanged: {
                        if (_loading)
                            return;

                        if (currentText && currentText !== _loadedProfileName)
                            loadProfile(currentText);
                    }
                }

                Button {
                    id: newBtn

                    text: qsTr("+ New")
                    onClicked: resetToNew()
                }

                Button {
                    id: saveBtn

                    text: qsTr("Save")
                    highlighted: true
                    onClicked: saveCurrent()
                }

                Button {
                    id: restoreDeleteBtn

                    text: _isDefaultProfile ? qsTr("Restore") : qsTr("Delete")
                    visible: _loadedProfileName !== ""
                    onClicked: _isDefaultProfile ? restoreSingleProfile() : deleteDialog.open()
                }

                Button {
                    id: advancedBtn

                    text: qsTr("Advanced Mode")
                    checkable: true
                    checked: root.advancedMode
                    onClicked: root.advancedMode ? exitAdvancedMode() : enterAdvancedMode()
                }

                Item {
                    id: toolbarSpacer

                    width: Math.max(0, toolbar.width - leftGroupWidth() - rightGroup.width - toolbar.spacing * 2)
                    height: 1
                }

                Row {
                    id: rightGroup

                    width: rightGroup.implicitWidth
                    spacing: 8

                    Button {
                        id: exportBtn

                        text: qsTr("Export\u2026")
                        onClicked: {
                            exportDialog.profileNames = JSON.parse(backend.userProfileNames());
                            exportDialog.defaultCheckedName = _loadedProfileName;
                            exportDialog.open();
                        }
                    }

                    Button {
                        id: importBtn

                        text: qsTr("Import\u2026")
                        onClicked: importDialog.open()
                    }

                    Button {
                        id: restoreDefaultsBtn

                        text: qsTr("Restore Defaults")
                        onClicked: restoreDialog.open()
                    }
                }
            }

            Label {
                text: qsTr("Profile name")
                color: theme.textMuted
                font.bold: true
                font.pixelSize: 14
            }

            TextField {
                id: profileNameField

                width: parent.width
                placeholderText: qsTr("Enter profile name...")
            }

            Rectangle {
                visible: !root.advancedMode
                width: parent.width
                height: 1
                color: theme.textDim
            }

            Row {
                visible: !root.advancedMode
                spacing: 16
                width: parent.width

                VideoPanel {
                    id: videoPanel

                    width: parent.width / 2 - 8
                    loading: root._loading
                    onChanged: updatePreview()
                }

                AudioPanel {
                    id: audioPanel

                    width: parent.width / 2 - 8
                    loading: root._loading
                    videoEnabled: videoPanel.videoEnabled
                    currentCodecKey: videoPanel.codec
                    container: videoPanel.container
                    onChanged: updatePreview()
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: theme.textDim
            }

            AdvancedPanel {
                id: advancedPanel

                width: parent.width
                loading: root._loading
                advancedMode: root.advancedMode
                onAdvancedCommandChanged: updatePreview()
                onExtraArgsChanged: updatePreview()
            }
        }

        ScrollBar.vertical: ScrollBar {
            id: editorScrollBar

            policy: ScrollBar.AsNeeded
        }
    }

    RestoreDefaultsDialog {
        id: restoreDialog

        onRestoreRequested: restoreDefaults()
    }

    DeleteProfileDialog {
        id: deleteDialog

        profileName: root._loadedProfileName
        onDeleteRequested: deleteCurrent()
    }

    ExitAdvancedDialog {
        id: exitAdvancedDialog

        onExitRequested: confirmExitAdvanced()
    }

    ProfileExportDialog {
        id: exportDialog

        onExportFinished: function (count) {
            showNotification(qsTr("Exported %1 profile(s)").arg(count), theme.accent);
        }
    }

    ProfileImportDialog {
        id: importDialog

        onConflictsFound: function (path, conflicts) {
            conflictDialog.importPath = path;
            conflictDialog.conflicts = conflicts;
            conflictDialog.open();
        }
        onImportFinished: function (summary) {
            handleImportSummary(summary);
        }
        onImportFailed: function (message) {
            showNotification(qsTr("Import failed: %1").arg(message), Constants.errorColor);
        }
    }

    ProfileImportConflictDialog {
        id: conflictDialog

        onImportFinished: function (summary) {
            handleImportSummary(summary);
        }
        onImportFailed: function (message) {
            showNotification(qsTr("Import failed: %1").arg(message), Constants.errorColor);
        }
    }

    EncoderCompatDialog {
        id: compatDialog

        codecLabels: videoPanel.codecLabels
        codecKeys: videoPanel.codecKeys
        availableEncoders: videoPanel._availableEncoders
    }

    Connections {
        function onOpenEncoderCompatDialog() {
            compatDialog.open();
        }

        target: videoPanel
    }
}
