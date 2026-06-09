cmake_minimum_required(VERSION 3.16)
project(guinea_mpeg VERSION 0.5.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
    # GCC 14+ / Qt 6.11 compat: prevent copy-relocation errors against protected
    # Qt symbols (GNU_PROPERTY_1_NEEDED_INDIRECT_EXTERN_ACCESS).
    add_compile_options(-mdirect-extern-access)
endif()

if(UNIX)
    if(CMAKE_LIBRARY_ARCHITECTURE)
        list(PREPEND CMAKE_LIBRARY_PATH "/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}")
    endif()
    include(GNUInstallDirs)
endif()

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2 Widgets)
if(UNIX AND NOT APPLE)
    find_package(Qt6 6.5 REQUIRED COMPONENTS DBus)
endif()

if(WIN32)
    find_path(MPV_INCLUDE_DIR mpv/client.h
        HINTS
            ${CMAKE_SOURCE_DIR}/build/windows/.mpv-dev
            $ENV{MPV_DIR}
        PATH_SUFFIXES include
    )
    find_library(MPV_LIBRARY
        NAMES mpv libmpv
        HINTS
            ${CMAKE_SOURCE_DIR}/build/windows/.mpv-dev
            $ENV{MPV_DIR}
        PATH_SUFFIXES lib .
    )
    if(NOT MPV_LIBRARY)
        find_file(MPV_LIBRARY_FILE
            NAMES mpv.lib libmpv.dll.a
            HINTS
                ${CMAKE_SOURCE_DIR}/build/windows/.mpv-dev
                $ENV{MPV_DIR}
            PATH_SUFFIXES lib .
        )
        if(MPV_LIBRARY_FILE)
            set(MPV_LIBRARY "${MPV_LIBRARY_FILE}")
        endif()
    endif()
    if(NOT MPV_INCLUDE_DIR OR NOT MPV_LIBRARY)
        message(FATAL_ERROR "mpv not found. Download shinchiro's mpv-dev bundle to "
            "build/windows/.mpv-dev/ or set MPV_DIR environment variable."
        )
    endif()
    add_library(mpv::mpv UNKNOWN IMPORTED)
    set_target_properties(mpv::mpv PROPERTIES
        IMPORTED_LOCATION "${MPV_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${MPV_INCLUDE_DIR}"
    )

    find_package(OpenGL REQUIRED)
else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
    pkg_check_modules(OPENGL REQUIRED IMPORTED_TARGET opengl glx)
endif()

find_program(CARGO cargo REQUIRED)

qt_standard_project_setup()

if(NOT PACKAGE_TARGET)
    set(PACKAGE_TARGET "generic")
endif()

set(RUST_PROJECT_DIR ${CMAKE_SOURCE_DIR}/rust)
if(DEFINED ENV{CARGO_TARGET_DIR})
    set(RUST_TARGET_DIR "$ENV{CARGO_TARGET_DIR}")
else()
    set(RUST_TARGET_DIR "${RUST_PROJECT_DIR}/target")
endif()

if(WIN32)
    set(RUST_LIB "${RUST_TARGET_DIR}/release/guinea_mpeg_core.dll")
elseif(APPLE)
    set(RUST_LIB "${RUST_TARGET_DIR}/release/libguinea_mpeg_core.dylib")
else()
    set(RUST_LIB "${RUST_TARGET_DIR}/release/libguinea_mpeg_core.so")
endif()

