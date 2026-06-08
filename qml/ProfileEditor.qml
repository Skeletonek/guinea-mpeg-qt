import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "ProfileEditor"

Rectangle {
    id: root
    color: theme.bg
    property string profileName: ""
    signal back

    property bool _loading: false

    Flickable {
        anchors.fill: parent
        anchors.margins: 10
        contentHeight: mainColumn.height + 30
        clip: true

        Column {
            id: mainColumn
            width: parent.width
            spacing: 16

            Label {
                text: "Profile Editor"
                font.bold: true
                font.pixelSize: 20
                color: theme.text
                bottomPadding: 4
            }

            // Top bar
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
                    model: {
                        var raw = backend.availableProfiles()
                        try { return JSON.parse(raw) } catch(e) { return [] }
                    }
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
                    text: "Delete"
                    visible: profileName !== ""
                    onClicked: deleteCurrent()
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

            // Two-column layout
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
            profileName = name
            profileNameField.text = name
            _loading = false
            return
        }
        profileName = name
        profileNameField.text = name

        videoPanel.setData(d)
        audioPanel.setData(d)
        advancedPanel.setData(d)

        for (var i = 0; i < profileSelector.model.length; i++) {
            if (profileSelector.model[i] === name) {
                profileSelector.currentIndex = i
                break
            }
        }

        _loading = false
        updatePreview()
    }

    function restoreDefaults() {
        backend.restoreDefaultProfiles()
        var names = JSON.parse(backend.availableProfiles())
        profileSelector.model = names
        if (names.length > 0)
            loadProfile(names[0])
        else
            resetToNew()
    }

    Dialog {
        id: restoreDialog
        title: "Restore Default Profiles"
        standardButtons: Dialog.Yes | Dialog.No
        width: 400
        padding: 0
        implicitHeight: implicitHeaderHeight + msg.implicitHeight + implicitFooterHeight + 24
        Component.onCompleted: centerInParent()
        onOpened: centerInParent()
        function centerInParent() {
            if (parent) {
                x = Math.round((parent.width - width) / 2)
                y = Math.round((parent.height - height) / 2)
            }
        }
        onAccepted: restoreDefaults()

        Label {
            id: msg
            anchors.fill: parent
            anchors.margins: 16
            text: "This will reset all built-in profiles to their original settings.\n\n" +
                  "Custom profiles you created will not be affected.\n\n" +
                  "Continue?"
            color: theme.text
            wrapMode: Text.WordWrap
        }
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
        back()
    }

    function deleteCurrent() {
        backend.deleteProfile(profileName)
        back()
    }

    Component.onCompleted: loadProfile(profileName)
}
