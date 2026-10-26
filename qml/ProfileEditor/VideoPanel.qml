import "../Components"
import "../Utils/Constants.js" as Constants
import "../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15
import "VideoPanel"

Column {
    id: root

    property var _availableEncoders: ({})
    property var _codecAvailable: []
    property bool loading: false
    property bool audioEnabled: true
    readonly property alias videoEnabled: videoEnabledSwitch.checked
    readonly property string codec: codecSection ? codecSection.codec : Constants.codecKeys[0]
    readonly property bool _isAnimated: codec === "gif" || codec === "webp"
    readonly property bool _isCopy: codec === "copy"
    readonly property string container: containerSection ? containerSection.container : ""

    signal changed

    function loadAvailableEncoders() {
        var raw = backend.availableEncoders();
        if (raw && raw !== "null")
            root._availableEncoders = JSON.parse(raw);

        root.rebuildCodecItems();
    }

    function refreshAll(encName) {
        if (encName === undefined)
            encName = codecSection.getCurrentEncoder();

        var caps = {};
        if (encName) {
            var raw = backend.encoderCapabilities(encName);
            if (raw && raw !== "null")
                caps = JSON.parse(raw);
        }
        // Sync before the rebuilds below — codecChanged fires only after this handler chain
        presetTuneSection.currentCodecKey = codecSection.getCurrentCodecKey();
        presetTuneSection._capOverrides = caps;
        pixelFormatSection._capOverrides = caps;
        presetTuneSection.rebuildPresetModel(caps);
        presetTuneSection.rebuildTuneModel(caps);
        pixelFormatSection.rebuildPixfmtModel(caps);
        root.changed();
    }

    function rebuildCodecItems() {
        if (codecSection) {
            var avail = [];
            for (var i = 0; i < Constants.codecKeys.length; i++) {
                var key = Constants.codecKeys[i];
                if (key === "copy")
                    avail.push(true);
                else if (key === "gif" || key === "webp")
                    avail.push(true);
                else
                    avail.push(root._encodersForKey(key).length > 0);
            }
            root._codecAvailable = avail;
            codecSection._codecAvailable = root._codecAvailable;
            codecSection.rebuildCodecItems();
        }
    }

    function _encodersForKey(key) {
        return root._availableEncoders[key] || [];
    }

    /**
     * Collects data from all sections and returns combined video profile data
     */
    function getData() {
        var data = {
            "video_enabled": videoEnabledSwitch.checked,
            "codec": root.codec,
            "container": containerSection ? containerSection.getContainer() : null
        };
        if (videoEnabledSwitch.checked) {
            var codecData = codecSection.getCodecData();
            data.codec = codecData.codec;
            data.encoder = codecData.encoder;
            if (root._isCopy) {
                // stream copy: skip encoding params, null them out so preview omits them
                data.crf = null;
                data.bitrate = null;
                data.preset = null;
                data.tune = null;
                data.pixel_format = null;
                data.resolution = null;
                data.framerate = null;
                data.tile_rows = null;
                data.tile_columns = null;
                data.enable_qm = null;
                data.cpu_used = null;
                data.compression_level = null;
                data.rate_control = null;
                data.encoder = null;
            } else if (!root._isAnimated) {
                data = DataUtils.buildProfileData(data, rateControlSection.getRateControlData(), presetTuneSection.getPresetTuneData(), pixelFormatSection.getPixelFormatData());
            }
            if (!root._isCopy) {
                data = DataUtils.buildProfileData(data, scalingSection.getScalingData());
                if (filtersSection)
                    data = DataUtils.buildProfileData(data, filtersSection.getFiltersData());
                if (animatedSection && root._isAnimated)
                    data = DataUtils.buildProfileData(data, animatedSection.getAnimatedData());
                if (av1Section)
                    data = DataUtils.buildProfileData(data, av1Section.getAV1Data());
                if (vp8vp9Section)
                    data = DataUtils.buildProfileData(data, vp8vp9Section.getVP8VP9Data());
            } else {
                // preserve scaling/filters as nulls already
            }
        }
        return data;
    }

    /**
     * Distributes profile data to all sections
     */
    function setData(d) {
        videoEnabledSwitch.checked = d.video_enabled !== false;
        if (videoEnabledSwitch.checked) {
            codecSection.setCodecData({
                "codec": d.codec,
                "encoder": d.encoder
            });
            containerSection.setContainerData(d);
            rateControlSection.setRateControlData(d);
            presetTuneSection.setPresetTuneData(d);
            pixelFormatSection.setPixelFormatData(d);
            scalingSection.setScalingData(d);
            if (filtersSection)
                filtersSection.setFiltersData(d);
            if (animatedSection)
                animatedSection.setAnimatedData(d);

            if (av1Section)
                av1Section.setAV1Data(d);

            if (vp8vp9Section)
                vp8vp9Section.setVP8VP9Data(d);
        }
        root.refreshAll();
    }

    spacing: 8
    Component.onCompleted: {
        root.loadAvailableEncoders();
    }

    WidgetHeader {
        width: parent.width
        height: 28

        Row {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 8
            spacing: 8

            Label {
                text: qsTr("Video")
                color: theme.text
                font.bold: true
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }

            Switch {
                id: videoEnabledSwitch
                objectName: "videoEnabledSwitch"

                checked: true
                enabled: root.audioEnabled || !videoEnabledSwitch.checked
                onCheckedChanged: {
                    if (!root.loading)
                        root.changed();
                }
            }
        }
    }

    Column {
        id: videoSettingsColumn

        width: parent.width
        spacing: 8
        visible: videoEnabledSwitch.checked

        SectionHeader {
            text: qsTr("Codec")
        }

        CodecSection {
            id: codecSection

            width: parent.width
            _availableEncoders: root._availableEncoders
            loading: root.loading
            onChanged: root.changed()
            onEncoderSelectionChanged: function (encName) {
                root.refreshAll(encName);
            }
        }

        ContainerSection {
            id: containerSection

            width: parent.width
            codecKey: root.codec
            loading: root.loading
            onChanged: root.changed()
        }

        SectionHeader {
            text: qsTr("Rate control")
        }

        RateControlSection {
            id: rateControlSection

            width: parent.width
            visible: !root._isAnimated && !root._isCopy
            loading: root.loading
            onChanged: root.changed()
        }

        PresetTuneSection {
            id: presetTuneSection

            width: parent.width
            visible: !root._isAnimated && !root._isCopy
            loading: root.loading
            onChanged: root.changed()
        }

        PixelFormatSection {
            id: pixelFormatSection

            width: parent.width
            visible: !root._isAnimated && !root._isCopy
            loading: root.loading
            onChanged: root.changed()
        }

        AV1Section {
            id: av1Section

            width: parent.width
            isCopy: root._isCopy
            codecKey: root.codec
            loading: root.loading
            onChanged: root.changed()
        }

        VP8VP9Section {
            id: vp8vp9Section

            width: parent.width
            isCopy: root._isCopy
            codecKey: root.codec
            loading: root.loading
            onChanged: root.changed()
        }

        SectionHeader {
            text: qsTr("Scaling")
            visible: !root._isCopy
        }

        ScalingSection {
            id: scalingSection

            enabled: !root._isCopy
            opacity: root._isCopy ? 0.4 : 1.0
            width: parent.width
            loading: root.loading
            onChanged: root.changed()
        }

        FiltersSection {
            id: filtersSection

            enabled: !root._isCopy
            opacity: root._isCopy ? 0.4 : 1.0
            width: parent.width
            loading: root.loading
            onChanged: root.changed()
        }

        Label {
            width: parent.width
            visible: root._isCopy
            text: qsTr("Scaling, filters, rate control and codec options are disabled for Copy (stream copy).")
            color: theme.textSecondary
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        AnimatedSection {
            id: animatedSection

            width: parent.width
            codecKey: root.codec
            loading: root.loading
            onChanged: root.changed()
        }
    }
}
