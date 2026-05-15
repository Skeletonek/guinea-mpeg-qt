import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    property int videoDuration: 0
    property int startTime: 0
    property int endTime: 0

    color: "#333"
    border.color: "#555"
    border.width: 1

    Column {
        spacing: 5
        anchors.fill: parent
        padding: 5

        Row {
            spacing: 10
            Label { text: formatTime(startTime); width: 80; color: "white" }
            Label { text: formatTime(endTime); width: 80; color: "white" }
        }

        Rectangle {
            id: track
            width: parent.width
            height: 20
            color: "#555"
            radius: 4

            property double _ratio: videoDuration > 0 ? width / videoDuration : 1

            // Selection range
            Rectangle {
                x: startTime * track._ratio
                width: (endTime - startTime) * track._ratio
                height: parent.height
                color: "#4a9eff"
                opacity: 0.4
                radius: 4
            }

            // Start handle
            Rectangle {
                id: startHandle
                x: Math.max(0, Math.min(startTime * track._ratio - width / 2, track.width - width))
                y: 0
                width: 12
                height: parent.height
                color: "#4a9eff"
                radius: 3
                MouseArea {
                    anchors.fill: parent
                    drag.target: parent
                    drag.axis: Drag.XAxis
                    drag.minimumX: 0
                    drag.maximumX: track.width
                    onPositionChanged: {
                        var t = Math.round((startHandle.x + startHandle.width / 2) / track._ratio)
                        t = Math.max(0, Math.min(t, videoDuration))
                        if (t < endTime) {
                            startTime = t
                        }
                    }
                }
            }

            // End handle
            Rectangle {
                id: endHandle
                x: Math.max(0, Math.min(endTime * track._ratio - width / 2, track.width - width))
                y: 0
                width: 12
                height: parent.height
                color: "#ff6b4a"
                radius: 3
                MouseArea {
                    anchors.fill: parent
                    drag.target: parent
                    drag.axis: Drag.XAxis
                    drag.minimumX: 0
                    drag.maximumX: track.width
                    onPositionChanged: {
                        var t = Math.round((endHandle.x + endHandle.width / 2) / track._ratio)
                        t = Math.max(0, Math.min(t, videoDuration))
                        if (t > startTime) {
                            endTime = t
                        }
                    }
                }
            }
        }
    }

    function formatTime(ms) {
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        s = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }
}
