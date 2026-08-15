if(WIN32)
    set(GUINEA_APP_SOURCES main.cpp backend.cpp app.rc)
else()
    set(GUINEA_APP_SOURCES main.cpp backend.cpp)
endif()

qt_add_executable(guinea-mpeg
    ${GUINEA_APP_SOURCES}
    mpvitem.h
    mpvitem.cpp
    backend.h
)

target_include_directories(guinea-mpeg PRIVATE ${RUST_PROJECT_DIR}/include)

target_link_libraries(guinea-mpeg
    PRIVATE Qt6::Quick
    PRIVATE Qt6::QuickControls2
    PRIVATE Qt6::Gui
    PRIVATE Qt6::Widgets
    PRIVATE Qt6::Multimedia
)

if(WIN32)
    if(NOT CONSOLE_MODE)
        set_target_properties(guinea-mpeg PROPERTIES WIN32_EXECUTABLE TRUE)
    endif()
    target_link_libraries(guinea-mpeg
        PRIVATE mpv::mpv
        PRIVATE OpenGL::GL
    )
    target_link_libraries(guinea-mpeg PRIVATE "${RUST_SYSROOT_DIR}/${RUST_LIB_PROFILE}/guinea_mpeg_core.dll.lib")

    add_custom_command(TARGET guinea-mpeg POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${RUST_SYSROOT_DIR}/${RUST_LIB_PROFILE}/guinea_mpeg_core.dll"
            $<TARGET_FILE_DIR:guinea-mpeg>
        COMMENT "Copying Rust DLL to output"
    )
else()
    target_link_libraries(guinea-mpeg
        PRIVATE PkgConfig::MPV
        PRIVATE PkgConfig::OPENGL
        PRIVATE Qt6::DBus
    )
    target_link_libraries(guinea-mpeg PRIVATE ${RUST_LIB})
endif()

add_dependencies(guinea-mpeg rust_lib)

target_compile_definitions(guinea-mpeg PRIVATE
    PACKAGE_TARGET="${PACKAGE_TARGET}"
    PROJECT_VERSION="${PROJECT_VERSION}"
    PROJECT_VERSION_FULL="${PROJECT_VERSION_FULL}"
)
