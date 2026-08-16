find_package(Qt6 REQUIRED COMPONENTS Test QuickTest Quick)

# Rust core unit tests (separate test binary via cargo).
add_test(NAME rust-core
    COMMAND ${CARGO} test --manifest-path ${CMAKE_SOURCE_DIR}/rust/Cargo.toml
)

if(NOT WIN32)
    # QML JS utility tests (Qt Quick Test). QUICK_TEST_SOURCE_DIR points the
    # runner at the .qml test files; pure JS/pure QML, no mpv/GL.
    add_executable(tst_qml tst_qml_main.cpp)
    target_compile_definitions(tst_qml PRIVATE
        QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml")
    target_link_libraries(tst_qml PRIVATE Qt6::QuickTest Qt6::Quick Qt6::Qml)
    add_test(NAME tst_qml COMMAND tst_qml)
    set_tests_properties(tst_qml PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

    # C++ FFI smoke test against the Rust cdylib (validates the C header contract).
    add_executable(tst_backend_ffi cpp/tst_backend_ffi.cpp)
    target_include_directories(tst_backend_ffi PRIVATE ${RUST_PROJECT_DIR}/include)
    target_link_libraries(tst_backend_ffi PRIVATE Qt6::Test ${RUST_LIB})
    add_dependencies(tst_backend_ffi rust_lib)
    add_test(NAME tst_backend_ffi COMMAND tst_backend_ffi)
    set_tests_properties(tst_backend_ffi PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
endif()