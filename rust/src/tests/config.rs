use tempfile::tempdir;

use crate::config::*;
use crate::tests::common::{with_config_dir, write_default_profiles, DEFAULT_PROFILES_TOML};

fn write_temp(content: &str) -> (tempfile::TempDir, std::path::PathBuf) {
    let dir = tempdir().unwrap();
    let path = dir.path().join("config.toml");
    std::fs::write(&path, content).unwrap();
    (dir, path)
}

#[test]
fn parses_canonical_profiles_table() {
    let (_dir, path) = write_temp(
        r#"
        [[profiles]]
        name = "Test"
        codec = "h264"
        crf = 18
        "#,
    );
    let cfg = load_config_from_file(&path);
    assert_eq!(cfg.profiles.len(), 1);
    let p = &cfg.profiles[0];
    assert_eq!(p.name, "Test");
    assert_eq!(p.codec, "h264");
    assert_eq!(p.crf, Some(18));
    assert_eq!(p.audio_bitrate, "128k");
    assert_eq!(p.video_enabled, None);
}

#[test]
fn parses_legacy_map_format() {
    // Legacy [profiles."name"] map: profiles parse, but map keys are not
    // propagated to profile names (legacy support is slated for removal).
    let (_dir, path) = write_temp(
        r#"
        [profiles."Legacy"]
        codec = "vp9"
        crf = 40
        "#,
    );
    let cfg = load_config_from_file(&path);
    assert_eq!(cfg.profiles.len(), 1);
    assert_eq!(cfg.profiles[0].codec, "vp9");
    assert_eq!(cfg.profiles[0].crf, Some(40));
    assert_eq!(cfg.options.language, "system");
}

#[test]
fn migrates_svtav1_codec_key() {
    let (_dir, path) = write_temp(
        r#"
        [[profiles]]
        name = "Old"
        codec = "svtav1"
        "#,
    );
    let cfg = load_config_from_file(&path);
    assert_eq!(cfg.profiles[0].codec, "av1");
}

#[test]
fn garbage_toml_returns_default_config() {
    let (_dir, path) = write_temp("this is not toml [[[");
    let cfg = load_config_from_file(&path);
    assert!(cfg.profiles.is_empty());
    assert_eq!(cfg.options.theme, "system");
}

#[test]
fn options_defaults_when_absent() {
    let (_dir, path) = write_temp(
        r#"
        [[profiles]]
        name = "X"
        codec = "h264"
        "#,
    );
    let cfg = load_config_from_file(&path);
    assert_eq!(cfg.options.language, "system");
    assert_eq!(cfg.options.theme, "system");
    assert_eq!(cfg.options.color_scheme, "system");
    assert_eq!(cfg.options.hwdec, "auto-copy");
    assert_eq!(cfg.options.preview_volume, 100.0);
    assert_eq!(cfg.options.preview_duration, 5.0);
    assert!(cfg.options.check_for_updates);
}

#[test]
fn set_option_preview_volume_clamped() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        assert!(set_option("previewVolume", "150").is_ok());
        assert_eq!(get_options().preview_volume, 100.0);
        assert!(set_option("previewVolume", "-5").is_ok());
        assert_eq!(get_options().preview_volume, 0.0);
        assert!(set_option("previewVolume", "42.5").is_ok());
        assert_eq!(get_options().preview_volume, 42.5);
    });
}

#[test]
fn set_option_preview_duration_clamped() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        assert!(set_option("previewDuration", "120").is_ok());
        assert_eq!(get_options().preview_duration, 60.0);
        assert!(set_option("previewDuration", "0").is_ok());
        assert_eq!(get_options().preview_duration, 1.0);
        assert!(set_option("previewDuration", "7.5").is_ok());
        assert_eq!(get_options().preview_duration, 7.5);
    });
}

#[test]
fn set_option_validates_values() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        assert!(set_option("previewVolume", "abc").is_err());
        assert!(set_option("previewDuration", "abc").is_err());
        assert!(set_option("checkForUpdates", "notabool").is_err());
        assert!(set_option("autoplayOnLoad", "notabool").is_err());
        assert!(set_option("unknownKey", "x").is_err());
    });
}

