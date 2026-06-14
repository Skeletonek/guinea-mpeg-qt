qt_add_resources(guinea-mpeg "app_qml"
    PREFIX "/"
    BASE ${CMAKE_SOURCE_DIR}
    FILES
        ${CMAKE_SOURCE_DIR}/qml/main.qml
        ${CMAKE_SOURCE_DIR}/media/logo/logo.png
        ${CMAKE_SOURCE_DIR}/media/icons/info.png
        ${CMAKE_SOURCE_DIR}/qml/TimelineControl.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor.qml
        ${CMAKE_SOURCE_DIR}/qml/VideoPreview.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/AboutDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/DeleteProfileDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/FfmpegWarningDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/FileOpenDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/FileSaveDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/MpvWarningDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/RestoreDefaultsDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/Dialogs/TranscodeDialog.qml
        ${CMAKE_SOURCE_DIR}/qml/ControlsPanel.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/VideoPanel.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/AudioPanel.qml
        ${CMAKE_SOURCE_DIR}/qml/ProfileEditor/AdvancedPanel.qml
        ${CMAKE_SOURCE_DIR}/qml/Utils/Centering.js
        ${CMAKE_SOURCE_DIR}/media/images/lettuce.png
        ${CMAKE_SOURCE_DIR}/media/audio/guinea.wav
)
