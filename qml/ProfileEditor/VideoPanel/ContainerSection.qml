import "../../Components"
import "../../Utils/Constants.js" as Constants
import "../../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Controls 2.15

Column {
    id: root

    property string codecKey: "h264"
    property bool loading: false
    readonly property string container: _container
    property string _container: ""

    signal changed

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
        containerCombo.model = model;
        if (containerCombo.currentIndex >= model.length)
            containerCombo.currentIndex = 0;
    }

    spacing: 8
    width: parent.width
    visible: codecKey !== "gif" && codecKey !== "webp"
    onCodecKeyChanged: rebuildModel()

    LabeledRow {
        label: qsTr("Container")

        ComboBox {
            id: containerCombo

            width: parent.width - parent.effectiveLabelWidth - parent.spacing
            onCurrentIndexChanged: {
                root._container = root.getContainer() || "";
                if (!root.loading)
                    root.changed();
            }
            onActivated: {
                if (!root.loading)
                    root.changed();
            }
        }
    }
}