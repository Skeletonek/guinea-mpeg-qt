import QtQuick 2.15
import QtQuick.Dialogs

FileDialog {
    id: root
    title: qsTr("Import Profiles")
    nameFilters: [qsTr("TOML files (*.toml)")]

    signal conflictsFound(string path, var conflicts)
    signal importFinished(var summary)
    signal importFailed(string message)

    onAccepted: {
        var path = String(root.selectedFile)
        if (path.startsWith("file://"))
            path = decodeURIComponent(path.substring(7))
        var preview = {}
        try { preview = JSON.parse(backend.importProfilesPreview(path)) } catch(e) {}
        if (preview.error) {
            root.importFailed(preview.error)
            return
        }
        if (preview.conflicts && preview.conflicts.length > 0) {
            root.conflictsFound(path, preview.conflicts)
            return
        }
        var summary = {}
        try { summary = JSON.parse(backend.importProfiles(path, false)) } catch(e) {}
        root.importFinished(summary)
    }
}
