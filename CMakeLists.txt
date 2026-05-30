cmake_minimum_required(VERSION 3.16)
project(guinea_mpeg VERSION 0.2.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# GCC 14+ / Qt 6.11 compat: prevent copy-relocation errors against protected
# Qt symbols (GNU_PROPERTY_1_NEEDED_INDIRECT_EXTERN_ACCESS).
add_compile_options(-mdirect-extern-access)

# Debian/Ubuntu multiarch: ensure CMake finds OpenGL/GLX in the correct path
# (avoid dangling symlinks in /usr/lib/)
if(CMAKE_LIBRARY_ARCHITECTURE)
    list(PREPEND CMAKE_LIBRARY_PATH "/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}")
endif()

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2 Widgets)
find_package(PkgConfig REQUIRED)
include(GNUInstallDirs)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
pkg_check_modules(OPENGL REQUIRED IMPORTED_TARGET opengl glx)
find_program(CARGO cargo REQUIRED)

qt_standard_project_setup()

# Default package target; override via -DPACKAGE_TARGET=deb|rpm|pacman|flatpak|appimage|generic
if(NOT PACKAGE_TARGET)
    set(PACKAGE_TARGET "generic")
endif()

# Main executable
qt_add_executable(guinea-mpeg
    src/main.cpp
    src/mpvitem.h
    src/mpvitem.cpp
)

# Embed QML files directly using resource file
qt_add_resources(guinea-mpeg "app_qml"
    PREFIX "/"
    FILES
        qml/main.qml
        qml/TimelineControl.qml
        qml/ProfileEditor.qml
        qml/VideoPreview.qml
        qml/dialogs/AboutDialog.qml
        qml/dialogs/FfmpegWarningDialog.qml
        qml/dialogs/TranscodeDialog.qml
        qml/dialogs/FileOpenDialog.qml
        qml/dialogs/FileSaveDialog.qml
        qml/ControlsPanel.qml
)

# Link Qt libraries
target_link_libraries(guinea-mpeg
    PRIVATE Qt6::Quick
    PRIVATE Qt6::QuickControls2
    PRIVATE Qt6::Gui
    PRIVATE Qt6::Widgets
    PRIVATE ${CMAKE_DL_LIBS}
    PRIVATE PkgConfig::MPV
    PRIVATE PkgConfig::OPENGL
)

# Pass build info to C++
target_compile_definitions(guinea-mpeg PRIVATE
    PACKAGE_TARGET="${PACKAGE_TARGET}"
    PROJECT_VERSION="${PROJECT_VERSION}"
)

# Set RPATH so the binary finds libguinea_mpeg_core.so at runtime
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_FULL_LIBDIR}/guinea-mpeg")

# Build Rust library
set(RUST_PROJECT_DIR ${CMAKE_SOURCE_DIR}/rust)
if(DEFINED ENV{CARGO_TARGET_DIR})
    set(RUST_TARGET_DIR "$ENV{CARGO_TARGET_DIR}")
else()
    set(RUST_TARGET_DIR "${RUST_PROJECT_DIR}/target")
endif()
set(RUST_LIB_PATH ${RUST_TARGET_DIR}/release/libguinea_mpeg_core.so)

add_custom_target(rust_lib ALL
    COMMAND ${CARGO} build --release
    WORKING_DIRECTORY ${RUST_PROJECT_DIR}
    COMMENT "Building Rust library"
    BYPRODUCTS ${RUST_LIB_PATH}
)

add_dependencies(guinea-mpeg rust_lib)

# Copy Rust library to build directory
add_custom_command(TARGET rust_lib POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${RUST_LIB_PATH}
        $<TARGET_FILE_DIR:guinea-mpeg>/libguinea_mpeg_core.so
    COMMENT "Copying Rust library"
)

# Copy default profiles next to the binary
add_custom_command(TARGET rust_lib POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_SOURCE_DIR}/default_profiles.toml
        $<TARGET_FILE_DIR:guinea-mpeg>/default_profiles.toml
    COMMENT "Copying default profiles"
)

install(TARGETS guinea-mpeg
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Install Rust library to lib/guinea-mpeg/
install(FILES ${RUST_LIB_PATH}
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/guinea-mpeg
    RENAME libguinea_mpeg_core.so
)

# Install default profiles
install(FILES ${CMAKE_SOURCE_DIR}/default_profiles.toml
    DESTINATION ${CMAKE_INSTALL_DATADIR}/guinea-mpeg
)
