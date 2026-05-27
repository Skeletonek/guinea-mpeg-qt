cmake_minimum_required(VERSION 3.16)
project(guinea_mpeg VERSION 0.2 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2 Widgets)
find_package(PkgConfig REQUIRED)
include(GNUInstallDirs)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
find_program(CARGO cargo REQUIRED)

qt_standard_project_setup()

# Main executable
qt_add_executable(appguinea_mpeg
    main.cpp
    mpvitem.h
    mpvitem.cpp
)

# Embed QML files directly using resource file
qt_add_resources(appguinea_mpeg "app_qml"
    PREFIX "/"
    FILES
        qml/main.qml
        qml/TimelineControl.qml
        qml/ProfileEditor.qml
        qml/VideoPreview.qml
)

# Link Qt libraries
target_link_libraries(appguinea_mpeg
    PRIVATE Qt6::Quick
    PRIVATE Qt6::QuickControls2
    PRIVATE Qt6::Gui
    PRIVATE Qt6::Widgets
    PRIVATE ${CMAKE_DL_LIBS}
    PRIVATE PkgConfig::MPV
)

# Set RPATH so the binary finds libguinea_mpeg_core.so at runtime
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_FULL_LIBDIR}/guinea-mpeg")

# Build Rust library
set(RUST_PROJECT_DIR ${CMAKE_SOURCE_DIR}/rust)
set(RUST_LIB_PATH ${RUST_PROJECT_DIR}/target/release/libguinea_mpeg_core.so)

add_custom_target(rust_lib ALL
    COMMAND ${CARGO} build --release
    WORKING_DIRECTORY ${RUST_PROJECT_DIR}
    COMMENT "Building Rust library"
    BYPRODUCTS ${RUST_LIB_PATH}
)

add_dependencies(appguinea_mpeg rust_lib)

# Copy Rust library to build directory
add_custom_command(TARGET rust_lib POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${RUST_LIB_PATH}
        $<TARGET_FILE_DIR:appguinea_mpeg>/libguinea_mpeg_core.so
    COMMENT "Copying Rust library"
)

# Copy default profiles next to the binary
add_custom_command(TARGET rust_lib POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_SOURCE_DIR}/default_profiles.toml
        $<TARGET_FILE_DIR:appguinea_mpeg>/default_profiles.toml
    COMMENT "Copying default profiles"
)

install(TARGETS appguinea_mpeg
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
