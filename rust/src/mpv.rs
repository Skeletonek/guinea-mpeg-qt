use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_void};
use std::sync::OnceLock;

use libmpv2_sys::*;

const MS_PER_SEC: f64 = 1000.0;
const MAX_VOLUME: i32 = 100;
const MIN_VOLUME: i32 = 0;
const CHANGED_POSITION: i32 = 1;
const CHANGED_DURATION: i32 = 2;
const CHANGED_PLAYING: i32 = 4;

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
                mpv_command_string(self.handle, c_str("stop").as_ptr());
                mpv_terminate_destroy(self.handle);
            }
        }
    }
}

impl MpvBackend {
    fn set_string(&self, name: &str, val: &str) {
        unsafe {
            mpv_set_property_string(self.handle, c_str(name).as_ptr(), c_str(val).as_ptr());
        }
    }

    fn raw_handle(&self) -> *mut mpv_handle {
        self.handle
    }
}

fn set_opt(handle: *mut mpv_handle, name: &str, val: &str) {
    unsafe {
        mpv_set_option_string(handle, c_str(name).as_ptr(), c_str(val).as_ptr());
    }
}

fn observe(handle: *mut mpv_handle, name: &str, format: mpv_format) {
    unsafe {
        mpv_observe_property(handle, 0, c_str(name).as_ptr(), format);
    }
}

fn backend_from_ptr(ptr: *mut c_void) -> &'static mut MpvBackend {
    unsafe { &mut *(ptr as *mut MpvBackend) }
}

#[inline]
fn f64_to_ms(v: f64) -> i32 {
    (v * MS_PER_SEC).max(0.0) as i32
}