#[test]
fn set_option_roundtrip() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        set_option("language", "pl").unwrap();
        set_option("theme", "dark").unwrap();
        set_option("colorScheme", "dark").unwrap();
        set_option("hwdec", "vaapi").unwrap();
        set_option("checkForUpdates", "false").unwrap();
        set_option("autoplayOnLoad", "false").unwrap();
        let opts = get_options();
        assert_eq!(opts.language, "pl");
        assert_eq!(opts.theme, "dark");
        assert_eq!(opts.color_scheme, "dark");
        assert_eq!(opts.hwdec, "vaapi");
        assert!(!opts.check_for_updates);
        assert!(!opts.autoplay_on_load);
        set_option("autoplayOnLoad", "true").unwrap();
        assert!(get_options().autoplay_on_load);
    });
}

#[test]
fn save_then_load_profile_roundtrip() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        let json = r#"{"name":"ignored","codec":"h264","crf":23,"preset":"fast"}"#;
        assert!(save_profile("My Profile", json).is_ok());
        let loaded = load_profile("My Profile").unwrap();
        assert_eq!(loaded.codec, "h264");
        assert_eq!(loaded.crf, Some(23));
        assert_eq!(loaded.preset, Some("fast".to_string()));
        assert_eq!(loaded.name, "My Profile");
        assert!(user_profile_names().contains(&"My Profile".to_string()));
    });
}

#[test]
fn custom_command_survives_save_load_roundtrip() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        let json = r#"{"codec":"h264","custom_command":"-i {input} -c:v libx264 -y {output}"}"#;
        assert!(save_profile("Advanced", json).is_ok());
        let loaded = load_profile("Advanced").unwrap();
        assert_eq!(
            loaded.custom_command.as_deref(),
            Some("-i {input} -c:v libx264 -y {output}")
        );
        assert_eq!(loaded.codec, "h264");
    });
}

#[test]
fn overwrite_existing_profile_updates() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        save_profile("P", r#"{"codec":"h264","crf":20}"#).unwrap();
        save_profile("P", r#"{"codec":"hevc","crf":30}"#).unwrap();
        let loaded = load_profile("P").unwrap();
        assert_eq!(loaded.codec, "hevc");
        assert_eq!(loaded.crf, Some(30));
        assert_eq!(user_profile_names().len(), 1);
    });
}

#[test]
fn delete_profile_removes() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        save_profile("P", r#"{"codec":"h264"}"#).unwrap();
        assert!(load_profile("P").is_some());
        delete_profile("P").unwrap();
        assert!(load_profile("P").is_none());
        assert!(user_profile_names().is_empty());
    });
}

#[test]
fn save_profile_empty_name_is_stored() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        // Name validation lives in the QML layer; the Rust core accepts
        // whatever name it is given without crashing.
        assert!(save_profile("", r#"{"codec":"h264","crf":18}"#).is_ok());
        assert!(load_profile("").is_some());
        assert!(user_profile_names().contains(&"".to_string()));
    });
}

#[test]
fn save_profile_invalid_json_rejected() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        assert!(save_profile("P", "not json").is_err());
        assert!(load_profile("P").is_none());
        assert!(user_profile_names().is_empty());
    });
}

