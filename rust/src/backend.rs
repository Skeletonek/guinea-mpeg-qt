use std::ffi::{CStr, CString};
use std::os::raw::c_char;

fn to_json<T: serde::Serialize>(val: &T) -> *mut c_char {
    CString::new(serde_json::to_string(val).unwrap_or_default())
        .unwrap()
        .into_raw()
}

unsafe fn from_cstr<'a>(ptr: *const c_char) -> &'a str {
    if ptr.is_null() {
        return "";
    }
    CStr::from_ptr(ptr).to_str().unwrap_or("")
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_available_profiles() -> *mut c_char {
    let names = crate::config::available_profiles();
    to_json(&names)
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_default_profile_names() -> *mut c_char {
    let names = crate::config::default_profile_names();
    to_json(&names)
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_load_profile(name: *const c_char) -> *mut c_char {
    let n = unsafe { from_cstr(name) };
    let profile = crate::config::load_profile(n);
    to_json(&profile)
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_save_profile(
    name: *const c_char,
    json: *const c_char,
) -> bool {
    let n = unsafe { from_cstr(name) };
    let j = unsafe { from_cstr(json) };
    crate::config::save_profile(n, j).is_ok()
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_restore_defaults() -> bool {
    crate::config::restore_defaults().is_ok()
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_delete_profile(name: *const c_char) -> bool {
    let n = unsafe { from_cstr(name) };
    crate::config::delete_profile(n).is_ok()
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            drop(CString::from_raw(s));
        }
    }
}
