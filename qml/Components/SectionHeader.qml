import QtQuick 2.15
import QtQuick.Controls 2.15
import "../Utils/Constants.js" as Constants

/**
 * Standard section header for grouping related form elements
 */
Label {
    id: root
    
    text: root.text
    color: theme.textMuted
    font.bold: true
    font.pixelSize: 14
    topPadding: 4
}
