use std::ptr;

use crate::mpv::*;
use crate::tests::common::with_config_dir;
use tempfile::tempdir;

#[test]
fn null_handle_is_safe() {
    assert_eq!(guinea_mpeg_mpv_process_events(ptr::null_mut()), 0);
    assert_eq!(guinea_mpeg_mpv_position(ptr::null()), 0);
    assert_eq!(guinea_mpeg_mpv_duration(ptr::null()), 0);
    assert!(!guinea_mpeg_mpv_is_playing(ptr::null()));
    assert_eq!(guinea_mpeg_mpv_volume(ptr::null_mut()), 0);
    assert_eq!(guinea_mpeg_mpv_raw_handle(ptr::null_mut()), ptr::null_mut());
    guinea_mpeg_mpv_destroy(ptr::null_mut());
    guinea_mpeg_mpv_load_file(ptr::null_mut(), ptr::null());
    guinea_mpeg_mpv_play(ptr::null_mut());
    guinea_mpeg_mpv_pause(ptr::null_mut());
    guinea_mpeg_mpv_stop(ptr::null_mut());
    guinea_mpeg_mpv_seek(ptr::null_mut(), 100);
    guinea_mpeg_mpv_set_volume(ptr::null_mut(), 50);
}

#[test]
fn mpv_available_with_libmpv() {
    // libmpv is a hard dependency of the crate; a real install must initialize.
    assert!(guinea_mpeg_mpv_available());
}

#[test]
fn mpv_handle_create_and_destroy() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        let handle = guinea_mpeg_mpv_create();
        if handle.is_null() {
            panic!("guinea_mpeg_mpv_create() failed - is libmpv installed?");
        }
        // Fresh idle handle: no media loaded.
        assert_eq!(guinea_mpeg_mpv_position(handle), 0);
        assert_eq!(guinea_mpeg_mpv_duration(handle), 0);
        assert!(!guinea_mpeg_mpv_is_playing(handle));
        // The raw handle is what the C++ renderer turns into a render context.
        assert!(!guinea_mpeg_mpv_raw_handle(handle).is_null());
        // Default preview volume (from options) is applied, then set/clamped.
        assert_eq!(guinea_mpeg_mpv_volume(handle), 100);
        guinea_mpeg_mpv_set_volume(handle, 75);
        assert_eq!(guinea_mpeg_mpv_volume(handle), 75);
        guinea_mpeg_mpv_set_volume(handle, 500);
        assert_eq!(guinea_mpeg_mpv_volume(handle), 100);
        // Playback control is safe on a live handle.
        guinea_mpeg_mpv_pause(handle);
        guinea_mpeg_mpv_seek(handle, 1000);
        guinea_mpeg_mpv_destroy(handle);
    });
}