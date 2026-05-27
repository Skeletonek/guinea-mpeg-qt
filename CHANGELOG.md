### 0.2.1
- Added option to load file from argument
- Fixed flatpak having no audio on preview
- Fixed flatpak having no profiles by default

### 0.2.0
- Change QtMultimedia preview to libmpv one
- Added new profile editor
- Improved config file handling
- Added option to create new profiles
- Added option to delete profile
- Added option to cancel transcoding
- Added option to re-open transcoding popup
- Added new settings for profiles: Resolution and framerate
- Fixed transcoding popup preventing scrolling
- Hardcoded containers for specific codecs (f.e. .mp4 is only used for h264)
- Hardcoded support for specific codecs, for now: h264, av1-svt, vp8, vp9
- Removed additional close buttons from transcoding popup
- Prepared packaging system for linux distributions (debian, ubuntu, fedora, arch)
- Added flatpak support

### 0.1.0
- Initial prototype of the app using QML C++, and Rust library
- QtMultimedia preview
- FFMPEG transcoding
- Simple editor profile
- Timeline selection
