### 0.11.0 (In progress)
- Added advanced mode for ProfileEditor allowing to freely edit ffmpeg command
- Added container option in ProfileEditor
- Allow resizing and collapsing the controls panel in main view
- Allow clicking on preview to play / pause the preview
- Added additional metadata such as file version and copyright to the Windows binary
- Added additional metadata such as file version and copyright to the Windows installer file
- Fixed Windows aarch64 build process
- Additional codebase cleanups

### 0.10.1
- Fixed preview controls not working on Windows
- Fixed profile exporting not working in Profile Editor on Windows
- Fixed encoder settings comboboxes in profile editor being set incorrectly after changing profile with different encoder
- Major codebase cleanup

### 0.10.0
- Added aarch64 (ARM64) CPU architecture support
- Added ARM64 .deb, .rpm and .flatpak build support for CI/CD
- Added transcoding queue
- Added confirmation dialog when transcoding would overwrite existing file
- Timeline control handles are now focusable
- Timeline control handles accept left/right arrow, and h/l keypresses for more granular control
- Improved visibility of a text popup in Profile Editor
- Standardized pop-up's
- Swapped "Copy" and "Ok" buttons in about dialog
- Added confirmation dialog when pressing "Copy" button in about dialog
- Unified margins, paddings and spacings across the entire app
- Fixed encoder compatibility dialog rendering at the bottom on first launch in some Qt Quick Styles such as Fusion
- Updated translations

### 0.9.0
- Added option to import and export profiles
- Bundled debian version of ffmpeg in Appimage
- Bundled full ffmpeg version for Windows
- Decreased size of Appimage build by about 30%
- Decreased size of Windows build by about 25%
- Appimage version now tries to use system filepicker using XDG portal
- Right section of top row in Profile Editor now moves if there isn't enough space
- Moved info label in Profile Editor to the top right corner of the window
- Fixed AV1 profiles not working in Appimage
- Fixed AV1 profiles not working on Windows
- Fixed missing app icon in titlebar on Windows
- Improved Windows build system

### 0.8.1
- Fixed system color theme on Linux
- Fixed incorrect file handling with filenames containing '\[' and '\]'
- Fixed Video Information not expanding on bigger file names
- Update missing translations

### 0.8.0
- Added support for GIF output format
- Added support for animated WebP output format
- Added QtQuickControls style change
- Added updated checker
- Added copy button in AboutDialog for bug reporting
- Added additional information for development builds
- Fixed audio streams name not being captured properly
- Fixed system name being "KDE Flatpak Runtime" in Flatpak version, instead of real system name
- Fixed elements overlapping labels in some languages
- Fixed not being able to set custom FPS values
- Fixed source fps settings showing up as "0" in FPS combobox
- Fixed debug build on Windows
- Fixed transcoding notification not working on Windows
- Fixed color themes not working properly on Windows
- Bump CXX standard to C++20
- Cleaned up C++ codebase
- Updated translations

### 0.7.0
- Added support for translations based on system locale
- Added Polish language
- Added German language
- Added Russian language
- Added French language
- Added Italian language
- Added Spanish language
- Added Czech language
- Added Silesian language
- Added options panel
- Added switching application theme
- Added progress bar to transcoding dialog
- Added option to change MPV hardware acceleration settings
- Added remembering preview volume settings
- Added qt, mpv, ffmpeg version info to about app dialog
- Added author logo to about app
- Author label is clickable and opens author's website

### 0.6.2
- Added Compression Level option for VA-API based encoders
- Fix hardware encoding not working due to incorrect parameters
- Removed Apple Video Toolbox and Linux Video4Linux2 Memory-to-Memory encoders
- Temporarily disabled Vulkan-based encoders
- Cleaned up QML codebase

### 0.6.1
- Fixed wrong encoder being set up when loading Profile Editor
- Fixed AV1 still being named SVT-AV1, despite adding support for other encoders
- Fixed ffmpeg preview showing incorrect information
- Fixed encoder compatibility dialog not being centered in some QT styles
- Fixed incorrect project URL for Windows (Installer)
- Cleaned up codebase

### 0.6.0
- Added support for H.265 / HEVC codec
- Added support for hardware encoding (NVENC, VA-API, QSV, AMF) for H.264, H.265 and AV1
- Added compatibility table to profile editor to show what is supported by ffmpeg
- Added audio and video stream selector when the input file has more than one
- Added option to open known audio formats
- Added framerate to Video Information section
- Updated default profiles
- Fixed flatpak package showing up as generic
- Fixed wrong container format for only audio exports
- Fixed using the old container format for updated profile
- Fixed wrong audio codec showing up in preview for audio only exports
- Fixed tune setting not working for H.264, VP8 and VP9
- Fixed settings not updating instantly when manually entering values
- Fixed resolution updating preview with the previous value instead of the current one
- Fixed profile editor using first profile on launch instead of the selected one in main view
- Fixed Video Information text rendering outside visible area if filename is very long

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
