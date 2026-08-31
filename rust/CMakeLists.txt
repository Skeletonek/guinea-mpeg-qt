set(_cargo_target_args)
if(RUST_TARGET)
    list(APPEND _cargo_target_args --target ${RUST_TARGET})
endif()

set(_cargo_profile_args)
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    list(APPEND _cargo_profile_args --release)
endif()

add_custom_target(rust_lib ALL
    COMMAND ${CARGO} build ${_cargo_profile_args} ${_cargo_target_args}
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
