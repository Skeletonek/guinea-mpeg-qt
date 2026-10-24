import QtQuick 2.15
import QtQuick.Controls 2.15
import "Utils/Constants.js" as Constants
import "Utils/FormatUtils.js" as FormatUtils

Rectangle {
    id: root

    property int videoDuration: 0
    property int startTime: 0
    property int endTime: 0
    property var mainWindow: null
    // Source FPS as a decimal, derived from currentVideoInfo
    readonly property real fps: {
        var info = mainWindow && mainWindow.currentVideoInfo ? mainWindow.currentVideoInfo : null;
        return info ? (FormatUtils.fpsToDecimal(String(info.fps || "")) || 0) : 0;
    }
    readonly property int nudgeStep: fps > 0 ? Math.max(1, Math.round(1000 / fps)) : 100

    signal trimRequested(string kind, real value)

    function nudgeStartBy(stepMs) {
        var t = Math.max(0, Math.min(startTime + stepMs, endTime - 1));
        startTime = t;
        startTime = Qt.binding(function () {
            return mainWindow ? mainWindow.startTime : 0;
        });
    }

    function nudgeEndBy(stepMs) {
        var t = Math.max(startTime + 1, Math.min(endTime + stepMs, videoDuration));
        endTime = t;
        endTime = Qt.binding(function () {
            return mainWindow ? mainWindow.endTime : 0;
        });
    }

    // Global trim nudging — active while a trim handle holds focus (the seek
    // shortcuts yield to the timeline in the same state). Frame = 1 frame,
    // Ctrl = 1s, Shift = 1min; H/L stay as frame aliases. The focused handle
    // decides which edge moves.
    readonly property bool trimFocused: startHandle.activeFocus || endHandle.activeFocus

    function nudgeFocusedBy(stepMs) {
        if (startHandle.activeFocus)
            nudgeStartBy(stepMs);
        else if (endHandle.activeFocus)
            nudgeEndBy(stepMs);
    }

    Shortcut {
        enabled: root.trimFocused
        sequences: ["Left", "H"]
        onActivated: root.nudgeFocusedBy(-root.nudgeStep)
    }

    Shortcut {
        enabled: root.trimFocused
        sequence: "Ctrl+Left"
        onActivated: root.nudgeFocusedBy(-1000)
    }

    Shortcut {
        enabled: root.trimFocused
        sequence: "Shift+Left"
        onActivated: root.nudgeFocusedBy(-60000)
    }

    Shortcut {
        enabled: root.trimFocused
        sequences: ["Right", "L"]
        onActivated: root.nudgeFocusedBy(root.nudgeStep)
    }

    Shortcut {
        enabled: root.trimFocused
        sequence: "Ctrl+Right"
        onActivated: root.nudgeFocusedBy(1000)
    }

    Shortcut {
        enabled: root.trimFocused
        sequence: "Shift+Right"
        onActivated: root.nudgeFocusedBy(60000)
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
                text: FormatUtils.formatTimePrecise(Math.min(startTime, videoDuration), root.fps)
                width: 80
                color: theme.text
            }

            Label {
                text: FormatUtils.formatTimePrecise(Math.min(endTime, videoDuration), root.fps)
                width: 80
                color: theme.text
            }
        }

        Rectangle {
            id: track

            property double _ratio: videoDuration > 0 ? width / videoDuration : 1

            width: parent.width - parent.leftPadding - parent.rightPadding
            height: 20
            color: Constants.timelineTrackColor
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
                border.color: Constants.timelineHandleBorder
                activeFocusOnTab: true

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
                        // Emit before the binding restore drops the final drag value
                        root.trimRequested("start", startTime);
                        startHandle.x = Qt.binding(function () {
                            return Math.max(0, Math.min(startTime * track._ratio, track.width - startHandle.width));
                        });
                        startTime = Qt.binding(function () {
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
                border.color: Constants.timelineHandleBorder
                activeFocusOnTab: true

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
                        root.trimRequested("end", endTime);
                        endHandle.x = Qt.binding(function () {
                            return Math.max(0, Math.min(endTime * track._ratio - endHandle.width, track.width - endHandle.width));
                        });
                        endTime = Qt.binding(function () {
                            return mainWindow ? mainWindow.endTime : 0;
                        });
                    }
                }
            }
        }
    }
}
