import "../Utils/DataUtils.js" as DataUtils
import QtQuick 2.15
import QtQuick.Dialogs

FileDialog {
    id: root

    signal conflictsFound(string path, var conflicts)
    signal importFinished(var summary)
    signal importFailed(string message)

    title: qsTr("Import Profiles")
    nameFilters: [qsTr("TOML files (*.toml)")]
    onAccepted: {
        var path = DataUtils.toLocalPath(root.selectedFile);
        var preview = {};
        try {
            preview = JSON.parse(backend.importProfilesPreview(path));
        } catch (e) {}
        if (preview.error) {
            root.importFailed(preview.error);
            return;
        }
        if (preview.conflicts && preview.conflicts.length > 0) {
            root.conflictsFound(path, preview.conflicts);
            return;
        }
        var summary = {};
        try {
            summary = JSON.parse(backend.importProfiles(path, false));
        } catch (e) {}
        root.importFinished(summary);
    }
}
