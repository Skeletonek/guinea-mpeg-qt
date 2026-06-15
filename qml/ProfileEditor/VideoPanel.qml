import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../Utils/Constants.js" as Constants
import "../Utils/DataUtils.js" as DataUtils
import "../Components"
import "VideoPanel"

/**
 * Video Panel - Main container for video encoding settings
 * Coordinates between codec-specific components and manages video enable/disable state
 */
Column {
    id: root
    spacing: 8

    property var _availableEncoders: ({})
    property var _codecAvailable: []
    property var _capOverrides: ({})
    property bool loading: false
    
    readonly property alias videoEnabled: videoEnabledSwitch.checked
    readonly property string codec: codecSection ? codecSection.codec : Constants.codecKeys[0]
    
    signal changed
    signal openEncoderCompatDialog()

    // Video enable/disable toggle
    WidgetHeader {
        width: parent.width
        height: 28
        
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

    // Codec-specific components (only visible when video is enabled)
    Column {
        id: videoSettingsColumn
        width: parent.width
        spacing: 8
        visible: videoEnabledSwitch.checked

        // Codec and encoder selection
        CodecSection {
            id: codecSection
            width: parent.width
            _availableEncoders: root._availableEncoders
            _codecAvailable: root._codecAvailable
            _capOverrides: root._capOverrides
            loading: root.loading
            onChanged: root.changed()
            onCodecSelectionChanged: {
                // Update codec-dependent sections when codec changes
                if (presetTuneSection) {
                    presetTuneSection.currentCodecKey = root.codec
                    presetTuneSection.rebuildPresetModel()
                    presetTuneSection.rebuildTuneModel()
                }
                if (av1Section) {
                    av1Section.codecKey = root.codec
                }
                if (vp8vp9Section) {
                    vp8vp9Section.codecKey = root.codec
                }
            }
            onOpenEncoderCompatDialog: root.openEncoderCompatDialog()
            onEncoderSelectionChanged: root.applyEncoderCapabilities(encName)
        }

        // Rate control (CRF/VBR/CBR)
        RateControlSection {
            id: rateControlSection
            width: parent.width
            loading: root.loading
            onChanged: root.changed()
        }

        // Preset and Tune
        PresetTuneSection {
            id: presetTuneSection
            width: parent.width
            loading: root.loading
            _capOverrides: root._capOverrides
            currentCodecKey: root.codec
            onChanged: root.changed()
        }

        // Pixel format
        PixelFormatSection {
            id: pixelFormatSection
            width: parent.width
            loading: root.loading
            _capOverrides: root._capOverrides
            onChanged: root.changed()
        }

        // Scaling (resolution and framerate)
        ScalingSection {
            id: scalingSection
            width: parent.width
            loading: root.loading
            onChanged: root.changed()
        }

        // AV1-specific settings
        AV1Section {
            id: av1Section
            width: parent.width
            codecKey: root.codec
            loading: root.loading
            onChanged: root.changed()
        }

        // VP8/VP9-specific settings
        VP8VP9Section {
            id: vp8vp9Section
            width: parent.width
            codecKey: root.codec
            loading: root.loading
            onChanged: root.changed()
        }
    }

    /**
     * Load available encoders from backend
     */
    function loadAvailableEncoders() {
        var raw = backend.availableEncoders()
        if (raw && raw !== "null") {
            root._availableEncoders = JSON.parse(raw)
        }
        root.rebuildCodecItems()
    }

    /**
     * Apply encoder capabilities for a specific encoder
     */
    function applyEncoderCapabilities(encName) {
        if (!encName) {
            root._capOverrides = {}
            root.updateChildModels()
            return
        }
        var raw = backend.encoderCapabilities(encName)
        if (!raw || raw === "null") {
            root._capOverrides = {}
            root.updateChildModels()
            return
        }
        root._capOverrides = JSON.parse(raw)
        root.updateChildModels()
    }

    /**
     * Update models in child components when capabilities change
     */
    function updateChildModels() {
        if (presetTuneSection) {
            presetTuneSection._capOverrides = root._capOverrides
            presetTuneSection.rebuildPresetModel()
            presetTuneSection.rebuildTuneModel()
        }
        if (pixelFormatSection) {
            pixelFormatSection._capOverrides = root._capOverrides
            pixelFormatSection.rebuildPixfmtModel()
        }
    }

    /**
     * Rebuilds codec availability items
     */
    function rebuildCodecItems() {
        if (codecSection) {
            var avail = []
            for (var i = 0; i < Constants.codecKeys.length; i++) {
                avail.push(root._encodersForKey(Constants.codecKeys[i]).length > 0)
            }
            root._codecAvailable = avail
            codecSection._codecAvailable = root._codecAvailable
            codecSection.rebuildCodecItems()
        }
    }

    function _encodersForKey(key) {
        return root._availableEncoders[key] || []
    }

    /**
     * Collects data from all sections and returns combined video profile data
     */
    function getData() {
        var data = {
            video_enabled: videoEnabledSwitch.checked,
            codec: root.codec
        }
        
        if (codecSection) {
            var codecData = codecSection.getCodecData()
            data.codec = codecData.codec
            data.encoder = codecData.encoder
        }
        
        // Merge data from all sections
        if (rateControlSection) {
            var rcData = rateControlSection.getRateControlData()
            for (var k in rcData) data[k] = rcData[k]
        }
        
        if (presetTuneSection) {
            var ptData = presetTuneSection.getPresetTuneData()
            for (var k in ptData) data[k] = ptData[k]
        }
        
        if (pixelFormatSection) {
            var pfData = pixelFormatSection.getPixelFormatData()
            for (var k in pfData) data[k] = pfData[k]
        }
        
        if (scalingSection) {
            var scData = scalingSection.getScalingData()
            for (var k in scData) data[k] = scData[k]
        }
        
        if (av1Section) {
            var av1Data = av1Section.getAV1Data()
            for (var k in av1Data) data[k] = av1Data[k]
        }
        
        if (vp8vp9Section) {
            var vp8vp9Data = vp8vp9Section.getVP8VP9Data()
            for (var k in vp8vp9Data) data[k] = vp8vp9Data[k]
        }
        
        return data
    }

    /**
     * Distributes profile data to all sections
     */
    function setData(d) {
        videoEnabledSwitch.checked = d.video_enabled !== false
        
        if (codecSection) {
            codecSection.setCodecData({
                codec: d.codec,
                encoder: d.encoder
            })
        }
        
        if (rateControlSection) {
            rateControlSection.setRateControlData(d)
        }
        
        if (presetTuneSection) {
            presetTuneSection.setPresetTuneData(d)
        }
        
        if (pixelFormatSection) {
            pixelFormatSection.setPixelFormatData(d)
        }
        
        if (scalingSection) {
            scalingSection.setScalingData(d)
        }
        
        if (av1Section) {
            av1Section.setAV1Data(d)
        }
        
        if (vp8vp9Section) {
            vp8vp9Section.setVP8VP9Data(d)
        }
    }

    Component.onCompleted: {
        root.loadAvailableEncoders()
    }
}
