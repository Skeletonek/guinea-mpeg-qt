use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_void};

use libmpv2_sys::*;

const EVENT_NONE: mpv_event_id = mpv_event_id_MPV_EVENT_NONE;
const EVENT_PLAYBACK_RESTART: mpv_event_id = mpv_event_id_MPV_EVENT_PLAYBACK_RESTART;
const EVENT_END_FILE: mpv_event_id = mpv_event_id_MPV_EVENT_END_FILE;
const EVENT_PROPERTY_CHANGE: mpv_event_id = mpv_event_id_MPV_EVENT_PROPERTY_CHANGE;
const FORMAT_DOUBLE: mpv_format = mpv_format_MPV_FORMAT_DOUBLE;
const FORMAT_FLAG: mpv_format = mpv_format_MPV_FORMAT_FLAG;

pub struct MpvBackend {
    handle: *mut mpv_handle,
    position: i32,
    duration: i32,
    playing: bool,
}

unsafe impl Send for MpvBackend {}
unsafe impl Sync for MpvBackend {}

impl Drop for MpvBackend {
    fn drop(&mut self) {
        if !self.handle.is_null() {
            unsafe {
                mpv_command_string(self.handle, CString::new("stop").unwrap().as_ptr());
                mpv_terminate_destroy(self.handle);
            }
        }
    }
}

impl MpvBackend {
    fn set_string(&self, name: &str, val: &str) {
        unsafe {
            mpv_set_property_string(
                self.handle,
                CString::new(name).unwrap().as_ptr(),
                CString::new(val).unwrap().as_ptr(),
            );
        }
    }

    fn raw_handle(&self) -> *mut mpv_handle {
        self.handle
    }
}

fn set_opt(handle: *mut mpv_handle, name: &str, val: &str) {
    unsafe {
        mpv_set_option_string(
            handle,
            CString::new(name).unwrap().as_ptr(),
            CString::new(val).unwrap().as_ptr(),
        );
    }
}

fn observe(handle: *mut mpv_handle, name: &str, format: mpv_format) {
    unsafe {
        mpv_observe_property(handle, 0, CString::new(name).unwrap().as_ptr(), format);
    }
}

