import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../Utils/Centering.js" as Utils

Column {
    id: root
    spacing: 8

    property var codecKeys: ["h264", "hevc", "vp8", "vp9", "svtav1"]
    property var codecLabels: ["H.264", "H.265/HEVC", "VP8", "VP9", "AV1 (SVT-AV1)"]
    property var resOptions: ["native", "360p", "480p", "720p", "1080p", "1440p", "2160p"]
    property var fpsOptions: ["source", 20, 23.976, 25, 30, 40, 45, 50, 60]
    property string pixfmtDefault: "default"
    property var pixfmtOptions: [root.pixfmtDefault, "yuv420p", "yuv422p", "yuv444p", "yuv420p10le", "yuv422p10le", "yuv444p10le", "nv12"]
    property var _availableEncoders: ({})
    property var _codecAvailable: []
    property var _capOverrides: ({})  // {presets, tunes, pix_fmts} from encoder capabilities

    // codec defaults for tunings
    property var _tuneDefaults: {
        "h264": ["film", "grain", "animation", "psnr", "ssim", "fastdecode", "zerolatency"],
        "hevc": ["film", "grain", "animation", "psnr", "ssim", "fastdecode", "zerolatency"],
        "vp8": ["psnr", "ssim", "good", "best"],
        "vp9": ["psnr", "ssim", "good", "best"],
        "svtav1": ["psnr", "ssim", "vmaf"]
    }
    property var _presetDefaults: {
        "h264": ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow", "placebo"],
        "hevc": ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow", "placebo"],
        "vp8": ["good", "best", "realtime"],
        "vp9": ["good", "best", "realtime"],
        "svtav1": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"]
    }

    property var rateControlLabels: ["CRF", "VBR", "CBR"]
    property var rateControlKeys: ["crf", "vbr", "cbr"]
    property bool loading: false
    property var rateValidator: null

    readonly property alias videoEnabled: videoEnabledSwitch.checked
    readonly property string codec: codecKeys[codecCombo.currentIndex]

    signal changed

    IntValidator { id: crfValidatorInst; bottom: 0; top: 63 }

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
                text: "Video"
                color: theme.text
                font.bold: true
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }
            Switch {
                id: videoEnabledSwitch
                checked: true
                onCheckedChanged: if (!root.loading) root.changed()
            }
        }
    }

    Column {
        width: parent.width
        spacing: 8
        visible: videoEnabledSwitch.checked

        Label {
            text: "Codec"
            color: theme.textMuted
            font.bold: true
            font.pixelSize: 14
        }
        ComboBox {
            id: codecCombo
            model: root.codecLabels
            width: parent.width
            delegate: ItemDelegate {
                text: modelData + (root._codecAvailable[index] ? "" : " (unavailable)")
                enabled: root._codecAvailable[index]
                opacity: root._codecAvailable[index] ? 1.0 : 0.4
                palette.text: enabled ? theme.text : theme.textDim
            }
            onCurrentIndexChanged: {
                if (!root._codecAvailable[currentIndex]) return
                root._capOverrides = {}
                rebuildTuneModel()
                rebuildEncoderModel()
                if (!root.loading) root.changed()
            }
        }

        Row {
            spacing: 8
            width: parent.width
            Label {
                text: "Encoder"
                color: theme.textSecondary
                width: 100
                verticalAlignment: Text.AlignVCenter
            }
            Button {
                id: compatInfoBtn
                width: 32
                height: 32
                text: "?"
                font.bold: true
                font.pixelSize: 15
                onClicked: compatDialog.open()
                ToolTip.visible: hovered
                ToolTip.text: "Show available encoders"
            }
            ComboBox {
                id: encoderCombo
                width: parent.width - 100 - compatInfoBtn.width - 2 * parent.spacing
                editable: true
                // Model set explicitly by rebuildEncoderModel (no binding)
                onCurrentIndexChanged: {
                    applyEncoderCapabilities(encoderCombo.currentText)
                    if (!root.loading) root.changed()
                }
                onEditTextChanged: {
                    if (!root.loading) root.changed()
                }
            }
        }

        Label {
            text: "Rate control"
            color: theme.textMuted
            font.bold: true
            font.pixelSize: 14
        }
        Row {
            spacing: 8
            width: parent.width
            ComboBox {
                id: rateControlCombo
                model: rateControlLabels
                width: 100
                onCurrentIndexChanged: {
                    root.rateValidator = rateControlKeys[currentIndex] === "crf" ? crfValidatorInst : null
                    if (!root.loading) root.changed()
                }
            }
            TextField {
                id: rateValueField
                width: parent.width - rateControlCombo.width - parent.spacing
                placeholderText: rateControlKeys[rateControlCombo.currentIndex] === "crf" ? "CRF value (e.g. 18)" : "Bitrate (e.g. 2M)"
                validator: root.rateValidator
                onTextChanged: if (!root.loading) root.changed()
                onEditingFinished: if (!root.loading) root.changed()
            }
        }

        Row {
            spacing: 8
            width: parent.width
            Label { text: "Preset"; color: theme.textSecondary; width: 100 }
            ComboBox {
                id: presetCombo
                width: parent.width - 108
                editable: true
                model: {
                    var codec = codecKeys[codecCombo.currentIndex]
                    var list = (root._capOverrides.presets || root._presetDefaults[codec] || []).slice()
                    list.unshift("default")
                    return list
                }
                onCurrentIndexChanged: {
                    if (!root.loading) root.changed()
                }
                onEditTextChanged: {
                    if (!root.loading) root.changed()
                }
            }
        }

        Row {
            spacing: 8
            width: parent.width
            Label { text: "Tune"; color: theme.textSecondary; width: 100 }
            ComboBox {
                id: tuneCombo
                width: parent.width - 108
                editable: true
                model: {
                    var codec = codecKeys[codecCombo.currentIndex]
                    var tunes = (root._capOverrides.tunes || root._tuneDefaults[codec] || []).slice()
                    tunes.unshift("default")
                    return tunes
                }
                onCurrentIndexChanged: if (!root.loading) root.changed()
                onEditTextChanged: if (!root.loading) root.changed()
            }
        }

        Row {
            spacing: 8
            width: parent.width
            Label { text: "Pixel fmt"; color: theme.textSecondary; width: 100 }
            ComboBox {
                id: pixfmtCombo
                width: parent.width - 108
                editable: true
                model: {
                    var list = root._capOverrides.pix_fmts
                        ? root._capOverrides.pix_fmts.slice()
                        : root.pixfmtOptions.slice()
                    if (list.indexOf(root.pixfmtDefault) < 0)
                        list.unshift(root.pixfmtDefault)
                    return list
                }
                onCurrentIndexChanged: if (!root.loading) root.changed()
                onEditTextChanged: if (!root.loading) root.changed()
            }
        }

        Label {
            text: "Scaling"
            color: theme.textMuted
            font.bold: true
            font.pixelSize: 14
            topPadding: 4
        }
        Row {
            spacing: 8
            width: parent.width
            Label { text: "Resolution"; color: theme.textSecondary; width: 100 }
            ComboBox {
                id: resCombo
                model: resOptions
                width: parent.width - 108
                onCurrentIndexChanged: if (!root.loading) root.changed()
                onActivated: if (!root.loading) root.changed()
            }
        }
        Row {
            spacing: 8
            width: parent.width
            Label { text: "Framerate"; color: theme.textSecondary; width: 100 }
            ComboBox {
                id: fpsCombo
                model: fpsOptions
                width: parent.width - 108
                editable: true
                validator: DoubleValidator { bottom: 0; top: 120 }
                onCurrentIndexChanged: if (!root.loading) root.changed()
                onEditTextChanged: if (!root.loading) root.changed()
            }
        }

        Column {
            width: parent.width
            visible: codecKeys[codecCombo.currentIndex] === "svtav1"
            spacing: 6
            Label {
                text: "AV1 (SVT-AV1)"
                color: theme.textMuted
                font.bold: true
                font.pixelSize: 14
                topPadding: 4
            }
            Grid {
                columns: 4
                columnSpacing: 8
                rowSpacing: 6
                width: parent.width
                Label { text: "Tile rows"; color: theme.textSecondary }
                TextField {
                    id: tileRowsField
                    width: 60
                    placeholderText: "2"
                    validator: IntValidator { bottom: 0; top: 8 }
                    onTextChanged: if (!root.loading) root.changed()
                }
                Label { text: "Tile cols"; color: theme.textSecondary }
                TextField {
                    id: tileColsField
                    width: 60
                    placeholderText: "3"
                    validator: IntValidator { bottom: 0; top: 8 }
                    onTextChanged: if (!root.loading) root.changed()
                }
            }
            CheckBox {
                id: enableQmCheck
                text: "Enable Quantization Matrix"
                onCheckedChanged: if (!root.loading) root.changed()
            }
        }

        Column {
            width: parent.width
            visible: { var c = codecKeys[codecCombo.currentIndex]; return c === "vp8" || c === "vp9" }
            spacing: 6
            Label {
                text: "VP8/VP9"
                color: theme.textMuted
                font.bold: true
                font.pixelSize: 14
                topPadding: 4
            }
            Row {
                spacing: 8
                width: parent.width
                Label { text: "CPU used"; color: theme.textSecondary; width: 100 }
                ComboBox {
                    id: cpuUsedCombo
                    width: parent.width - 108
                    editable: true
                    model: ["default", "0", "1", "2", "3", "4", "5"]
                    onCurrentIndexChanged: if (!root.loading) root.changed()
                    onEditTextChanged: if (!root.loading) root.changed()
                }
            }
        }
    }

    Dialog {
        id: compatDialog
        title: "Available Encoders"
        standardButtons: Dialog.Ok
        width: 360
        padding: 0
        implicitHeight: implicitHeaderHeight + compatList.implicitHeight + implicitFooterHeight + 24
        Component.onCompleted: Utils.centerInParent(compatDialog)
        onOpened: Utils.centerInParent(compatDialog)

        Column {
            id: compatList
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8
            Repeater {
                model: root.codecLabels.length
                delegate: Column {
                    spacing: 3
                    visible: {
                        var encs = root._encodersForKey(root.codecKeys[index])
                        return encs.length > 0
                    }
                    Label {
                        text: root.codecLabels[index] + " (" + root._encodersForKey(root.codecKeys[index]).length + ")"
                        color: theme.text
                        font.bold: true
                        font.pixelSize: 12
                    }
                    Repeater {
                        model: root._encodersForKey(root.codecKeys[index])
                        delegate: Label {
                            text: "\u2022 " + modelData
                            color: theme.textSecondary
                            font.pixelSize: 11
                            leftPadding: 12
                        }
                    }
                }
            }
        }
    }

    function rebuildTuneModel() {
        var codec = codecKeys[codecCombo.currentIndex]
        var tunes = (root._capOverrides.tunes || root._tuneDefaults[codec] || []).slice()
        tunes.unshift("default")
        var prev = tuneCombo.currentText
        tuneCombo.model = tunes
        var idx = tunes.indexOf(prev)
        tuneCombo.currentIndex = idx >= 0 ? idx : 0
    }

    function applyEncoderCapabilities(encName) {
        if (!encName) {
            root._capOverrides = {}
            return
        }
        var raw = backend.encoderCapabilities(encName)
        if (!raw || raw === "null") {
            root._capOverrides = {}
            return
        }
        var caps = JSON.parse(raw)
        root._capOverrides = caps

        // Check if current values are still valid in the new models
        var codec = codecKeys[codecCombo.currentIndex]

        // Preset: check if current value exists in new model
        var newPresets = caps.presets || root._presetDefaults[codec] || []
        var curPreset = presetCombo.currentText
        if (curPreset !== "" && curPreset !== "default" && newPresets.indexOf(curPreset) < 0)
            presetCombo.currentIndex = 0

        // Tune: check if current value exists
        var newTunes = caps.tunes || root._tuneDefaults[codec] || []
        var curTune = tuneCombo.currentText
        if (curTune !== "" && curTune !== "default" && newTunes.indexOf(curTune) < 0)
            tuneCombo.currentIndex = 0

        // Pixfmt: check if current value exists
        var newPixfmts = caps.pix_fmts
        if (newPixfmts) {
            var curPix = pixfmtCombo.currentText
            if (curPix !== "" && curPix !== root.pixfmtDefault && newPixfmts.indexOf(curPix) < 0)
                pixfmtCombo.currentIndex = 0
        }
    }

    function _encodersForKey(key) {
        // map internal codec key to ffmpeg codec name
        var ffmpegKey = (key === "svtav1") ? "av1" : key
        return root._availableEncoders[ffmpegKey] || []
    }

    function _defaultEncoderForKey(key) {
        var map = {
            "h264": "libx264",
            "hevc": "libx265",
            "vp8": "libvpx",
            "vp9": "libvpx-vp9",
            "svtav1": "libsvtav1"
        }
        return map[key] || "libx264"
    }

    function rebuildEncoderModel(forceDefault) {
        var codec = codecKeys[codecCombo.currentIndex]
        var encs = root._encodersForKey(codec)
        var prev = encoderCombo.currentText
        encoderCombo.model = encs
        if (encs.length === 0) {
            encoderCombo.currentIndex = -1
            return
        }
        if (!forceDefault && prev && encs.indexOf(prev) >= 0) {
            encoderCombo.currentIndex = encs.indexOf(prev)
            return
        }
        var defEnc = root._defaultEncoderForKey(codec)
        var ei = encs.indexOf(defEnc)
        encoderCombo.currentIndex = ei >= 0 ? ei : 0
    }

    function _comboText(combo, sentinel) {
        return (combo.currentText && combo.currentText !== sentinel) ? combo.currentText : null
    }

    function _setComboText(combo, value, sentinel) {
        if (value == null || value === sentinel || value === "") {
            combo.currentIndex = 0
            return
        }
        var idx = combo.model.indexOf(value)
        if (idx >= 0)
            combo.currentIndex = idx
        else
            combo.editText = value
    }

    function _indexValue(keys, combo) {
        return keys[combo.currentIndex]
    }

    function _setIndex(keys, combo, value) {
        var idx = keys.indexOf(value)
        combo.currentIndex = idx >= 0 ? idx : 0
    }

    function getData() {
        var rcKey = _indexValue(rateControlKeys, rateControlCombo)
        var cpuUsedTmp = _comboText(cpuUsedCombo, "default")
        var data = {
            codec: _indexValue(codecKeys, codecCombo),
            video_enabled: videoEnabledSwitch.checked,
            rate_control: rcKey,
            encoder: encoderCombo.currentText || null,
            preset: _comboText(presetCombo, "default"),
            tune: _comboText(tuneCombo, "default"),
            pixel_format: _comboText(pixfmtCombo, root.pixfmtDefault),
            resolution: _comboText(resCombo, "native"),
            framerate: fpsCombo.currentIndex === 0 ? null : parseFloat(fpsCombo.currentText),
            tile_rows: tileRowsField.text ? parseInt(tileRowsField.text) : null,
            tile_columns: tileColsField.text ? parseInt(tileColsField.text) : null,
            enable_qm: enableQmCheck.checked ? true : null,
            cpu_used: cpuUsedTmp ? parseInt(cpuUsedTmp) : null
        }
        if (rcKey === "crf") {
            data.crf = rateValueField.text ? parseInt(rateValueField.text) : null
            data.bitrate = null
        } else {
            data.crf = null
            data.bitrate = rateValueField.text || null
        }
        return data
    }

    function setData(d) {
        _setIndex(codecKeys, codecCombo, d.codec)

        videoEnabledSwitch.checked = d.video_enabled !== false

        _setIndex(rateControlKeys, rateControlCombo, d.rate_control)
        root.rateValidator = rateControlKeys[rateControlCombo.currentIndex] === "crf" ? crfValidatorInst : null

        if (rateControlKeys[rateControlCombo.currentIndex] === "crf") {
            rateValueField.text = d.crf != null ? String(d.crf) : ""
        } else {
            rateValueField.text = d.bitrate || ""
        }

        _setComboText(presetCombo, d.preset, "default")
        _setComboText(pixfmtCombo, d.pixel_format, root.pixfmtDefault)

        _setIndex(resOptions, resCombo, d.resolution)

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

        _setComboText(cpuUsedCombo, d.cpu_used != null ? String(d.cpu_used) : null, "default")

        rebuildEncoderModel(true)
        if (d.encoder) {
            var encs = root._encodersForKey(d.codec)
            var ei = encs.indexOf(d.encoder)
            if (ei >= 0)
                encoderCombo.currentIndex = ei
            else
                encoderCombo.editText = d.encoder
            applyEncoderCapabilities(d.encoder)
        }

        rebuildTuneModel()
        _setComboText(tuneCombo, d.tune, "default")
    }

    function rebuildCodecItems() {
        var avail = []
        for (var i = 0; i < root.codecKeys.length; i++) {
            avail.push(root._encodersForKey(root.codecKeys[i]).length > 0)
        }
        root._codecAvailable = avail
    }

    Component.onCompleted: {
        var raw = backend.availableEncoders()
        if (raw && raw !== "null") {
            root._availableEncoders = JSON.parse(raw)
        }
        rebuildCodecItems()
        rebuildEncoderModel()
    }
}
