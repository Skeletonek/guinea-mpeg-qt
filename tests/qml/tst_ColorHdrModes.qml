import "../../qml/ProfileEditor/VideoPanel"
import QtQuick
import QtTest

Item {
    id: root

    // Stand-in for the C++ context property the section expects
    property var theme: ({
            "text": "#ffffff",
            "textSecondary": "#cccccc",
            "textMuted": "#aaaaaa",
            "textDim": "#888888",
            "widget": "#333333",
            "widgetBorder": "#555555"
        })

    width: 600
    height: 600

    ColorHdrSection {
        id: colorHdr

        width: 400
    }

    TestCase {
        name: "ColorHdrModes"
        when: windowShown

        function _handling() {
            return findChild(colorHdr, "colorHdrHandlingCombo");
        }

        function _tone() {
            return findChild(colorHdr, "colorHdrToneCombo");
        }

        function init() {
            colorHdr.setColorHdrData({});
        }

        function test_auto_exports_nulls() {
            compare(_handling().currentIndex, 0);
            var d = colorHdr.getColorHdrData();
            compare(d.pixel_format, null);
            compare(d.color_primaries, null);
            compare(d.color_trc, null);
            compare(d.colorspace, null);
            compare(d.color_range, null);
            compare(d.tonemap, null);
        }

        function test_sdr_exports_tonemap_without_none() {
            // custom with tone mapping off, then switch to Convert to SDR
            colorHdr.setColorHdrData({"color_trc": "bt709"});
            compare(_tone().currentText, "none");
            _handling().currentIndex = 1;
            // "Convert to SDR" coerces a disabled tone map to the default
            compare(colorHdr.getColorHdrData().tonemap, "hable");
            compare(_tone().model.indexOf("none"), -1);
            _tone().currentIndex = 1; // mobius
            compare(colorHdr.getColorHdrData().tonemap, "mobius");
        }

        function test_custom_roundtrip() {
            colorHdr.setColorHdrData({
                "pixel_format": "yuv420p10le",
                "color_primaries": "bt2020",
                "color_trc": "smpte2084",
                "colorspace": "bt2020nc",
                "color_range": "tv",
                "video_filters": {"tonemap": "hable"}
            });
            compare(_handling().currentIndex, 2);
            var d = colorHdr.getColorHdrData();
            compare(d.pixel_format, "yuv420p10le");
            compare(d.color_primaries, "bt2020");
            compare(d.color_trc, "smpte2084");
            compare(d.colorspace, "bt2020nc");
            compare(d.color_range, "tv");
            compare(d.tonemap, "hable");
        }

        function test_mode_derived_from_data() {
            colorHdr.setColorHdrData({"video_filters": {"tonemap": "mobius"}});
            compare(_handling().currentIndex, 1);
            compare(colorHdr.getColorHdrData().tonemap, "mobius");

            colorHdr.setColorHdrData({"pixel_format": "yuv420p"});
            compare(_handling().currentIndex, 2);
            compare(colorHdr.getColorHdrData().pixel_format, "yuv420p");
            // hidden fields are nulled even when the combos hold stale values
            compare(colorHdr.getColorHdrData().color_trc, null);

            colorHdr.setColorHdrData({});
            compare(_handling().currentIndex, 0);
        }
    }
}
