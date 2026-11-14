import "../../Components"
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15

SectionBase {
    id: root

    readonly property int _modeAuto: 0
    readonly property int _modeSdr: 1
    readonly property int _modeCustom: 2

    function rebuildPixfmtModel(caps) {
        pixelFormatSection.rebuildPixfmtModel(caps);
    }

    /**
     * Collects the color/HDR part of the profile. Hidden fields are nulled
     * out: "Auto" deliberately keeps pixel format and tags at source values.
     * Returns a flat "tonemap" key; VideoPanel merges it into video_filters.
     */
    function getColorHdrData() {
        var mode = handlingCombo.currentIndex;
        var data = {
            "pixel_format": null,
            "color_primaries": null,
            "color_trc": null,
            "colorspace": null,
            "color_range": null,
            "tonemap": null
        };
        if (mode === root._modeSdr) {
            data.tonemap = DataUtils.comboText(toneCombo, "none");
        } else if (mode === root._modeCustom) {
            data.pixel_format = pixelFormatSection.getPixelFormatData().pixel_format;
            var tags = colorTagsSection.getColorData();
            for (var k in tags)
                data[k] = tags[k];
            data.tonemap = DataUtils.comboText(toneCombo, "none");
        }
        return data;
    }

    /**
     * Distributes profile data and derives the handling mode from it:
     * custom tags or an explicit pixel format → Custom, tone mapping →
     * Convert to SDR, otherwise Auto. The mode itself is not persisted.
     */
    function setColorHdrData(d) {
        var vf = d.video_filters || {};
        pixelFormatSection.setPixelFormatData(d);
        colorTagsSection.setColorData(d);
        var hasTags = d.color_primaries || d.color_trc || d.colorspace || d.color_range;
        if (hasTags || d.pixel_format)
            handlingCombo.currentIndex = root._modeCustom;
        else if (vf.tonemap)
            handlingCombo.currentIndex = root._modeSdr;
        else
            handlingCombo.currentIndex = root._modeAuto;
        root._applyToneModel(vf.tonemap || "none");
    }

    // "Convert to SDR" means tone mapping on: hide the "none" entry there and
    // coerce a disabled tone map to the default algorithm on mode entry. The
    // model differs per mode, so this is the only place that sets the value.
    function _applyToneModel(value) {
        var custom = handlingCombo.currentIndex === root._modeCustom;
        var items = custom ? Constants.tonemapOptions : Constants.tonemapAlgoOptions;
        if (value === undefined)
            value = DataUtils.comboText(toneCombo, "none");
        if (handlingCombo.currentIndex === root._modeSdr && !value)
            value = Constants.tonemapAlgoOptions[0];
        toneCombo.model = items;
        DataUtils.setIndex(items, toneCombo, value || "none");
    }

    SectionHeader {
        text: qsTr("Color & HDR")
    }

    LabeledRow {
        label: qsTr("Handling")

        ComboBox {
            id: handlingCombo

            objectName: "colorHdrHandlingCombo"
            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            model: [qsTr("Auto (keep source)"), qsTr("Convert to SDR"), qsTr("Custom")]
            currentIndex: 0
            onCurrentIndexChanged: {
                root._applyToneModel();
                root.emitChanged();
            }
        }
    }

    LabeledRow {
        label: qsTr("Tone mapping")
        visible: handlingCombo.currentIndex !== root._modeAuto

        ComboBox {
            id: toneCombo

            objectName: "colorHdrToneCombo"
            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            model: Constants.tonemapOptions
            currentIndex: 0
            onCurrentIndexChanged: root.emitChanged();
        }
    }

    PixelFormatSection {
        id: pixelFormatSection

        width: parent.width
        visible: handlingCombo.currentIndex === root._modeCustom
        loading: root.loading
        onChanged: root.emitChanged()
    }

    ColorTagsSection {
        id: colorTagsSection

        width: parent.width
        visible: handlingCombo.currentIndex === root._modeCustom
        loading: root.loading
        onChanged: root.emitChanged()
    }
}
