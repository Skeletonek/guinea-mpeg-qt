import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    property int videoDuration: 0
    property int startTime: 0
    property int endTime: 0

    onVideoDurationChanged: Qt.callLater(resetHandles)

    color: theme.widget
    border.color: theme.widgetBorder
    border.width: 1

    Column {
        spacing: 5
        anchors.fill: parent
        padding: 5

        Row {
            spacing: 10
            Label { text: formatTime(startTime); width: 80; color: theme.text }
            Label { text: formatTime(endTime); width: 80; color: theme.text }
        }

        Rectangle {
            id: track
            width: parent.width - parent.leftPadding - parent.rightPadding
            height: 20
            color: "#555555"
            radius: 4

            property double _ratio: videoDuration > 0 ? width / videoDuration : 1

            Rectangle {
                x: Math.max(0, Math.min(startTime * track._ratio, track.width))
                width: Math.max(0, Math.min((endTime - startTime) * track._ratio, track.width - x))
                height: parent.height
                color: "#4a9eff"
                opacity: 0.5
                radius: 4
            }

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
                    drag.maximumX: track.width - width
                    onPositionChanged: {
                        startHandle.x = Math.max(0, Math.min(startHandle.x, track.width - width))
                        var t = Math.round((startHandle.x + startHandle.width / 2) / track._ratio)
                        t = Math.max(0, Math.min(t, videoDuration))
                        if (t < endTime) {
                            startTime = t
                        }
                    }
                }
            }

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
                    drag.maximumX: track.width - width
                    onPositionChanged: {
                        endHandle.x = Math.max(0, Math.min(endHandle.x, track.width - width))
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

    function resetHandles() {
        startHandle.x = Math.max(0, Math.min(startTime * track._ratio - startHandle.width / 2, track.width - startHandle.width))
        endHandle.x = Math.max(0, Math.min(endTime * track._ratio - endHandle.width / 2, track.width - endHandle.width))
    }

    function formatTime(ms) {
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        s = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }
}
