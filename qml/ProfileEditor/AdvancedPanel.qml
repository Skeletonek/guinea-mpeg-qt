import "../Components"
import QtQuick 2.15
import QtQuick.Controls 2.15

Column {
    id: root

    property bool loading: false
    property string previewText: qsTr("Adjust settings above to see the ffmpeg command preview...")

    signal changed()
    signal extraArgsChanged()

    function getData() {
        return {
            "extra_args": extraArgsField.text.trim() ? extraArgsField.text.trim().split(/\s+/) : []
        };
    }

    function setData(d) {
        extraArgsField.text = (d.extra_args || []).join(" ");
    }

    function setPreview(text) {
        root.previewText = text;
    }

    spacing: 8

    WidgetHeader {
        text: qsTr("Advanced")
    }

    SectionHeader {
        text: qsTr("Extra FFmpeg arguments")
    }

    TextField {
        id: extraArgsField

        width: parent.width
        font.family: "monospace"
        font.pixelSize: 11
        placeholderText: "-row-mt 1 -tiles 2x2"
        onTextChanged: {
            if (!root.loading)
                root.extraArgsChanged();

            if (!root.loading)
                root.changed();

        }
        onEditingFinished: {
            if (!root.loading)
                root.extraArgsChanged();

            if (!root.loading)
                root.changed();

        }
    }

    SectionHeader {
        text: qsTr("FFmpeg Preview")
    }

    Rectangle {
        width: parent.width
        height: 80
        color: theme.widget
        border.color: theme.widgetBorder
        radius: 4

        TextArea {
            id: previewArea

            anchors.fill: parent
            anchors.margins: 4
            readOnly: true
            font.family: "monospace"
            font.pixelSize: 11
            color: theme.text
            wrapMode: Text.WordWrap
            selectByMouse: true
            text: root.previewText
            background: null
        }

    }

}
