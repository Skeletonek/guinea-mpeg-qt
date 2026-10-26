#[cfg(target_os = "windows")]
use crate::ffmpeg::normalize_path;

#[cfg(target_os = "windows")]
#[test]
fn normalize_path_strips_unix_prefix_on_windows() {
    assert_eq!(normalize_path("/C:/videos/a.mp4"), "C:/videos/a.mp4");
    assert_eq!(normalize_path("C:/videos/a.mp4"), "C:/videos/a.mp4");
    assert_eq!(normalize_path("relative/file.mp4"), "relative/file.mp4");
}
