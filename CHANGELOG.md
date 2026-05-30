### 0.4.0
- Added Windows support via MSVC
- Added Windows install bundle from InnoSetup
- Added better support for light themes
- Fixed About dialog centering on open in some QT styles
- Refactored all hardcoded QML colors to theme-aware properties

### 0.3.0
- AppImage support with Docker-based builds
- GitLab CI pipeline for automated releases
- Refactored QML layout code; cleaner separation of UI components
- Dropped menubar; added "Open Video..." and "About GuineaMPEG" buttons to right panel
- Volume controls moved from right panel into video preview overlay
- Added version, author, license, distro, package target, build date and copyright to About dialog
- Added PACKAGE_TARGET CMake define for per-distro package builds
- Replaced VP8 Web profile with VP9 720p Web
- Improved VP9 profiles with VMAF perceptual quality tuning
- Fixed AV1 720p Fast preset speed and quality tuning; renamed to AV1 720p
- Fixed timeline handle bounds and track width issues
- Fixed titlebar missing close button on some styles
- Fixed Flatpak and AppImage packaging
- Added filename and audio codec to video info display
- Bumped audio bitrate to 192k for 1080p profiles
- Updated SVG icon, cleaned up dead code

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
