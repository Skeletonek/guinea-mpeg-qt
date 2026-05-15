cmake_minimum_required(VERSION 3.16)
project(guinea_mpeg VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2 Widgets Multimedia)
find_program(CARGO cargo REQUIRED)

qt_standard_project_setup()

# Main executable
qt_add_executable(appguinea_mpeg
    main.cpp
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
    PRIVATE Qt6::Multimedia
    PRIVATE ${CMAKE_DL_LIBS}
)

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

install(TARGETS appguinea_mpeg
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