execute_process(COMMAND ${CARGO} build --release
    WORKING_DIRECTORY ${RUST_PROJECT_DIR}
    RESULT_VARIABLE CARGO_RESULT
)
if(NOT CARGO_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to build Rust library")
endif()

add_custom_target(rust_lib ALL
    COMMAND ${CARGO} build --release
    WORKING_DIRECTORY ${RUST_PROJECT_DIR}
    COMMENT "Building Rust library"
    BYPRODUCTS ${RUST_LIB}
)

if(WIN32)
    set(GUINEA_APP_SOURCES src/main.cpp src/backend.cpp src/app.rc)
else()
    set(GUINEA_APP_SOURCES src/main.cpp src/backend.cpp)
endif()
qt_add_executable(guinea-mpeg
    ${GUINEA_APP_SOURCES}
    src/mpvitem.h
    src/mpvitem.cpp
    src/backend.h
)

qt_add_resources(guinea-mpeg "app_qml"
    PREFIX "/"
    FILES
        qml/main.qml
        media/logo/logo.png
        media/icons/info.png
        qml/TimelineControl.qml
        qml/ProfileEditor.qml
        qml/VideoPreview.qml
        qml/dialogs/AboutDialog.qml
        qml/dialogs/FfmpegWarningDialog.qml
        qml/dialogs/TranscodeDialog.qml
        qml/dialogs/MpvWarningDialog.qml
        qml/dialogs/FileOpenDialog.qml
        qml/dialogs/FileSaveDialog.qml
        qml/ControlsPanel.qml
        qml/ProfileEditor/VideoPanel.qml
        qml/ProfileEditor/AudioPanel.qml
        qml/ProfileEditor/AdvancedPanel.qml
)

target_include_directories(guinea-mpeg PRIVATE ${RUST_PROJECT_DIR}/include)

target_link_libraries(guinea-mpeg
    PRIVATE Qt6::Quick
    PRIVATE Qt6::QuickControls2
    PRIVATE Qt6::Gui
    PRIVATE Qt6::Widgets

)

if(WIN32)
    if(NOT CONSOLE_MODE)
        set_target_properties(guinea-mpeg PROPERTIES WIN32_EXECUTABLE TRUE)
    endif()
    target_link_libraries(guinea-mpeg
        PRIVATE mpv::mpv
        PRIVATE OpenGL::GL
    )
else()
    target_link_libraries(guinea-mpeg
        PRIVATE PkgConfig::MPV
        PRIVATE PkgConfig::OPENGL
        PRIVATE Qt6::DBus
    )
endif()

if(WIN32)
    target_link_libraries(guinea-mpeg PRIVATE "${RUST_TARGET_DIR}/release/guinea_mpeg_core.dll.lib")
else()
    target_link_libraries(guinea-mpeg PRIVATE ${RUST_LIB})
endif()

add_dependencies(guinea-mpeg rust_lib)

# Read full semver from canonical Cargo.toml (may include pre-release suffix like -dev)
file(READ "${CMAKE_SOURCE_DIR}/rust/Cargo.toml" CARGO_TOML)
string(REGEX MATCH "version = \"([^\"]+)\"" _ "${CARGO_TOML}")
set(PROJECT_VERSION_FULL "${CMAKE_MATCH_1}")

target_compile_definitions(guinea-mpeg PRIVATE
    PACKAGE_TARGET="${PACKAGE_TARGET}"
    PROJECT_VERSION="${PROJECT_VERSION}"
    PROJECT_VERSION_FULL="${PROJECT_VERSION_FULL}"
)

if(WIN32)
    add_custom_command(TARGET guinea-mpeg POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${RUST_TARGET_DIR}/release/guinea_mpeg_core.dll"
            $<TARGET_FILE_DIR:guinea-mpeg>
        COMMENT "Copying Rust DLL to output"
    )
endif()

add_custom_command(TARGET rust_lib POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_SOURCE_DIR}/default_profiles.toml
        $<TARGET_FILE_DIR:guinea-mpeg>/default_profiles.toml
    COMMENT "Copying default profiles"
)

if(NOT WIN32)
    install(TARGETS guinea-mpeg
        BUNDLE DESTINATION .
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )

    install(FILES ${CMAKE_SOURCE_DIR}/default_profiles.toml
        DESTINATION ${CMAKE_INSTALL_DATADIR}/guinea-mpeg
    )
endif()