#[test]
fn merge_configs_user_overrides_default() {
    with_config_dir(tempdir().unwrap().path(), |dir| {
        write_default_profiles(dir, DEFAULT_PROFILES_TOML);
        // Overriding a default profile by name overlays it: the merged list
        // must contain exactly one entry for that name.
        save_profile("H.264 High", r#"{"codec":"h264","crf":30}"#).unwrap();
        let cfg = merge_configs();
        let h264: Vec<_> = cfg
            .profiles
            .iter()
            .filter(|p| p.name == "H.264 High")
            .collect();
        assert_eq!(h264.len(), 1);
        assert_eq!(h264[0].crf, Some(30));
        // defaults merged in too
        assert!(cfg.profiles.iter().any(|p| p.name == "VP9 Low"));
    });
}

#[test]
fn user_profile_names_excludes_defaults() {
    with_config_dir(tempdir().unwrap().path(), |dir| {
        write_default_profiles(dir, DEFAULT_PROFILES_TOML);
        assert!(user_profile_names().is_empty());
        save_profile("Mine", r#"{"codec":"h264"}"#).unwrap();
        assert_eq!(user_profile_names(), vec!["Mine".to_string()]);
    });
}

#[test]
fn default_profile_names_from_fixture() {
    with_config_dir(tempdir().unwrap().path(), |dir| {
        write_default_profiles(dir, DEFAULT_PROFILES_TOML);
        let names = default_profile_names();
        assert_eq!(names, vec!["H.264 High".to_string(), "VP9 Low".to_string()]);
    });
}

#[test]
fn restore_defaults_reverts_overrides_keeps_custom() {
    with_config_dir(tempdir().unwrap().path(), |dir| {
        write_default_profiles(dir, DEFAULT_PROFILES_TOML);
        save_profile("H.264 High", r#"{"codec":"h264","crf":50}"#).unwrap();
        save_profile("Custom", r#"{"codec":"vp9","crf":10}"#).unwrap();
        assert_eq!(load_profile("H.264 High").unwrap().crf, Some(50));

        restore_defaults().unwrap();

        assert_eq!(load_profile("H.264 High").unwrap().crf, Some(18));
        assert!(load_profile("Custom").is_some());
    });
}

#[test]
fn category_survives_save_load() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        let json = r#"{"codec":"h264","category":"Web & streaming"}"#;
        assert!(save_profile("Categorized", json).is_ok());
        let loaded = load_profile("Categorized").unwrap();
        assert_eq!(loaded.category.as_deref(), Some("Web & streaming"));
    });
}

#[test]
fn profile_groups_order_and_custom_fallback() {
    with_config_dir(tempdir().unwrap().path(), |dir| {
        write_default_profiles(
            dir,
            r#"
        [[profiles]]
        name = "B"
        codec = "h264"
        category = "General"

        [[profiles]]
        name = "A"
        codec = "vp9"
        category = "Compact"

        [[profiles]]
        name = "C"
        codec = "vp9"
        category = "General"

        [[profiles]]
        name = "Uncategorized"
        codec = "gif"
        "#,
        );
        set_config(merge_configs());
        save_profile("Mine", r#"{"codec":"h264","category":"General"}"#).unwrap();
        save_profile("UserOnly", r#"{"codec":"h264","category":"OnlyUser"}"#).unwrap();
        save_profile("Raw", r#"{"codec":"h264"}"#).unwrap();

        let groups = profile_groups();
        let categories: Vec<&str> = groups.iter().map(|g| g.category.as_str()).collect();
        assert_eq!(categories, vec!["General", "Compact", "OnlyUser", "Custom"]);
        assert_eq!(
            groups[0].names,
            vec!["B".to_string(), "C".to_string(), "Mine".to_string()]
        );
        assert_eq!(groups[1].names, vec!["A".to_string()]);
        assert_eq!(groups[2].names, vec!["UserOnly".to_string()]);
        assert_eq!(
            groups[3].names,
            vec!["Raw".to_string(), "Uncategorized".to_string()]
        );
    });
}

#[test]
fn profile_groups_no_uncategorized_group_when_empty() {
    with_config_dir(tempdir().unwrap().path(), |dir| {
        write_default_profiles(
            dir,
            r#"
        [[profiles]]
        name = "A"
        codec = "h264"
        category = "General"
        "#,
        );
        set_config(merge_configs());
        let groups = profile_groups();
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].category, "General");
        assert_eq!(groups[0].names, vec!["A".to_string()]);
    });
}

#[test]
fn export_import_preserves_category() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        save_profile("Cat", r#"{"codec":"h264","category":"Compact"}"#).unwrap();
        save_profile("NoCat", r#"{"codec":"h264"}"#).unwrap();

        let export_path =
            std::env::temp_dir().join(format!("guinea_cat_{}.toml", std::process::id()));
        export_profiles(
            export_path.to_str().unwrap(),
            &["Cat".to_string(), "NoCat".to_string()],
        )
        .unwrap();

        delete_profile("Cat").unwrap();
        delete_profile("NoCat").unwrap();

        let summary = import_profiles(export_path.to_str().unwrap(), false);
        assert!(summary.error.is_none());
        assert_eq!(
            load_profile("Cat").unwrap().category.as_deref(),
            Some("Compact")
        );
        assert_eq!(load_profile("NoCat").unwrap().category, None);
        std::fs::remove_file(&export_path).ok();
    });
}

#[test]
fn export_then_import_roundtrip() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        save_profile("A", r#"{"codec":"h264","crf":18}"#).unwrap();
        save_profile("B", r#"{"codec":"av1","crf":35}"#).unwrap();

        let export_path =
            std::env::temp_dir().join(format!("guinea_export_{}.toml", std::process::id()));
        export_profiles(
            export_path.to_str().unwrap(),
            &["A".to_string(), "B".to_string()],
        )
        .unwrap();

        delete_profile("A").unwrap();
        delete_profile("B").unwrap();
        assert!(load_profile("A").is_none());

        let summary = import_profiles(export_path.to_str().unwrap(), false);
        assert!(summary.error.is_none());
        assert_eq!(summary.imported.len(), 2);
        assert!(summary.imported.contains(&"A".to_string()));
        assert!(summary.imported.contains(&"B".to_string()));
        assert_eq!(load_profile("A").unwrap().codec, "h264");
        std::fs::remove_file(&export_path).ok();
    });
}

