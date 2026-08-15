import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Utils/UpdateUtils.js" as UpdateUtils

Rectangle {
    id: root
    implicitHeight: 96
    visible: buildInfo.debugBuild ? !dismissed : (updateAvailable && !dismissed)
    color: theme.widget
    border.color: theme.widgetBorder
    border.width: 1
    radius: 6

    property string metadataUrl: "https://server.skeletonek.com/app/guinea-mpeg/update.toml"
    property string defaultUpdateUrl: "https://skeletonek.com/apps/guinea-mpeg/"
    property bool updateAvailable: false
    property string latestVersion: ""
    property string updateUrl: ""
    property bool dismissed: false

    Component.onCompleted: {
        if (buildInfo.debugBuild === true) return
        var opts = {}
        try { opts = JSON.parse(backend.getOptions()) } catch(e) {}
        if (opts.checkForUpdates === false) return
        checkForUpdates()
    }

    function checkForUpdates() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", root.metadataUrl)
        xhr.timeout = 8000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                print("[UpdateCheck] Update check failed: HTTP " + xhr.status + " from " + root.metadataUrl)
                return
            }
            var meta = UpdateUtils.parseUpdateToml(xhr.responseText)
            if (!meta) {
                print("[UpdateCheck] Update check failed: invalid or incomplete metadata from " + root.metadataUrl)
                return
            }
            var current = UpdateUtils.currentVersionParts(buildInfo.version)
            if (UpdateUtils.isNewer(meta, current)) {
                root.updateAvailable = true
                root.latestVersion = meta.major + "." + meta.minor + "." + meta.patch
                root.updateUrl = meta.url
            }
        }
        xhr.onerror = function() {
            print("[UpdateCheck] Update check failed: network error (no connection?) for " + root.metadataUrl)
        }
        xhr.ontimeout = function() {
            print("[UpdateCheck] Update check timed out: " + root.metadataUrl)
        }
        xhr.send()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 4
            Layout.fillHeight: true
            color: theme.accent
            radius: 2
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: buildInfo.debugBuild ? "Development build of GuineaMPEG"
                                               : qsTr("A new version of GuineaMPEG is available")
                    color: theme.text
                    font.pixelSize: 13
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: buildInfo.debugBuild ? buildInfo.buildDate
                                               : "%1 → %2".arg(buildInfo.version).arg(root.latestVersion)
                    color: theme.accent
                    font.pixelSize: 13
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                Button {
                    text: qsTr("Update")
                    onClicked: {
                        var url = root.updateUrl !== "" ? root.updateUrl : root.defaultUpdateUrl
                        Qt.openUrlExternally(url)
                    }
                }

                Button {
                    text: qsTr("Close")
                    onClicked: root.dismissed = true
                }
            }
        }
    }
}
