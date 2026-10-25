import QtQuick
import QtQuick.Controls
import "../Utils/FormatUtils.js" as FormatUtils

Column {
    id: root

    // Streams to pick from (ffprobe entries) and their kind ("video"/"audio")
    property var streams: []
    property string kind: "video"
    // Selected indices; owned by the host — this component only signals
    property var selection: []

    signal toggled(int index, bool checked)

    function isSelected(index) {
        return selection.indexOf(index) >= 0;
    }

    spacing: 4

    Repeater {
        model: root.streams.length

        delegate: CheckBox {
            // State comes from the selection binding only — an internal toggle
            // would destroy the binding and desync the host state
            checkable: false
            checked: root.isSelected(index)
            text: FormatUtils.streamText(root.streams[index], index, root.kind)
            onClicked: root.toggled(index, !root.isSelected(index))
        }
    }
}
