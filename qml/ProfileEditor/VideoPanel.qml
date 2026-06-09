import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Column {
    id: root
    spacing: 8

    property var codecKeys: ["h264", "vp8", "vp9", "svtav1"]
    property var codecLabels: ["H.264", "VP8", "VP9", "AV1 (SVT-AV1)"]
    property var resOptions: ["native", "360p", "480p", "720p", "1080p", "1440p", "2160p"]
    property var fpsOptions: ["source", 20, 23.976, 25, 30, 40, 45, 50, 60]
    property string tuneDefault: "default"
    property string pixfmtDefault: "source"
    property var pixfmtOptions: [root.pixfmtDefault, "yuv420p", "yuv422p", "yuv444p", "yuv420p10le", "yuv422p10le", "yuv444p10le", "nv12"]
    property var tuneByCodec: {
        "h264": ["film", "grain", "animation", "psnr", "ssim", "fastdecode", "zerolatency"],
        "vp8": ["psnr", "ssim", "good", "best"],
        "vp9": ["psnr", "ssim", "good", "best"],
        "svtav1": ["psnr", "ssim", "vmaf"]
    }
    property var presetOptionsByCodec: {
        "h264": ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow", "placebo"],
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
            model: codecLabels
            width: parent.width
            onCurrentIndexChanged: {
                rebuildTuneModel()
                var cur = presetCombo.currentText
                if (cur && cur !== "default" && presetCombo.model.indexOf(cur) < 0)
                    presetCombo.currentIndex = 0
                if (!root.loading) root.changed()
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
                    var list = (presetOptionsByCodec[codecKeys[codecCombo.currentIndex]] || []).slice()
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
                model: [root.tuneDefault, "film", "grain", "animation", "psnr", "ssim", "fastdecode", "zerolatency"]
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
                model: pixfmtOptions
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

    function rebuildTuneModel() {
        var codec = codecKeys[codecCombo.currentIndex]
        var tunes = (tuneByCodec[codec] || []).slice()
        tunes.unshift(root.tuneDefault)
        var prev = tuneCombo.currentText
        tuneCombo.model = tunes
        var idx = tunes.indexOf(prev)
        tuneCombo.currentIndex = idx >= 0 ? idx : 0
    }

    function getData() {
        var rcKey = rateControlKeys[rateControlCombo.currentIndex]
        var data = {
            codec: codecKeys[codecCombo.currentIndex],
            video_enabled: videoEnabledSwitch.checked,
            rate_control: rcKey,
            preset: (presetCombo.currentText && presetCombo.currentText !== "default") ? presetCombo.currentText : null,
            tune: (tuneCombo.currentText && tuneCombo.currentText !== root.tuneDefault) ? tuneCombo.currentText : null,
            pixel_format: (pixfmtCombo.currentText && pixfmtCombo.currentText !== root.pixfmtDefault) ? pixfmtCombo.currentText : null,
            resolution: resCombo.currentText === "native" ? null : resCombo.currentText,
            framerate: fpsCombo.currentIndex === 0 ? null : parseFloat(fpsCombo.currentText),
            tile_rows: tileRowsField.text ? parseInt(tileRowsField.text) : null,
            tile_columns: tileColsField.text ? parseInt(tileColsField.text) : null,
            enable_qm: enableQmCheck.checked ? true : null,
            cpu_used: (cpuUsedCombo.currentText && cpuUsedCombo.currentText !== "default") ? parseInt(cpuUsedCombo.currentText) : null
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
        var ci = codecKeys.indexOf(d.codec)
        if (ci >= 0) codecCombo.currentIndex = ci

        videoEnabledSwitch.checked = d.video_enabled !== false

        var rci = rateControlKeys.indexOf(d.rate_control)
        if (rci < 0) rci = 0
        rateControlCombo.currentIndex = rci
        root.rateValidator = rateControlKeys[rci] === "crf" ? crfValidatorInst : null

        if (d.rate_control === "crf") {
            rateValueField.text = d.crf != null ? String(d.crf) : ""
        } else {
            rateValueField.text = d.bitrate || ""
        }

        if (d.preset) {
            var pi2 = presetCombo.model.indexOf(d.preset)
            if (pi2 >= 0) presetCombo.currentIndex = pi2
            else presetCombo.editText = d.preset
        } else {
            presetCombo.currentIndex = 0
        }
        if (d.pixel_format) {
            pixfmtCombo.editText = d.pixel_format
            var pi = pixfmtOptions.indexOf(d.pixel_format)
            if (pi >= 0) pixfmtCombo.currentIndex = pi
        } else {
            pixfmtCombo.currentIndex = 0
        }

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

        if (d.cpu_used != null) {
            var cu = String(d.cpu_used)
            var cui = cpuUsedCombo.model.indexOf(cu)
            if (cui >= 0) cpuUsedCombo.currentIndex = cui
            else cpuUsedCombo.editText = cu
        } else {
            cpuUsedCombo.currentIndex = 0
        }

        rebuildTuneModel()
        if (d.tune) {
            var ti = tuneCombo.model.indexOf(d.tune)
            if (ti >= 0) tuneCombo.currentIndex = ti
            else tuneCombo.editText = d.tune
        } else {
            tuneCombo.currentIndex = 0
        }
    }
}
