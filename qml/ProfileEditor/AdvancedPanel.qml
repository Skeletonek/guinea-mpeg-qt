import "../Components"
import QtQuick 2.15
import QtQuick.Controls 2.15

Column {
    id: root

    property bool loading: false
    property bool advancedMode: false
    property string advancedCommand: ""
    property string previewText: qsTr("Adjust settings above to see the ffmpeg command preview...")

    signal changed
    signal extraArgsChanged

    function getData() {
        if (root.advancedMode)
            return {
                "extra_args": [],
                "custom_command": root.advancedCommand
            };

        return {
            "extra_args": extraArgsField.text.trim() ? extraArgsField.text.trim().split(/\s+/) : []
        };
    }

    function setData(d) {
        extraArgsField.text = (d.extra_args || []).join(" ");
        commandField.text = d.custom_command || "";
        root.advancedCommand = commandField.text;
    }

    function setCommand(text) {
        commandField.text = text;
        root.advancedCommand = text;
    }

    function setPreview(text) {
        root.previewText = text;
    }

    spacing: 8

    WidgetHeader {
        text: qsTr("Advanced")
    }

    SectionHeader {
        visible: !root.advancedMode
        text: qsTr("Extra FFmpeg arguments")
    }

    TextField {
        id: extraArgsField

        visible: !root.advancedMode
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
        visible: root.advancedMode
        text: qsTr("FFmpeg command")
    }

    Label {
        visible: root.advancedMode
        width: parent.width
        text: qsTr("Edit the full ffmpeg command. Placeholders: {input}, {output}, {start}, {duration} ({start}/{duration} are omitted when no trim is set).")
        color: theme.textSecondary
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }

    Rectangle {
        visible: root.advancedMode
        width: parent.width
        height: 200
        color: theme.widget
        border.color: theme.widgetBorder
        radius: 4

        TextArea {
            id: commandField

            anchors.fill: parent
            anchors.margins: 4
            font.family: "monospace"
            font.pixelSize: 12
            color: theme.text
            selectByMouse: true
            wrapMode: Text.WordWrap
            background: null
            onTextChanged: {
                root.advancedCommand = commandField.text;
                if (!root.loading)
                    root.advancedCommandChanged();

                if (!root.loading)
                    root.changed();
            }
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
