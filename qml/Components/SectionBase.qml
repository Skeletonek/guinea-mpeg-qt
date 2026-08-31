import QtQuick

Column {
    id: root

    property bool loading: false

    signal changed

    function emitChanged() {
        if (!root.loading)
            root.changed();
    }

    spacing: 8
    width: parent.width
}
