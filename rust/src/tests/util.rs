use crate::ffmpeg::normalize_path;

#[test]
fn normalize_path_passthrough_on_unix() {
    #[cfg(not(target_os = "windows"))]
    {
        assert_eq!(
            normalize_path("/home/user/video.mp4"),
            "/home/user/video.mp4"
        );
        assert_eq!(normalize_path("relative/file.mp4"), "relative/file.mp4");
        assert_eq!(normalize_path("C:\\videos\\a.mp4"), "C:\\videos\\a.mp4");
    }
}

#[cfg(target_os = "windows")]
#[test]
fn normalize_path_strips_unix_prefix_on_windows() {
    assert_eq!(normalize_path("/C:/videos/a.mp4"), "C:/videos/a.mp4");
    assert_eq!(normalize_path("C:/videos/a.mp4"), "C:/videos/a.mp4");
    assert_eq!(normalize_path("relative/file.mp4"), "relative/file.mp4");
}
