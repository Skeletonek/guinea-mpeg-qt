import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    property string videoSource: ""
    property int currentTime: 0
    
    color: "black"
    
    // Video player would go here
    // For now, just show a placeholder
    Image {
        id: videoDisplay
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        source: videoSource
    }
    
    // Playback controls overlay
    Rectangle {
        id: controlsOverlay
        anchors.bottom: parent.bottom
        width: parent.width
        height: 40
        color: "#80000000"
        visible: parent.hovered || mouseArea.containsMouse
        
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
        }
        
        Row {
            anchors.centerIn: parent
            spacing: 20
            
            Button {
                id: playButton
                text: "▶"
                onClicked: {
                    // Toggle play/pause
                }
            }
            
            Slider {
                id: seekSlider
                width: 200
                from: 0
                to: 100
                value: 0
            }
            
            Label {
                text: formatTime(currentTime)
                color: "white"
            }
        }
    }
    
    function formatTime(seconds) {
        var mins = Math.floor(seconds / 60)
        var secs = Math.floor(seconds % 60)
        return mins.toString().padStart(2, '0') + ":" + secs.toString().padStart(2, '0')
    }
}