fn backend_from_ptr(ptr: *mut c_void) -> &'static mut MpvBackend {
    unsafe { &mut *(ptr as *mut MpvBackend) }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_create() -> *mut c_void {
    let handle = unsafe { mpv_create() };
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let opts = crate::config::get_options();

    set_opt(handle, "vo", "libmpv");
    set_opt(handle, "keep-open", "yes");
    set_opt(handle, "volume", &opts.preview_volume.to_string());
    set_opt(handle, "cache", "yes");
    set_opt(handle, "hwdec", &opts.hwdec);

    unsafe { mpv_initialize(handle) };

    observe(handle, "time-pos", FORMAT_DOUBLE);
    observe(handle, "duration", FORMAT_DOUBLE);
    observe(handle, "pause", FORMAT_FLAG);

    let backend = Box::new(MpvBackend {
        handle,
        position: 0,
        duration: 0,
        playing: false,
    });

    Box::into_raw(backend) as *mut c_void
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_destroy(ptr: *mut c_void) {
    if !ptr.is_null() {
        unsafe {
            drop(Box::from_raw(ptr as *mut MpvBackend));
        }
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_available() -> bool {
    let handle = unsafe { mpv_create() };
    if handle.is_null() {
        return false;
    }
    let ok = unsafe { mpv_initialize(handle) } == 0;
    unsafe { mpv_terminate_destroy(handle) };
    ok
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_version() -> *mut c_char {
    let handle = unsafe { mpv_create() };
    if handle.is_null() {
        return std::ptr::null_mut();
    }
    if unsafe { mpv_initialize(handle) } != 0 {
        unsafe { mpv_terminate_destroy(handle) };
        return std::ptr::null_mut();
    }
    let result = unsafe {
        let prop = mpv_get_property_string(handle, CString::new("mpv-version").unwrap().as_ptr());
        if prop.is_null() {
            std::ptr::null_mut()
        } else {
            let s = CStr::from_ptr(prop).to_str().unwrap_or("").to_string();
            mpv_free(prop as *mut c_void);
            CString::new(s).unwrap_or_default().into_raw()
        }
    };
    unsafe { mpv_terminate_destroy(handle) };
    result
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_raw_handle(ptr: *mut c_void) -> *mut c_void {
    if ptr.is_null() {
        return std::ptr::null_mut();
    }
    backend_from_ptr(ptr).raw_handle() as *mut c_void
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_load_file(ptr: *mut c_void, path: *const c_char) {
    if ptr.is_null() || path.is_null() {
        return;
    }
    let p = unsafe { CStr::from_ptr(path) }.to_str().unwrap_or("");
    if p.is_empty() {
        return;
    }
    let backend = backend_from_ptr(ptr);
    let c_loadfile = CString::new("loadfile").unwrap();
    let c_path = CString::new(p).unwrap();
    let args = [c_loadfile.as_ptr(), c_path.as_ptr(), std::ptr::null()];
    unsafe {
        mpv_command(backend.handle, args.as_ptr() as *mut *const c_char);
        mpv_set_property_string(
            backend.handle,
            CString::new("pause").unwrap().as_ptr(),
            CString::new("no").unwrap().as_ptr(),
        );
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_play(ptr: *mut c_void) {
    if !ptr.is_null() {
        backend_from_ptr(ptr).set_string("pause", "no");
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_pause(ptr: *mut c_void) {
    if !ptr.is_null() {
        backend_from_ptr(ptr).set_string("pause", "yes");
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_stop(ptr: *mut c_void) {
    if !ptr.is_null() {
        unsafe {
            mpv_command_string(
                backend_from_ptr(ptr).handle,
                CString::new("stop").unwrap().as_ptr(),
            );
        }
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_seek(ptr: *mut c_void, pos_ms: i32) {
    if !ptr.is_null() {
        let cmd = CString::new(format!("seek {} absolute", pos_ms as f64 / 1000.0)).unwrap();
        unsafe {
            mpv_command_string(backend_from_ptr(ptr).handle, cmd.as_ptr());
        }
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_set_volume(ptr: *mut c_void, vol: i32) {
    if !ptr.is_null() {
        backend_from_ptr(ptr).set_string("volume", &vol.clamp(0, 100).to_string());
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_volume(ptr: *mut c_void) -> i32 {
    if ptr.is_null() {
        return 0;
    }
    let mut vol: f64 = 0.0;
    unsafe {
        mpv_get_property(
            backend_from_ptr(ptr).handle,
            CString::new("volume").unwrap().as_ptr(),
            FORMAT_DOUBLE,
            &mut vol as *mut _ as *mut c_void,
        );
    }
    vol as i32
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_process_events(ptr: *mut c_void) -> i32 {
    if ptr.is_null() {
        return 0;
    }
    let backend = backend_from_ptr(ptr);
    let mut changed = 0i32;

    unsafe {
        loop {
            let event = mpv_wait_event(backend.handle, 0.0);
            if (*event).event_id == EVENT_NONE {
                break;
            }

            match (*event).event_id {
                EVENT_PLAYBACK_RESTART => {
                    let mut paused: i32 = 0;
                    mpv_get_property(
                        backend.handle,
                        CString::new("pause").unwrap().as_ptr(),
                        FORMAT_FLAG,
                        &mut paused as *mut _ as *mut c_void,
                    );
                    let new_playing = paused == 0;
                    if new_playing != backend.playing {
                        backend.playing = new_playing;
                        changed |= 4;
                    }
                }
                EVENT_END_FILE => {
                    if backend.playing {
                        backend.playing = false;
                        backend.position = 0;
                        changed |= 6;
                    }
                }
                EVENT_PROPERTY_CHANGE => {
                    let prop = &*((*event).data as *const mpv_event_property);
                    let name = CStr::from_ptr(prop.name).to_str().unwrap_or("");
                    if name == "time-pos" && prop.format == FORMAT_DOUBLE {
                        let pos = *(prop.data as *const f64);
                        let new_pos = (pos * 1000.0).max(0.0) as i32;
                        if new_pos != backend.position {
                            backend.position = new_pos;
                            changed |= 1;
                        }
                    } else if name == "duration" && prop.format == FORMAT_DOUBLE {
                        let dur = *(prop.data as *const f64);
                        let new_dur = (dur * 1000.0).max(0.0) as i32;
                        if new_dur != backend.duration {
                            backend.duration = new_dur;
                            changed |= 2;
                        }
                    } else if name == "pause" && prop.format == FORMAT_FLAG {
                        let flag = *(prop.data as *const i32);
                        let new_playing = flag == 0;
                        if new_playing != backend.playing {
                            backend.playing = new_playing;
                            changed |= 4;
                        }
                    }
                }
                _ => {}
            }
        }
    }

    // Fallback: property observation events can be missed (e.g. lost wakeups
    // on some platforms), so poll the observed properties directly as well.
    // Reads are cheap and only report a change when the cached value differs.
    unsafe {
        let mut pos: f64 = 0.0;
        if mpv_get_property(
            backend.handle,
            CString::new("time-pos").unwrap().as_ptr(),
            FORMAT_DOUBLE,
            &mut pos as *mut _ as *mut c_void,
        ) == 0
        {
            let new_pos = (pos * 1000.0).max(0.0) as i32;
            if new_pos != backend.position {
                backend.position = new_pos;
                changed |= 1;
            }
        }

        let mut dur: f64 = 0.0;
        if mpv_get_property(
            backend.handle,
            CString::new("duration").unwrap().as_ptr(),
            FORMAT_DOUBLE,
            &mut dur as *mut _ as *mut c_void,
        ) == 0
        {
            let new_dur = (dur * 1000.0).max(0.0) as i32;
            if new_dur != backend.duration {
                backend.duration = new_dur;
                changed |= 2;
            }
        }

        let mut paused: i32 = 0;
        if mpv_get_property(
            backend.handle,
            CString::new("pause").unwrap().as_ptr(),
            FORMAT_FLAG,
            &mut paused as *mut _ as *mut c_void,
        ) == 0
        {
            let new_playing = paused == 0;
            if new_playing != backend.playing {
                backend.playing = new_playing;
                changed |= 4;
            }
        }
    }

    changed
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_position(ptr: *const c_void) -> i32 {
    if ptr.is_null() {
        return 0;
    }
    (unsafe { &*(ptr as *const MpvBackend) }).position
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_duration(ptr: *const c_void) -> i32 {
    if ptr.is_null() {
        return 0;
    }
    (unsafe { &*(ptr as *const MpvBackend) }).duration
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_is_playing(ptr: *const c_void) -> bool {
    if ptr.is_null() {
        return false;
    }
    (unsafe { &*(ptr as *const MpvBackend) }).playing
}
