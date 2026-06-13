import QtQuick 2.15
import QtQuick.Controls 2.15

Column {
    id: root
    spacing: 8

    property bool loading: false
    property string previewText: "Adjust settings above to see the ffmpeg command preview..."

    signal changed
    signal extraArgsChanged

    Rectangle {
        width: parent.width
        height: 28
        color: theme.widget
        radius: 4
        Label {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 6
            text: "Advanced"
            color: theme.text
            font.bold: true
            font.pixelSize: 14
        }
    }

    Label {
        text: "Extra FFmpeg arguments"
        color: theme.textMuted
        font.bold: true
        font.pixelSize: 14
        topPadding: 4
    }
    TextField {
        id: extraArgsField
        width: parent.width
        font.family: "monospace"
        font.pixelSize: 11
        placeholderText: "-row-mt 1 -tiles 2x2"
        onTextChanged: {
            if (!root.loading) root.extraArgsChanged()
            if (!root.loading) root.changed()
        }
        onEditingFinished: {
            if (!root.loading) root.extraArgsChanged()
            if (!root.loading) root.changed()
        }
    }

    Label {
        text: "FFmpeg Preview"
        color: theme.textMuted
        font.bold: true
        font.pixelSize: 14
        topPadding: 4
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

    function getData() {
        return {
            extra_args: extraArgsField.text.trim() ? extraArgsField.text.trim().split(/\s+/) : []
        }
    }

    function setData(d) {
        extraArgsField.text = (d.extra_args || []).join(" ")
    }

    function setPreview(text) {
        previewArea.text = text
    }
}
