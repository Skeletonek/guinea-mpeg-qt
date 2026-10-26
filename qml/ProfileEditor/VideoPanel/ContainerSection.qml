import "../../Components"
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15

SectionBase {
    id: root

    property string codecKey: "h264"
    readonly property string container: _container
    property string _container: ""

    function getContainer() {
        return DataUtils.comboText(containerCombo, Constants.SENTINEL_DEFAULT);
    }

    function setContainerData(d) {
        DataUtils.setComboText(containerCombo, d.container, Constants.SENTINEL_DEFAULT);
    }

    function rebuildModel() {
        var keys = Constants.containerKeysByCodec[root.codecKey] || [];
        var model = [Constants.SENTINEL_DEFAULT];
        for (var i = 0; i < keys.length; i++)
            model.push(keys[i]);
        var prev = DataUtils.comboValue(containerCombo);
        containerCombo.model = model;
        var idx = model.indexOf(prev);
        containerCombo.currentIndex = idx >= 0 ? idx : 0;
    }

    visible: codecKey !== "gif" && codecKey !== "webp"
    onCodecKeyChanged: rebuildModel()

    LabeledRow {
        label: qsTr("Container")

        ComboBox {
            id: containerCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            editable: true
            onCurrentIndexChanged: {
                root._container = root.getContainer() || "";
                root.emitChanged();
            }
            onEditTextChanged: {
                root._container = root.getContainer() || "";
                root.emitChanged();
            }
        }
    }
}
