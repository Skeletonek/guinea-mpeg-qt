import QtQuick
import QtQuick.Controls

Button {
    id: root

    // Icon-only button; text doubles as the tooltip and accessibility label
    display: AbstractButton.IconOnly
    icon.width: 24
    icon.height: 24

    ToolTip.visible: hovered
    ToolTip.delay: 500
    ToolTip.text: root.text
}
