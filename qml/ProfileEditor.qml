import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "ProfileEditor"
import "Dialogs"
import "Utils/DataUtils.js" as DataUtils

Rectangle {
    id: root
    color: theme.bg
    property string profileName: ""
    signal back

    property bool _loading: false
    property var _defaultNames: []
    property string _loadedProfileName: ""
    property bool _isDefaultProfile: _defaultNames.indexOf(_loadedProfileName) >= 0
    property var _profileNames: []

    onProfileNameChanged: _loadedProfileName = profileName

    Timer {
        id: notifyTimer
        interval: 3000
        onTriggered: {
            notifyLabel.opacity = 0
            notifyCollapseTimer.start()
        }
    }
    Timer {
        id: notifyCollapseTimer
        interval: 350
        onTriggered: notifyLabel.visible = false
    }

    Flickable {
        id: editorFlickable
        anchors.fill: parent
        anchors.margins: 8
        contentHeight: mainColumn.height + 30
        clip: true

        ScrollBar.vertical: ScrollBar {
            id: editorScrollBar
            policy: ScrollBar.AsNeeded
        }

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

                Item { Layout.fillWidth: true }

                Label {
                    id: notifyLabel
                    Layout.leftMargin: 8
                    Layout.maximumWidth: 360
                    color: theme.accent
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    visible: false
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
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
                        if (_loading) return
                        if (currentText && currentText !== _loadedProfileName)
                            loadProfile(currentText)
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

                Item {
                    id: toolbarSpacer
                    width: Math.max(0, toolbar.width - leftGroupWidth()
                                    - rightGroup.width - toolbar.spacing * 2)
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
                            exportDialog.profileNames = JSON.parse(backend.userProfileNames())
                            exportDialog.defaultCheckedName = _loadedProfileName
                            exportDialog.open()
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

            Rectangle { width: parent.width; height: 1; color: theme.textDim }

            Row {
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
                    onChanged: updatePreview()
                }
            }

            Rectangle { width: parent.width; height: 1; color: theme.textDim }

            AdvancedPanel {
                id: advancedPanel
                width: parent.width
                loading: root._loading
                onExtraArgsChanged: updatePreview()
            }
        }
    }

    function buildCurrentData() {
        return DataUtils.buildProfileData(
            videoPanel.getData(),
            audioPanel.getData(),
            advancedPanel.getData()
        )
    }

    function updatePreview() {
        if (_loading) return
        var data = buildCurrentData()
        var json = JSON.stringify(data)
        var raw = backend.generateCommandPreview(json)
        if (raw) {
            var args = JSON.parse(raw)
            if (args && args.length > 0) {
                advancedPanel.setPreview("ffmpeg " + args.join(" "))
                return
            }
        }
        advancedPanel.setPreview(qsTr("Failed to generate preview"))
    }

    function resetToNew() {
        _loadedProfileName = ""
        profileNameField.text = ""
        profileNameField.placeholderText = "Enter profile name..."
        profileSelector.currentIndex = -1
        _loading = true
        videoPanel.setData({
            codec: "h264", video_enabled: true, rate_control: "crf",
            preset: null, tune: null, pixel_format: null,
            resolution: null, framerate: null,
            tile_rows: null, tile_columns: null, enable_qm: null,
            crf: null, bitrate: null
        })
        audioPanel.setData({
            audio_enabled: true, audio_bitrate: "128k",
            audio_channels: null, audio_sample_rate: null,
            audio_codec: null
        })
        advancedPanel.setData({ extra_args: [] })
        _loading = false
        updatePreview()
    }

    function loadProfile(name) {
        _loading = true
        var raw = backend.loadProfile(name)
        var d = JSON.parse(raw)
        if (!d) {
            if (_profileNames.length > 0) {
                loadProfile(_profileNames[0])
                return
            }
            resetToNew()
            _loading = false
            return
        }
        _loadedProfileName = name
        profileNameField.text = name

        videoPanel.setData(d)
        audioPanel.setData(d)
        advancedPanel.setData(d)

        for (var i = 0; i < _profileNames.length; i++) {
            if (_profileNames[i] === name) {
                profileSelector.currentIndex = i
                break
            }
        }

        _loading = false
        var previewRaw = backend.generateCommandPreview(JSON.stringify(d))
        if (previewRaw) {
            var args = JSON.parse(previewRaw)
            if (args && args.length > 0) {
                advancedPanel.setPreview("ffmpeg " + args.join(" "))
            }
        }
    }

    function restoreDefaults() {
        backend.restoreDefaultProfiles()
        _loading = true
        _profileNames = JSON.parse(backend.availableProfiles())
        if (_profileNames.length > 0)
            loadProfile(_profileNames[0])
        else
            resetToNew()
        _loading = false
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

    ProfileExportDialog {
        id: exportDialog
        onExportFinished: function(count) {
            showNotification(qsTr("Exported %1 profile(s)").arg(count), theme.accent)
        }
    }

    ProfileImportDialog {
        id: importDialog
        onConflictsFound: function(path, conflicts) {
            conflictDialog.importPath = path
            conflictDialog.conflicts = conflicts
            conflictDialog.open()
        }
        onImportFinished: function(summary) {
            handleImportSummary(summary)
        }
        onImportFailed: function(message) {
            showNotification(qsTr("Import failed: %1").arg(message), "#e66")
        }
    }

    ProfileImportConflictDialog {
        id: conflictDialog
        onImportFinished: function(summary) {
            handleImportSummary(summary)
        }
        onImportFailed: function(message) {
            showNotification(qsTr("Import failed: %1").arg(message), "#e66")
        }
    }

    EncoderCompatDialog {
        id: compatDialog
        codecLabels: videoPanel.codecLabels
        codecKeys: videoPanel.codecKeys
        availableEncoders: videoPanel._availableEncoders
    }

    Connections {
        target: videoPanel
        function onOpenEncoderCompatDialog() { compatDialog.open() }
    }

    function leftGroupWidth() {
        return groupWidth([backBtn, profileCaption, profileSelector, newBtn, saveBtn, restoreDeleteBtn])
    }

    function groupWidth(items) {
        var w = 0
        var count = 0
        for (var i = 0; i < items.length; i++) {
            if (!items[i].visible) continue
            if (count > 0) w += toolbar.spacing
            w += items[i].width
            count++
        }
        return w
    }

    function showNotification(msg, clr) {
        notifyLabel.text = msg
        notifyLabel.color = clr || theme.accent
        notifyLabel.visible = true
        notifyLabel.opacity = 1
        notifyTimer.restart()
    }

    function saveCurrent() {
        var name = profileNameField.text.trim()
        if (!name) {
            profileNameField.placeholderText = qsTr("Name is required!")
            return
        }
        var data = buildCurrentData()
        data.name = name
        backend.saveProfile(name, JSON.stringify(data))
        _defaultNames = JSON.parse(backend.defaultProfileNames())
        _loading = true
        _profileNames = JSON.parse(backend.availableProfiles())
        _loadedProfileName = name
        profileSelector.currentIndex = _profileNames.indexOf(name)
        _loading = false
        showNotification(qsTr("Profile \"%1\" saved").arg(name), theme.accent)
    }

    function deleteCurrent() {
        var deletedName = _loadedProfileName
        backend.deleteProfile(deletedName)
        _loading = true
        _profileNames = JSON.parse(backend.availableProfiles())
        if (_profileNames.length > 0)
            loadProfile(_profileNames[0])
        else
            resetToNew()
        _loading = false
        showNotification(qsTr("Profile \"%1\" deleted").arg(deletedName), "#e66")
    }

    function restoreSingleProfile() {
        var restoredName = _loadedProfileName
        backend.deleteProfile(restoredName)
        _loading = true
        _profileNames = JSON.parse(backend.availableProfiles())
        loadProfile(restoredName)
        _loading = false
        showNotification(qsTr("Profile \"%1\" restored to defaults").arg(restoredName), theme.accent)
    }

    function handleImportSummary(summary) {
        _loading = true
        _profileNames = JSON.parse(backend.availableProfiles())
        _defaultNames = JSON.parse(backend.defaultProfileNames())
        if (_loadedProfileName !== "" && _profileNames.indexOf(_loadedProfileName) >= 0)
            loadProfile(_loadedProfileName)
        else if (_profileNames.length > 0)
            loadProfile(_profileNames[0])
        else
            resetToNew()
        _loading = false
        var imported = summary.imported ? summary.imported.length : 0
        var overwritten = summary.overwritten ? summary.overwritten.length : 0
        var skipped = summary.skipped ? summary.skipped.length : 0
        var msg = qsTr("Imported %1, overwritten %2, skipped %3 profile(s)")
            .arg(imported).arg(overwritten).arg(skipped)
        showNotification(msg, theme.accent)
    }

    Component.onCompleted: {
        _loading = true
        _profileNames = JSON.parse(backend.availableProfiles())
        _defaultNames = JSON.parse(backend.defaultProfileNames())
        Qt.callLater(function() {
            loadProfile(profileName)
            _loading = false
        })
    }
}
