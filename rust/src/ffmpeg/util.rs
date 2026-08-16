use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::process::Command;

// On Windows, without CREATE_NO_WINDOW each child flashes a console window.
pub(crate) fn quiet_command(prog: &str) -> Command {
    #[cfg_attr(not(target_os = "windows"), allow(unused_mut))]
    let mut cmd = Command::new(prog);
    #[cfg(target_os = "windows")]
    {
        use std::os::windows::process::CommandExt;
        cmd.creation_flags(0x0800_0000); // CREATE_NO_WINDOW
    }
    cmd
}

pub(crate) fn normalize_path(path: &str) -> String {
    #[cfg(target_os = "windows")]
    {
        let bytes = path.as_bytes();
        if bytes.len() >= 3 && bytes[0] == b'/' && bytes[2] == b':' {
            return path[1..].to_string();
        }
    }
    path.to_string()
}

pub(crate) fn run_cmd(prog: &str, args: &[&str]) -> Option<String> {
    let output = quiet_command(prog).args(args).output().ok()?;
    if output.status.success() {
        String::from_utf8(output.stdout).ok()
    } else {
        None
    }
}

pub(crate) fn to_c_string(s: String) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

pub(crate) unsafe fn cstr(ptr: *const c_char) -> &'static str {
    if ptr.is_null() { "" } else { CStr::from_ptr(ptr).to_str().unwrap_or("") }
}
