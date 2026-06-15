import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "SectionHeader.qml"
import "../Utils/Constants.js" as Constants

/**
 * Container for grouping related form elements with a header
 */
Column {
    id: root
    spacing: 8
    width: parent.width
    
    property string title: ""
    property bool titleMuted: true
    
    SectionHeader {
        text: root.title
        muted: root.titleMuted
        visible: root.title !== ""
    }
    
    // Content goes here
}
