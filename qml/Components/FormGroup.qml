import QtQuick 2.15
import QtQuick.Controls 2.15
import "SectionHeader.qml"

/**
 * Container for grouping related form elements with a header
 */
Column {
    // Content goes here

    id: root

    property string title: ""

    spacing: 8
    width: parent.width

    SectionHeader {
        text: root.title
        visible: root.title !== ""
    }

}
