use std::ffi::{CStr, CString};
use std::os::raw::c_char;

mod config;
mod ffmpeg;

// Helper: Convert C string to Rust string
fn cstr_to_string(ptr: *const c_char) -> String {
    if ptr.is_null() {
        return String::new();
    }
    unsafe { CStr::from_ptr(ptr) }.to_string_lossy().into_owned()
}

// Helper: Convert Rust string to C string (caller must free with `free_rust_string`)
fn string_to_cstr(s: String) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

/// Free a string allocated by Rust
#[unsafe(no_mangle)]
pub extern "C" fn free_rust_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe { let _ = CString::from_raw(s); }
    }
}

/// Initialize the library (call once at startup)
#[unsafe(no_mangle)]
pub extern "C" fn init_core() -> bool {
    true
}

/// Get available profile names as JSON array string
#[unsafe(no_mangle)]
pub extern "C" fn available_profiles() -> *mut c_char {
    let profiles = config::available_profiles();
    string_to_cstr(serde_json::to_string(&profiles).unwrap_or_default())
}

/// Get a profile by name as JSON string
#[unsafe(no_mangle)]
pub extern "C" fn load_profile(name: *const c_char) -> *mut c_char {
    let name = cstr_to_string(name);
    let profile = config::load_profile(&name);
    string_to_cstr(serde_json::to_string(&profile).unwrap_or_default())
}

/// Save a profile from JSON string
#[unsafe(no_mangle)]
pub extern "C" fn save_profile(name: *const c_char, json: *const c_char) -> bool {
    let name = cstr_to_string(name);
    let json = cstr_to_string(json);
    config::save_profile(&name, &json).is_ok()
}

/// Delete a profile
#[unsafe(no_mangle)]
pub extern "C" fn delete_profile(name: *const c_char) -> bool {
    let name = cstr_to_string(name);
    config::delete_profile(&name).is_ok()
}

/// Build FFmpeg command line for a given profile
/// Returns JSON with args array
#[unsafe(no_mangle)]
pub extern "C" fn build_ffmpeg_command(
    input: *const c_char,
    output: *const c_char,
    start_time: f64,
    end_time: f64,
    profile_json: *const c_char,
) -> *mut c_char {
    let input = cstr_to_string(input);
    let output = cstr_to_string(output);
    let profile_json = cstr_to_string(profile_json);

    let args = ffmpeg::build_command(&input, &output, start_time, end_time, &profile_json);
    string_to_cstr(serde_json::to_string(&args).unwrap_or_default())
}


