import QtQuick 2.15
import QtQuick.Controls 2.15
import "Utils/Constants.js" as Constants
import "Utils/FormatUtils.js" as FormatUtils

Rectangle {
    id: root

    property int videoDuration: 0
    property int startTime: 0
    property int endTime: 0
    property QtObject mainWindow: null
    readonly property int nudgeStep: {
        var fpsStr = mainWindow && mainWindow.currentVideoInfo ? String(mainWindow.currentVideoInfo.fps || "") : "";
        var fps = 0;
        if (fpsStr.length > 0) {
            var parts = fpsStr.split("/");
            fps = parts.length === 2 ? (parseFloat(parts[0]) / parseFloat(parts[1])) : parseFloat(fpsStr);
        }
        return fps > 0 ? Math.max(1, Math.round(1000 / fps)) : 100;
    }

    function nudgeStartTime(dir) {
        var step = (dir < 0 ? -1 : 1) * nudgeStep;
        var t = Math.max(0, Math.min(startTime + step, endTime - 1));
        startTime = t;
        startTime = Qt.binding(function() {
            return mainWindow ? mainWindow.startTime : 0;
        });
    }

    function nudgeEndTime(dir) {
        var step = (dir < 0 ? -1 : 1) * nudgeStep;
        var t = Math.max(startTime + 1, Math.min(endTime + step, videoDuration));
        endTime = t;
        endTime = Qt.binding(function() {
            return mainWindow ? mainWindow.endTime : 0;
        });
    }

    color: theme.widget
    border.color: theme.widgetBorder
    border.width: 1

    Column {
        spacing: 8
        anchors.fill: parent
        padding: 8

        Row {
            spacing: 8

            Label {
                text: FormatUtils.formatTime(startTime)
                width: 80
                color: theme.text
            }

            Label {
                text: FormatUtils.formatTime(endTime)
                width: 80
                color: theme.text
            }

        }

        Rectangle {
            id: track

            property double _ratio: videoDuration > 0 ? width / videoDuration : 1

            width: parent.width - parent.leftPadding - parent.rightPadding
            height: 20
            color: "#555555"
            radius: 4

            Rectangle {
                x: Math.max(0, Math.min(startTime * track._ratio, track.width))
                width: Math.max(0, Math.min((endTime - startTime) * track._ratio, track.width - x))
                height: parent.height
                color: Constants.timelineSelectionColor
                opacity: Constants.timelineSelectionOpacity
                radius: 4
            }

            Rectangle {
                id: startHandle

                x: Math.max(0, Math.min(startTime * track._ratio, track.width - width))
                y: 0
                width: 12
                height: parent.height
                color: Constants.colorPrimary
                radius: 3
                border.width: activeFocus ? 1 : 0
                border.color: "#ffffff"
                activeFocusOnTab: true
                Keys.onLeftPressed: function(event) {
                    event.accepted = true;
                    nudgeStartTime(-1);
                }
                Keys.onRightPressed: function(event) {
                    event.accepted = true;
                    nudgeStartTime(1);
                }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_H || event.key === Qt.Key_L) {
                        event.accepted = true;
                        nudgeStartTime(event.key === Qt.Key_H ? -1 : 1);
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    drag.target: parent
                    drag.axis: Drag.XAxis
                    drag.minimumX: 0
                    drag.maximumX: track.width - width
                    onClicked: startHandle.forceActiveFocus()
                    onPositionChanged: {
                        startHandle.x = Math.max(0, Math.min(startHandle.x, track.width - width));
                        var t = Math.round(startHandle.x / track._ratio);
                        t = Math.max(0, Math.min(t, videoDuration));
                        if (t < endTime)
                            startTime = t;

                    }
                    onReleased: {
                        startHandle.x = Qt.binding(function() {
                            return Math.max(0, Math.min(startTime * track._ratio, track.width - startHandle.width));
                        });
                        startTime = Qt.binding(function() {
                            return mainWindow ? mainWindow.startTime : 0;
                        });
                    }
                }

            }

            Rectangle {
                id: endHandle

                x: Math.max(0, Math.min(endTime * track._ratio - width, track.width - width))
                y: 0
                width: 12
                height: parent.height
                color: Constants.colorSecondary
                radius: 3
                border.width: activeFocus ? 1 : 0
                border.color: "#ffffff"
                activeFocusOnTab: true
                Keys.onLeftPressed: function(event) {
                    event.accepted = true;
                    nudgeEndTime(-1);
                }
                Keys.onRightPressed: function(event) {
                    event.accepted = true;
                    nudgeEndTime(1);
                }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_H || event.key === Qt.Key_L) {
                        event.accepted = true;
                        nudgeEndTime(event.key === Qt.Key_H ? -1 : 1);
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    drag.target: parent
                    drag.axis: Drag.XAxis
                    drag.minimumX: 0
                    drag.maximumX: track.width - width
                    onClicked: endHandle.forceActiveFocus()
                    onPositionChanged: {
                        endHandle.x = Math.max(0, Math.min(endHandle.x, track.width - width));
                        var t = Math.round((endHandle.x + width) / track._ratio);
                        t = Math.max(0, Math.min(t, videoDuration));
                        if (t > startTime)
                            endTime = t;

                    }
                    onReleased: {
                        endHandle.x = Qt.binding(function() {
                            return Math.max(0, Math.min(endTime * track._ratio - endHandle.width, track.width - endHandle.width));
                        });
                        endTime = Qt.binding(function() {
                            return mainWindow ? mainWindow.endTime : 0;
                        });
                    }
                }

            }

        }

    }

}
