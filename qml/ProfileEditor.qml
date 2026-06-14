import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "ProfileEditor"
import "Dialogs"
import "Utils/Centering.js" as Utils

Rectangle {
    id: root
    color: theme.bg
    property string profileName: ""
    signal back

    property bool _loading: false
    property var _defaultNames: []
    property bool _isDefaultProfile: _defaultNames.indexOf(profileName) >= 0
    property var _profileNames: []

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
        anchors.margins: 10
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

            Label {
                text: "Profile Editor"
                font.bold: true
                font.pixelSize: 20
                color: theme.text
                bottomPadding: 4
            }

            RowLayout {
                width: parent.width

                Button {
                    text: "\u2190 Back"
                    onClicked: back()
                }

                Label {
                    text: "Profile:"
                    color: theme.textSecondary
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                }

                ComboBox {
                    id: profileSelector
                    Layout.preferredWidth: 300
                    model: root._profileNames
                    displayText: currentIndex < 0 ? "New profile" : currentText
                    onCurrentTextChanged: {
                        if (_loading) return
                        if (currentText && currentText !== profileName)
                            loadProfile(currentText)
                    }
                }

                Button {
                    text: "+ New"
                    onClicked: resetToNew()
                }

                Button {
                    text: "Save"
                    highlighted: true
                    onClicked: saveCurrent()
                }

                Button {
                    text: _isDefaultProfile ? "Restore" : "Delete"
                    visible: profileName !== ""
                    onClicked: _isDefaultProfile ? restoreSingleProfile() : deleteDialog.open()
                }

                Label {
                    id: notifyLabel
                    Layout.leftMargin: 12
                    color: theme.accent
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    visible: false
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "Restore Defaults"
                    onClicked: restoreDialog.open()
                }
            }

            Label {
                text: "Profile name"
                color: theme.textMuted
                font.bold: true
                font.pixelSize: 14
            }
            TextField {
                id: profileNameField
                width: parent.width
                placeholderText: "Enter profile name..."
            }

            Rectangle { width: parent.width; height: 1; color: theme.textDim }

            Row {
                spacing: 20
                width: parent.width

                VideoPanel {
                    id: videoPanel
                    width: parent.width / 2 - 10
                    loading: root._loading
                    onChanged: updatePreview()
                }

                AudioPanel {
                    id: audioPanel
                    width: parent.width / 2 - 10
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
        var data = {}
        var v = videoPanel.getData()
        for (var k in v) data[k] = v[k]
        var a = audioPanel.getData()
        for (var k in a) data[k] = a[k]
        var x = advancedPanel.getData()
        for (var k in x) data[k] = x[k]
        return data
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
        advancedPanel.setPreview("Failed to generate preview")
    }

    function resetToNew() {
        profileName = ""
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
        profileName = name
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
        profileName: root.profileName
        onDeleteRequested: deleteCurrent()
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
            profileNameField.placeholderText = "Name is required!"
            return
        }
        var data = buildCurrentData()
        data.name = name
        backend.saveProfile(name, JSON.stringify(data))
        _defaultNames = JSON.parse(backend.defaultProfileNames())
        _loading = true
        _profileNames = JSON.parse(backend.availableProfiles())
        profileName = name
        profileSelector.currentIndex = _profileNames.indexOf(name)
        _loading = false
        showNotification("Profile \"" + name + "\" saved", theme.accent)
    }

    function deleteCurrent() {
        var deletedName = profileName
        backend.deleteProfile(deletedName)
        _loading = true
        _profileNames = JSON.parse(backend.availableProfiles())
        if (_profileNames.length > 0)
            loadProfile(_profileNames[0])
        else
            resetToNew()
        _loading = false
        showNotification("Profile \"" + deletedName + "\" deleted", "#e66")
    }

    function restoreSingleProfile() {
        var restoredName = profileName
        backend.deleteProfile(restoredName)
        _loading = true
        _profileNames = JSON.parse(backend.availableProfiles())
        loadProfile(restoredName)
        _loading = false
        showNotification("Profile \"" + restoredName + "\" restored to defaults", theme.accent)
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