#[inline]
fn c_str(s: &str) -> CString {
    CString::new(s).unwrap()
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

    observe(handle, "time-pos", mpv_format_MPV_FORMAT_DOUBLE);
    observe(handle, "duration", mpv_format_MPV_FORMAT_DOUBLE);
    observe(handle, "pause", mpv_format_MPV_FORMAT_FLAG);

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

// Cached: creating + initializing an instance just to probe it is expensive.
struct MpvProbe {
    available: bool,
    version: Option<String>,
}

fn mpv_probe() -> &'static MpvProbe {
    static PROBE: OnceLock<MpvProbe> = OnceLock::new();
    PROBE.get_or_init(|| {
        let handle = unsafe { mpv_create() };
        if handle.is_null() {
            return MpvProbe {
                available: false,
                version: None,
            };
        }
        if unsafe { mpv_initialize(handle) } != 0 {
            unsafe { mpv_terminate_destroy(handle) };
            return MpvProbe {
                available: false,
                version: None,
            };
        }
        let version = unsafe {
            let prop = mpv_get_property_string(handle, c_str("mpv-version").as_ptr());
            if prop.is_null() {
                None
            } else {
                let s = CStr::from_ptr(prop).to_str().unwrap_or("").to_string();
                mpv_free(prop as *mut c_void);
                Some(s)
            }
        };
        unsafe { mpv_terminate_destroy(handle) };
        MpvProbe {
            available: true,
            version,
        }
    })
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_available() -> bool {
    mpv_probe().available
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_version() -> *mut c_char {
    match &mpv_probe().version {
        Some(v) => CString::new(v.clone()).unwrap_or_default().into_raw(),
        None => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_raw_handle(ptr: *mut c_void) -> *mut c_void {
    if ptr.is_null() {
        return std::ptr::null_mut();
    }
    backend_from_ptr(ptr).raw_handle() as *mut c_void
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_load_file(ptr: *mut c_void, path: *const c_char, autoplay: bool) {
    if ptr.is_null() || path.is_null() {
        return;
    }
    let p = unsafe { CStr::from_ptr(path) }.to_str().unwrap_or("");
    if p.is_empty() {
        return;
    }
    let backend = backend_from_ptr(ptr);
    // Reset cache so an identical-duration reload is still reported as changed
    backend.position = 0;
    backend.duration = 0;
    let c_loadfile = c_str("loadfile");
    let c_path = c_str(p);
    let args = [c_loadfile.as_ptr(), c_path.as_ptr(), std::ptr::null()];
    unsafe {
        mpv_command(backend.handle, args.as_ptr() as *mut *const c_char);
        mpv_set_property_string(
            backend.handle,
            c_str("pause").as_ptr(),
            c_str(if autoplay { "no" } else { "yes" }).as_ptr(),
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
            mpv_command_string(backend_from_ptr(ptr).handle, c_str("stop").as_ptr());
        }
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_seek(ptr: *mut c_void, pos_ms: i32) {
    if !ptr.is_null() {
        let cmd = c_str(&format!("seek {} absolute", pos_ms as f64 / MS_PER_SEC));
        unsafe {
            mpv_command_string(backend_from_ptr(ptr).handle, cmd.as_ptr());
        }
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_set_volume(ptr: *mut c_void, vol: i32) {
    if !ptr.is_null() {
        backend_from_ptr(ptr).set_string("volume", &vol.clamp(MIN_VOLUME, MAX_VOLUME).to_string());
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
            c_str("volume").as_ptr(),
            mpv_format_MPV_FORMAT_DOUBLE,
            &mut vol as *mut _ as *mut c_void,
        );
    }
    vol as i32
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_set_mute(ptr: *mut c_void, mute: bool) {
    if !ptr.is_null() {
        backend_from_ptr(ptr).set_string("mute", if mute { "yes" } else { "no" });
    }
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_mute(ptr: *mut c_void) -> bool {
    if ptr.is_null() {
        return false;
    }
    let mut flag: i32 = 0;
    unsafe {
        mpv_get_property(
            backend_from_ptr(ptr).handle,
            c_str("mute").as_ptr(),
            mpv_format_MPV_FORMAT_FLAG,
            &mut flag as *mut _ as *mut c_void,
        );
    }
    flag != 0
}

#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_set_track(ptr: *mut c_void, prop: *const c_char, id: i32) {
    if ptr.is_null() || prop.is_null() {
        return;
    }
    let name = unsafe { CStr::from_ptr(prop) }.to_str().unwrap_or("");
    if name.is_empty() {
        return;
    }
    backend_from_ptr(ptr).set_string(name, &id.to_string());
}

#[allow(non_upper_case_globals)]
unsafe fn drain_mpv_events(backend: &mut MpvBackend) -> i32 {
    let mut changed = 0i32;
    loop {
        let event = mpv_wait_event(backend.handle, 0.0);
        if (*event).event_id == mpv_event_id_MPV_EVENT_NONE {
            break;
        }
        match (*event).event_id {
            mpv_event_id_MPV_EVENT_PLAYBACK_RESTART => {
                let mut paused: i32 = 0;
                mpv_get_property(
                    backend.handle,
                    c_str("pause").as_ptr(),
                    mpv_format_MPV_FORMAT_FLAG,
                    &mut paused as *mut _ as *mut c_void,
                );
                let new_playing = paused == 0;
                if new_playing != backend.playing {
                    backend.playing = new_playing;
                    changed |= CHANGED_PLAYING;
                }
            }
            mpv_event_id_MPV_EVENT_END_FILE => {
                if backend.playing {
                    backend.playing = false;
                    // Keep position at EOF: MpvItem::play's rewind check relies on it
                    changed |= CHANGED_DURATION | CHANGED_PLAYING;
                }
            }
            mpv_event_id_MPV_EVENT_PROPERTY_CHANGE => {
                let prop = &*((*event).data as *const mpv_event_property);
                let name = CStr::from_ptr(prop.name).to_str().unwrap_or("");
                if name == "time-pos" && prop.format == mpv_format_MPV_FORMAT_DOUBLE {
                    let pos = *(prop.data as *const f64);
                    let new_pos = f64_to_ms(pos);
                    if new_pos != backend.position {
                        backend.position = new_pos;
                        changed |= CHANGED_POSITION;
                    }
                } else if name == "duration" && prop.format == mpv_format_MPV_FORMAT_DOUBLE {
                    let dur = *(prop.data as *const f64);
                    let new_dur = f64_to_ms(dur);
                    if new_dur != backend.duration {
                        backend.duration = new_dur;
                        changed |= CHANGED_DURATION;
                    }
                } else if name == "pause" && prop.format == mpv_format_MPV_FORMAT_FLAG {
                    let flag = *(prop.data as *const i32);
                    let new_playing = flag == 0;
                    if new_playing != backend.playing {
                        backend.playing = new_playing;
                        changed |= CHANGED_PLAYING;
                    }
                }
            }
            _ => {}
        }
    }
    changed
}

unsafe fn poll_mpv_properties(backend: &mut MpvBackend) -> i32 {
    let mut changed = 0i32;
    let mut pos: f64 = 0.0;
    if mpv_get_property(
        backend.handle,
        c_str("time-pos").as_ptr(),
        mpv_format_MPV_FORMAT_DOUBLE,
        &mut pos as *mut _ as *mut c_void,
    ) == 0
    {
        let new_pos = f64_to_ms(pos);
        if new_pos != backend.position {
            backend.position = new_pos;
            changed |= CHANGED_POSITION;
        }
    }
    let mut dur: f64 = 0.0;
    if mpv_get_property(
        backend.handle,
        c_str("duration").as_ptr(),
        mpv_format_MPV_FORMAT_DOUBLE,
        &mut dur as *mut _ as *mut c_void,
    ) == 0
    {
        let new_dur = f64_to_ms(dur);
        if new_dur != backend.duration {
            backend.duration = new_dur;
            changed |= CHANGED_DURATION;
        }
    }
    let mut paused: i32 = 0;
    if mpv_get_property(
        backend.handle,
        c_str("pause").as_ptr(),
        mpv_format_MPV_FORMAT_FLAG,
        &mut paused as *mut _ as *mut c_void,
    ) == 0
    {
        let new_playing = paused == 0;
        if new_playing != backend.playing {
            backend.playing = new_playing;
            changed |= CHANGED_PLAYING;
        }
    }
    changed
}

#[allow(non_upper_case_globals)]
#[no_mangle]
pub extern "C" fn guinea_mpeg_mpv_process_events(ptr: *mut c_void) -> i32 {
    if ptr.is_null() {
        return 0;
    }
    let backend = backend_from_ptr(ptr);
    let mut changed = 0i32;
    unsafe {
        changed |= drain_mpv_events(backend);
    }
    // Fallback poll: observation events can be missed (lost wakeups), so read
    // the properties directly too; changes are detected against the cache.
    unsafe {
        changed |= poll_mpv_properties(backend);
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
