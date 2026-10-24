import QtQuick
import QtQuick.Controls

Dialog {
    id: root

    // Implicit content height; -1 measures implicitContentHeight instead
    // (fill-anchored content measures 0 and must set this property).
    property real contentImplicitHeight: -1
    // Set false to manage position manually instead of staying centered.
    property bool centered: true
    // org.kde.desktop (Breeze) draws its own close button in the dialog header.
    readonly property bool styleDrawsHeaderClose: currentStyle === "org.kde.desktop"

    modal: true
    padding: 16
    topPadding: 8
    implicitHeight: implicitHeaderHeight
        + (contentImplicitHeight >= 0 ? contentImplicitHeight : implicitContentHeight)
        + implicitFooterHeight + padding + topPadding
    anchors.centerIn: centered ? Overlay.overlay : undefined
}
