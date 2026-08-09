import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Utils/Centering.js" as Utils
import "../Components"

Dialog {
    id: root
    title: qsTr("Options")
    width: 400
    padding: 0
    implicitHeight: implicitHeaderHeight + mainLayout.implicitHeight + implicitFooterHeight + 24
    modal: true
    standardButtons: Dialog.Close

    property bool restartRequired: false
    property bool _loadingOptions: false

    Component.onCompleted: Utils.centerInParent(root)
    onOpened: {
        Utils.centerInParent(root)
        restartRequired = false
        loadOptions()
    }

    function _indexOfValue(combo, value) {
        for (var i = 0; i < combo.model.length; i++) {
            if (combo.model[i].value === value) return i
        }
        return 0
    }

    function loadOptions() {
        var opts = {}
        try { opts = JSON.parse(backend.getOptions()) } catch(e) {}
        _loadingOptions = true
        languageCombo.currentIndex = _indexOfValue(languageCombo, opts.language || "system")
        themeCombo.currentIndex = _indexOfValue(themeCombo, opts.theme || "system")
        hwdecCombo.currentIndex = _indexOfValue(hwdecCombo, opts.hwdec || "auto-copy")
        checkForUpdatesSwitch.checked = opts.checkForUpdates !== false
        _loadingOptions = false
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 8
        spacing: 10

        Label { text: qsTr("General"); font.bold: true; font.pixelSize: 14; color: theme.text }

        Label { text: qsTr("Language"); color: theme.textMuted }
        ComboBox {
            id: languageCombo
            Layout.fillWidth: true
            model: [
                { text: qsTr("System default"), value: "system" },
                { text: "English", value: "en" },
                { text: "Čeština", value: "cs" },
                { text: "Deutsch", value: "de" },
                { text: "Español", value: "es" },
                { text: "Français", value: "fr" },
                { text: "Italiano", value: "it" },
                { text: "Polski", value: "pl_PL" },
                { text: "Русский", value: "ru" },
                { text: "Ślōnski", value: "szl" }
            ]
            textRole: "text"
            valueRole: "value"
            onActivated: function(index) {
                var v = model[index].value
                if (backend.setOption("language", v)) root.restartRequired = true
            }
        }

        Label { text: qsTr("Qt Quick Controls style"); color: theme.textMuted }
        ComboBox {
            id: themeCombo
            Layout.fillWidth: true
            textRole: "text"
            valueRole: "value"
            Component.onCompleted: {
                var out = [{ text: qsTr("System"), value: "system" }]
                var styles = availableStyles
                for (var i = 0; i < styles.length; i++) {
                    var value = styles[i]
                    var text = value
                    if (value === "org.kde.desktop") text = "Breeze"
                    out.push({ text: text, value: value })
                }
                themeCombo.model = out
            }
            onActivated: function(index) {
                var v = model[index].value
                if (backend.setOption("theme", v)) root.restartRequired = true
            }
        }

        Label { text: qsTr("Hardware acceleration"); color: theme.textMuted }
        ComboBox {
            id: hwdecCombo
            Layout.fillWidth: true
            model: [
                { text: "auto-copy", value: "auto-copy" },
                { text: "auto", value: "auto" },
                { text: qsTr("Off"), value: "no" },
                { text: "VAAPI", value: "vaapi" },
                { text: "VAAPI copy", value: "vaapi-copy" },
                { text: "CUDA", value: "cuda" },
                { text: "CUDA copy", value: "cuda-copy" },
                { text: "D3D11VA", value: "d3d11va" },
                { text: "D3D11VA copy", value: "d3d11va-copy" }
            ]
            textRole: "text"
            valueRole: "value"
            onActivated: function(index) {
                var v = model[index].value
                if (backend.setOption("hwdec", v)) root.restartRequired = true
            }
        }

        Label {
            text: qsTr("Some settings take effect on the next launch.")
            color: theme.accent
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: root.restartRequired
        }

        Label { text: qsTr("Updates"); font.bold: true; font.pixelSize: 14; color: theme.text; Layout.topMargin: 6 }

        SwitchRow {
            id: checkForUpdatesSwitch
            label: qsTr("Check for updates on startup")
            checked: true
            onCheckedChanged: {
                if (root._loadingOptions) return
                backend.setOption("checkForUpdates", String(checked))
            }
        }
    }
}
