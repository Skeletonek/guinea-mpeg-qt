import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    color: "#1e1e1e"
    property string profileName: ""
    signal back

    property var codecKeys: ["h264", "vp8", "vp9", "svtav1"]
    property var codecLabels: ["H.264", "VP8", "VP9", "AV1 (SVT-AV1)"]
    property var resOptions: ["native", "360p", "480p", "720p", "1080p", "1440p", "2160p"]
    property var fpsOptions: ["source", 20, 23.976, 25, 30, 40, 45, 50, 60]
    property var tuneByCodec: {
        "h264": ["film", "grain", "animation", "psnr", "ssim", "fastdecode", "zerolatency"],
        "vp8": ["psnr", "ssim", "good", "best"],
        "vp9": ["psnr", "ssim", "good", "best"],
        "svtav1": ["psnr", "ssim", "vmaf"]
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 10
        contentHeight: formColumn.height + 60
        clip: true

        Column {
            id: formColumn
            width: parent.width
            spacing: 8

            Row {
                spacing: 10
                Button {
                    text: "\u2190 Back"
                    onClicked: back()
                }
                Label {
                    text: profileName ? "Edit Profile: " + profileName : "New Profile"
                    font.pixelSize: 18
                    font.bold: true
                    color: "white"
                    verticalAlignment: Text.AlignVCenter
                }
                Item { width: 20 }
                Button {
                    text: "Delete"
                    visible: profileName !== ""
                    onClicked: deleteCurrent()
                }
                Button {
                    text: "Save"
                    highlighted: true
                    onClicked: saveCurrent()
                }
            }

            TextField {
                id: newProfileNameField
                visible: profileName === ""
                width: parent.width
                placeholderText: "Enter profile name..."
            }

            Label { text: "Codec"; color: "#888"; font.bold: true; font.pixelSize: 14; topPadding: 8 }
            ComboBox {
                id: codecCombo
                model: codecLabels
                width: parent.width
                onCurrentIndexChanged: rebuildTuneModel()
            }

            Label { text: "Video Quality"; color: "#888"; font.bold: true; font.pixelSize: 14; topPadding: 8 }
            Grid {
                columns: 2
                columnSpacing: 8
                rowSpacing: 6
                width: parent.width

                Label { text: "CRF"; color: "#aaa" }
                TextField {
                    id: crfField
                    width: 120; placeholderText: "e.g. 18"
                    validator: IntValidator { bottom: 0; top: 63 }
                }
                Label { text: "Bitrate (video)"; color: "#aaa" }
                TextField {
                    id: bitrateField
                    width: 160; placeholderText: "e.g. 2M"
                }
                Label { text: "Preset"; color: "#aaa" }
                TextField {
                    id: presetField
                    width: 200; placeholderText: "x264: slow/medium…  svtav1: 0-13"
                }
                Label { text: "Tune"; color: "#aaa" }
                ComboBox {
                    id: tuneCombo
                    width: 200; editable: true
                    model: ["film", "grain", "animation", "psnr", "ssim", "fastdecode", "zerolatency"]
                }
                Label { text: "Pixel format"; color: "#aaa" }
                TextField {
                    id: pixfmtField
                    width: 120; placeholderText: "yuv420p"
                }
            }

            Label { text: "Scaling"; color: "#888"; font.bold: true; font.pixelSize: 14; topPadding: 8 }
            Grid {
                columns: 2
                columnSpacing: 8
                rowSpacing: 6
                width: parent.width

                Label { text: "Resolution"; color: "#aaa" }
                ComboBox {
                    id: resCombo
                    model: resOptions
                    width: 200
                }
                Label { text: "Framerate"; color: "#aaa" }
                ComboBox {
                    id: fpsCombo
                    model: fpsOptions
                    width: 200; editable: true
                    validator: DoubleValidator { bottom: 0; top: 120 }
                }
            }

            Column {
                width: parent.width
                visible: codecKeys[codecCombo.currentIndex] === "svtav1"
                spacing: 6
                Label { text: "AV1 (SVT-AV1)"; color: "#888"; font.bold: true; font.pixelSize: 14; topPadding: 8 }
                Grid {
                    columns: 4
                    columnSpacing: 8
                    rowSpacing: 6
                    width: parent.width
                    Label { text: "Tile rows"; color: "#aaa" }
                    TextField { id: tileRowsField; width: 60; placeholderText: "2"; validator: IntValidator { bottom: 0; top: 8 } }
                    Label { text: "Tile cols"; color: "#aaa" }
                    TextField { id: tileColsField; width: 60; placeholderText: "3"; validator: IntValidator { bottom: 0; top: 8 } }
                }
                CheckBox { id: enableQmCheck; text: "Enable Quantization Matrix" }
            }

            Label { text: "Audio"; color: "#888"; font.bold: true; font.pixelSize: 14; topPadding: 8 }
            Label { text: "Codec auto-selected: " + (codecKeys[codecCombo.currentIndex] === "h264" ? "AAC" : "Opus"); color: "#666"; font.pixelSize: 12 }
            Grid {
                columns: 2
                columnSpacing: 8
                rowSpacing: 6
                width: parent.width

                Label { text: "Bitrate"; color: "#aaa" }
                TextField {
                    id: audioBitrateField
                    width: 120; placeholderText: "128k"
                }
                Label { text: "Channels"; color: "#aaa" }
                TextField {
                    id: audioChannelsField
                    width: 80; placeholderText: "2"
                    validator: IntValidator { bottom: 0; top: 8 }
                }
                Label { text: "Sample rate"; color: "#aaa" }
                TextField {
                    id: audioSrField
                    width: 100; placeholderText: "48000"
                    validator: IntValidator { bottom: 0; top: 192000 }
                }
            }

            Label { text: "Advanced"; color: "#888"; font.bold: true; font.pixelSize: 14; topPadding: 8 }
            Label { text: "Extra FFmpeg arguments"; color: "#aaa"; font.pixelSize: 12 }
            TextField {
                id: extraArgsField
                width: parent.width
                placeholderText: "e.g. -row-mt 1 -tiles 2x2"
            }
        }
    }

    function rebuildTuneModel() {
        var codec = codecKeys[codecCombo.currentIndex]
        var tunes = tuneByCodec[codec] || []
        var prev = tuneCombo.currentText
        tuneCombo.model = tunes
        var idx = tunes.indexOf(prev)
        tuneCombo.currentIndex = idx >= 0 ? idx : 0
    }

    function loadProfile(name) {
        var raw = backend.loadProfile(name)
        var d = JSON.parse(raw)
        if (!d) {
            rebuildTuneModel()
            return
        }

        var ci = codecKeys.indexOf(d.codec)
        if (ci >= 0) codecCombo.currentIndex = ci

        crfField.text = d.crf != null ? String(d.crf) : ""
        bitrateField.text = d.bitrate || ""
        presetField.text = d.preset || ""
        pixfmtField.text = d.pixel_format || ""

        var ri = resOptions.indexOf(d.resolution)
        resCombo.currentIndex = ri >= 0 ? ri : 0

        if (d.framerate != null) {
            var fi = fpsOptions.indexOf(d.framerate)
            if (fi >= 0) fpsCombo.currentIndex = fi
            else fpsCombo.editText = String(d.framerate)
        } else {
            fpsCombo.currentIndex = 0
        }

        tileRowsField.text = d.tile_rows != null ? String(d.tile_rows) : ""
        tileColsField.text = d.tile_columns != null ? String(d.tile_columns) : ""
        enableQmCheck.checked = d.enable_qm === true

        rebuildTuneModel()
        if (d.tune) {
            var ti = tuneCombo.model.indexOf(d.tune)
            if (ti >= 0) tuneCombo.currentIndex = ti
            else tuneCombo.editText = d.tune
        }

        audioBitrateField.text = d.audio_bitrate || "128k"
        audioChannelsField.text = d.audio_channels != null ? String(d.audio_channels) : ""
        audioSrField.text = d.audio_sample_rate != null ? String(d.audio_sample_rate) : ""

        extraArgsField.text = (d.extra_args || []).join(" ")
    }

    function saveCurrent() {
        var name = profileName
        if (!name) {
            name = newProfileNameField.text.trim()
            if (!name) {
                newProfileNameField.placeholderText = "Name is required!"
                return
            }
        }
        var codec = codecKeys[codecCombo.currentIndex]
        var data = {
            name: name,
            codec: codec,
            crf: crfField.text ? parseInt(crfField.text) : null,
            bitrate: bitrateField.text || null,
            preset: presetField.text || null,
            tune: tuneCombo.currentText || null,
            pixel_format: pixfmtField.text || null,
            resolution: resCombo.currentText === "native" ? null : resCombo.currentText,
            framerate: fpsCombo.currentIndex === 0 ? null : parseFloat(fpsCombo.currentText),
            tile_rows: tileRowsField.text ? parseInt(tileRowsField.text) : null,
            tile_columns: tileColsField.text ? parseInt(tileColsField.text) : null,
            enable_qm: enableQmCheck.checked ? true : null,
            audio_bitrate: audioBitrateField.text || "128k",
            audio_channels: audioChannelsField.text ? parseInt(audioChannelsField.text) : null,
            audio_sample_rate: audioSrField.text ? parseInt(audioSrField.text) : null,
            extra_args: extraArgsField.text.trim() ? extraArgsField.text.trim().split(/\s+/) : []
        }
        backend.saveProfile(name, JSON.stringify(data))
        back()
    }

    function deleteCurrent() {
        backend.deleteProfile(profileName)
        back()
    }

    Component.onCompleted: loadProfile(profileName)
}
