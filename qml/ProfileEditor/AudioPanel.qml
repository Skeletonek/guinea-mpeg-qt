import QtQuick 2.15
import QtQuick.Controls 2.15

Column {
    id: root
    spacing: 8

    property var audioCodecLabels: ["AAC", "Opus", "MP3", "FLAC", "Vorbis"]
    property bool videoEnabled: true
    property string currentCodecKey: "h264"
    property bool loading: false

    signal changed

    readonly property alias audioEnabled: audioEnabledSwitch.checked

    Rectangle {
        width: parent.width
        height: 28
        color: theme.widget
        radius: 4
        Row {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 6
            spacing: 8
            Label {
                text: "Audio"
                color: theme.text
                font.bold: true
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }
            Switch {
                id: audioEnabledSwitch
                checked: true
                onCheckedChanged: if (!root.loading) root.changed()
            }
        }
    }

    Column {
        width: parent.width
        spacing: 8
        visible: audioEnabledSwitch.checked

        Label {
            id: audioCodecAutoLabel
            visible: videoEnabled
            text: "Codec: Auto (" + (currentCodecKey === "h264" ? "AAC" : "Opus") + ")"
            color: theme.textDim
            font.pixelSize: 12
        }

        Label {
            text: "Codec"
            color: theme.textMuted
            font.bold: true
            font.pixelSize: 14
            topPadding: 4
            visible: !videoEnabled
        }
        ComboBox {
            id: audioCodecCombo
            visible: !videoEnabled
            model: audioCodecLabels
            width: parent.width
            onCurrentIndexChanged: if (!root.loading) root.changed()
        }

        Column {
            width: parent.width
            spacing: 6

            Row {
                spacing: 8
                width: parent.width
                visible: !videoEnabled && audioCodecCombo.currentText !== "FLAC"
                Label { text: "Bitrate"; color: theme.textSecondary; width: 80 }
                TextField {
                    id: audioBitrateField
                    width: parent.width - 88
                    placeholderText: "128k"
                    onTextChanged: if (!root.loading) root.changed()
                }
            }
            Row {
                spacing: 8
                width: parent.width
                Label { text: "Channels"; color: theme.textSecondary; width: 80 }
                TextField {
                    id: audioChannelsField
                    width: parent.width - 88
                    placeholderText: "2"
                    validator: IntValidator { bottom: 0; top: 8 }
                    onTextChanged: if (!root.loading) root.changed()
                }
            }
            Row {
                spacing: 8
                width: parent.width
                Label { text: "Sample rate"; color: theme.textSecondary; width: 80 }
                TextField {
                    id: audioSrField
                    width: parent.width - 88
                    placeholderText: "48000"
                    validator: IntValidator { bottom: 0; top: 192000 }
                    onTextChanged: if (!root.loading) root.changed()
                }
            }
        }
    }

    function getData() {
        var audioCodec = (!videoEnabled && audioEnabledSwitch.checked)
            ? audioCodecCombo.currentText || null : null
        var data = {
            audio_enabled: audioEnabledSwitch.checked,
            audio_bitrate: audioCodec === "FLAC" ? "" : (audioBitrateField.text || "128k"),
            audio_channels: audioChannelsField.text ? parseInt(audioChannelsField.text) : null,
            audio_sample_rate: audioSrField.text ? parseInt(audioSrField.text) : null,
            audio_codec: audioCodec
        }
        return data
    }

    function setData(d) {
        audioEnabledSwitch.checked = d.audio_enabled !== false
        audioChannelsField.text = d.audio_channels != null ? String(d.audio_channels) : ""
        audioSrField.text = d.audio_sample_rate != null ? String(d.audio_sample_rate) : ""

        if (d.audio_codec) {
            var aci = audioCodecLabels.indexOf(d.audio_codec)
            audioCodecCombo.currentIndex = aci >= 0 ? aci : 0
            audioBitrateField.text = d.audio_codec === "FLAC" ? "" : (d.audio_bitrate || "128k")
        } else {
            audioCodecCombo.currentIndex = 0
            audioBitrateField.text = d.audio_bitrate || "128k"
        }
    }
}
