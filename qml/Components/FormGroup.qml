import QtQuick 2.15
import QtQuick.Controls 2.15
import "SectionHeader.qml"

/**
 * Container for grouping related form elements with a header
 */
Column {
    id: root
    spacing: 8
    width: parent.width
    
    property string title: ""
    
    SectionHeader {
        text: root.title
        visible: root.title !== ""
    }
    
    // Content goes here
}
