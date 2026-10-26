import "../../Components"
import "../../Utils/Constants.js" as Constants
import QtQuick 2.15
import QtQuick.Controls 2.15

SectionBase {
    id: root

    property string audioCodec: ""

    function getPCMCodec() {
        // read live state: the formatKey binding updates after changed handlers run
        return "pcm_" + (Constants.pcmFormatKeys[formatCombo.currentIndex] || "s16le");
    }

    function setPCMData(d) {
        var ac = (d.audio_codec || "").toLowerCase();
        var key = ac.indexOf("pcm_") === 0 ? ac.substring(4) : "";
        var idx = Constants.pcmFormatKeys.indexOf(key);
        formatCombo.currentIndex = idx >= 0 ? idx : Constants.pcmFormatDefaultIndex;
    }

    width: parent.width
    visible: audioCodec === "PCM"

    SectionHeader {
        text: "PCM"
    }

    LabeledRow {
        label: qsTr("Format")

        ComboBox {
            id: formatCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            model: Constants.pcmFormatLabels
            currentIndex: Constants.pcmFormatDefaultIndex
            onCurrentIndexChanged: {
                if (!root.loading)
                    root.emitChanged();
            }
        }
    }
}
