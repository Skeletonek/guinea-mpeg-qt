qt_add_resources(guinea-mpeg "app_qml"
    PREFIX "/"
    BASE ${CMAKE_SOURCE_DIR}
    FILES
        ${CMAKE_SOURCE_DIR}/qml/main.qml
        ${CMAKE_SOURCE_DIR}/media/logo/logo.png
        ${CMAKE_SOURCE_DIR}/media/logo/app.ico
        ${CMAKE_SOURCE_DIR}/media/logo/skeletonek.jpg
        ${CMAKE_SOURCE_DIR}/media/icons/info.png
        ${CMAKE_SOURCE_DIR}/media/icons/settings.png
        ${CMAKE_SOURCE_DIR}/qml/TimelineControl.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor.qml
        ${CMAKE_SOURCE_DIR}/qml/VideoPreview.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/AboutDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/OptionsDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/DeleteProfileDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/FfmpegWarningDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/FileOpenDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/FileSaveDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/ProfileExportDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/ProfileImportDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/ProfileImportConflictDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/MpvWarningDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/RestoreDefaultsDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/OverwriteConfirmDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/EncoderCompatDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/TranscodeDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/ControlsPanel.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/VideoPanel.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/AudioPanel.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/AdvancedPanel.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/VideoPanel/CodecSection.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/VideoPanel/RateControlSection.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/VideoPanel/PresetTuneSection.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/VideoPanel/PixelFormatSection.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/VideoPanel/ScalingSection.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/VideoPanel/AV1Section.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/VideoPanel/VP8VP9Section.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/VideoPanel/AnimatedSection.qml
        ${CMAKE_SOURCE_DIR}/qml/Utils/Centering.js
        ${CMAKE_SOURCE_DIR}/qml/Utils/FormatUtils.js
        ${CMAKE_SOURCE_DIR}/qml/Utils/DataUtils.js
        ${CMAKE_SOURCE_DIR}/qml/Utils/Constants.js
        ${CMAKE_SOURCE_DIR}/qml/Utils/UpdateUtils.js
        ${CMAKE_SOURCE_DIR}/qml/Components/LabeledRow.qml
        ${CMAKE_SOURCE_DIR}/qml/Components/LabeledComboBox.qml
        ${CMAKE_SOURCE_DIR}/qml/Components/LabeledTextField.qml
        ${CMAKE_SOURCE_DIR}/qml/Components/SwitchRow.qml
        ${CMAKE_SOURCE_DIR}/qml/Components/SectionHeader.qml
        ${CMAKE_SOURCE_DIR}/qml/Components/FormGroup.qml
        ${CMAKE_SOURCE_DIR}/qml/Components/WidgetHeader.qml
        ${CMAKE_SOURCE_DIR}/qml/Components/UpdateBanner.qml
        ${CMAKE_SOURCE_DIR}/media/images/lettuce.png
        ${CMAKE_SOURCE_DIR}/media/audio/guinea.wav
)

option(GUINEA_LUPDATE_NO_OBSOLETE "Pass -no-obsolete to lupdate (drop obsolete/vanished entries)" OFF)

set(_lupdate_no_obsolete)
if(GUINEA_LUPDATE_NO_OBSOLETE)
    set(_lupdate_no_obsolete LUPDATE_OPTIONS -no-obsolete)
endif()

qt_add_translations(guinea-mpeg
    TS_FILES
        ${CMAKE_SOURCE_DIR}/translations/guinea-mpeg_cs.ts
        ${CMAKE_SOURCE_DIR}/translations/guinea-mpeg_de.ts
        ${CMAKE_SOURCE_DIR}/translations/guinea-mpeg_es.ts
        ${CMAKE_SOURCE_DIR}/translations/guinea-mpeg_fr.ts
        ${CMAKE_SOURCE_DIR}/translations/guinea-mpeg_it.ts
        ${CMAKE_SOURCE_DIR}/translations/guinea-mpeg_ru.ts
        ${CMAKE_SOURCE_DIR}/translations/guinea-mpeg_szl.ts
        ${CMAKE_SOURCE_DIR}/translations/guinea-mpeg_pl_PL.ts
    ${_lupdate_no_obsolete}
)