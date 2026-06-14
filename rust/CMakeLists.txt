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

add_custom_command(TARGET rust_lib POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_SOURCE_DIR}/default_profiles.toml
        $<TARGET_FILE_DIR:guinea-mpeg>/default_profiles.toml
    COMMENT "Copying default profiles"
)
