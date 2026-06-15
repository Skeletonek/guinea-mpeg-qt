import QtQuick 2.15
import QtQuick.Controls 2.15
import "../Utils/Constants.js" as Constants

/**
 * Standard section header for grouping related form elements
 */
Label {
    id: root
    
    property string text: ""
    property bool muted: false
    
    text: root.text
    color: root.muted ? theme.textMuted : theme.text
    font.bold: true
    font.pixelSize: 14
    topPadding: 4
}