#[test]
fn import_conflicts_detected() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        save_profile("Existing", r#"{"codec":"h264","crf":18}"#).unwrap();
        let import_path =
            std::env::temp_dir().join(format!("guinea_import_{}.toml", std::process::id()));
        export_profiles(import_path.to_str().unwrap(), &["Existing".to_string()]).unwrap();

        let preview = import_profiles_preview(import_path.to_str().unwrap());
        assert!(preview.error.is_none());
        assert!(preview.conflicts.contains(&"Existing".to_string()));

        let summary = import_profiles(import_path.to_str().unwrap(), false);
        assert!(summary.skipped.contains(&"Existing".to_string()));

        let summary = import_profiles(import_path.to_str().unwrap(), true);
        assert!(summary.overwritten.contains(&"Existing".to_string()));
        std::fs::remove_file(&import_path).ok();
    });
}

#[test]
fn import_invalid_file_errors() {
    with_config_dir(tempdir().unwrap().path(), |_dir| {
        let bad = std::env::temp_dir().join(format!("guinea_bad_{}.toml", std::process::id()));
        std::fs::write(&bad, "not a toml [[[ [").unwrap();

        let preview = import_profiles_preview(bad.to_str().unwrap());
        assert!(preview.error.is_some());

        let summary = import_profiles(bad.to_str().unwrap(), false);
        assert!(summary.error.is_some());
        std::fs::remove_file(&bad).ok();

        // Valid TOML without any profiles must also be rejected, not silently imported as nothing
        let empty = std::env::temp_dir().join(format!("guinea_empty_{}.toml", std::process::id()));
        std::fs::write(&empty, "title = \"no profiles here\"").unwrap();

        let preview = import_profiles_preview(empty.to_str().unwrap());
        assert!(preview.error.is_some());

        let summary = import_profiles(empty.to_str().unwrap(), false);
        assert!(summary.error.is_some());
        std::fs::remove_file(&empty).ok();
    });
}

#[test]
fn shipped_defaults_use_expected_names() {
    // The picker groups by these names; renames are user-facing, so pin them
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../default_profiles.toml");
    let cfg = load_config_from_file(&root);

    for name in [
        "H.264 High 1080p",
        "H.265 High 1080p",
        "VP9 High",
        "AV1 High",
        "H.265 Medium 720p",
        "AV1 Medium 720p",
        "VP9 Medium 720p",
        "H.264 Medium 1080p30",
        "VP9 Low 720p30",
        "AV1 Low 720p30",
        "H.265 Low 720p30",
        "VP9 Fast 720p30",
        "AAC 256k",
        "Opus 128k",
        "FLAC",
        "WAV",
    ] {
        assert!(
            cfg.profiles.iter().any(|p| p.name == name),
            "missing default profile: {name}"
        );
    }
}

#[test]
fn shipped_opus_profile_is_vbr() {
    // VBR with a 128k target is how libopus is meant to run
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../default_profiles.toml");
    let cfg = load_config_from_file(&root);
    let opus = cfg
        .profiles
        .iter()
        .find(|p| p.name == "Opus 128k")
        .expect("Opus 128k default profile");
    assert_eq!(
        opus.audio_filters
            .as_ref()
            .and_then(|f| f.rate_control.as_deref()),
        Some("vbr")
    );
}
