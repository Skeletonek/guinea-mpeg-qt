cmake_minimum_required(VERSION 3.16)
project(guinea_mpeg VERSION 0.6.2 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
    add_compile_options(-mdirect-extern-access)
endif()

if(UNIX)
    if(CMAKE_LIBRARY_ARCHITECTURE)
        list(PREPEND CMAKE_LIBRARY_PATH "/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}")
    endif()
    include(GNUInstallDirs)
endif()

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2 Widgets Multimedia LinguistTools)
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

# Rust library path setup
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

# Read full semver from canonical Cargo.toml (may include pre-release suffix like -dev)
file(READ "${CMAKE_SOURCE_DIR}/rust/Cargo.toml" CARGO_TOML)
string(REGEX MATCH "version = \"([^\"]+)\"" _ "${CARGO_TOML}")
set(PROJECT_VERSION_FULL "${CMAKE_MATCH_1}")

add_subdirectory(rust)
add_subdirectory(src)
add_subdirectory(qml)

if(NOT WIN32)
    install(TARGETS guinea-mpeg
        BUNDLE DESTINATION .
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )

    install(FILES ${RUST_LIB} DESTINATION ${CMAKE_INSTALL_LIBDIR})

    set_target_properties(guinea-mpeg PROPERTIES INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")

    install(FILES ${CMAKE_SOURCE_DIR}/default_profiles.toml
        DESTINATION ${CMAKE_INSTALL_DATADIR}/guinea-mpeg
    )
endif()
