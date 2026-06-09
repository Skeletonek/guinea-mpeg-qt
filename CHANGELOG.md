### 0.5.0
- Added system notification when transcoding finishes (D-Bus on Linux, native toast on Windows)
- Added auto-pausing preview on entering profile editor or when starting transcode
- Added replaying preview from start on pressing Play when video is seeked to the end of file
- Allowed highlighting ffmpeg logs in transcoding window
- Reworked Profile Editor for visual fidelity
- Changed profile related buttons in main view to one "Profile Editor" button
- Allowed renaming default profiles
- Added option to restore default profiles
- Added option to use VBR (Variable bitrate)
- Added option to encode only audio
- Added option to encode without audio
- Added support for FLAC, MP3, OGG Vorbis audio codecs (only when exporting without video)
- Added preview of the final ffmpeg command
- Added option to use source Pixel format and default Tune
- Added option to specify cpu-used parameter for VP8 and VP9 codecs
- Added confirmation dialog when deleting a profile
- Increased minimum application window size to 1024x768
- Changed pixel format to have predefined options
- Changed preset to have predefined options based on the codec chosen
- Changed default profiles to simplify basic transcoding

### 0.4.1
- Fixed missing ffprobe in Appimage build
- Fixed QT style not using system colors for background
- Fixed missing 'about' icon in Appimage and Windows builds

### 0.4.0
- Added Windows support via MSVC and packaging via InnoSetup
- Added drag & drop support — drop a video file anywhere on the window to load it
- Added file save dialog proposing default filename
- Added app logo to About dialog
- Added minimum window size (700×670)
- Improved support for light themes
- Minor changes for About dialog layout
- Replaced full-width "About" text button with a compact 48×48 icon button (bottom-right)
- Fixed MPV not utilising hardware decoding when available causing choppy playback
- Fixed right panel uneven margins caused by ScrollBar
- Fixed About dialog not centering on open in some QT styles
- Refactored all hardcoded QML colors to theme-aware properties
- Moved mpv handle management, event processing, and all playback commands to Rust
- Moved ffprobe video info, ffmpeg availability check, preview generation, and command building to Rust
- Decrease library size, by removing unnecessary debug info

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
