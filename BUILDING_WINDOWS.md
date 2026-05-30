# Building GuineaMPEG on Windows

## Prerequisites

### 1. Visual Studio 2022

Install Visual Studio 2022 with the **Desktop development with C++** workload.
Make sure the **C++ CMake tools for Windows** component is included.

### 2. Qt 6.5+

Download and install Qt from the [online installer](https://www.qt.io/download-qt-installer).
Required components (for MSVC 2022 x86_64):
- `Qt 6.5+ / Qt 6.5.x / MSVC 2022 64-bit`
- `Qt 6.5+ / Qt Quick`
- `Qt 6.5+ / Qt QuickControls2`

### 3. Rust

Install Rust via [rustup](https://rustup.rs/) using the MSVC toolchain:

```powershell
rustup toolchain install stable-msvc
rustup default stable-msvc
rustup target add x86_64-pc-windows-msvc
```

### 4. CMake & Ninja

```powershell
winget install Kitware.CMake
winget install Ninja-build.Ninja
```

Or install via Chocolatey:

```powershell
choco install cmake ninja
```

### 5. 7-Zip (required by mpv-dev download script)

```powershell
winget install 7zip.7zip
```

### 6. InnoSetup 6 (optional, for creating installer)

Download from [jrsoftware.org](https://jrsoftware.org/isdl.php).

---

## Building

Open **x64 Native Tools Command Prompt for VS 2022** (or any PowerShell where `cl.exe` and `nmake` are available from PATH), then:

```powershell
.\build\windows_build.ps1
```

The script will:
1. Download the mpv-dev bundle from shinchiro's GitHub
2. Build the Rust library with `cargo`
3. Configure and build with CMake + Ninja (MSVC)
4. Run `windeployqt` to collect Qt DLLs
5. Copy `mpv-2.dll` to the output directory
6. Create a portable ZIP archive
7. Build an InnoSetup installer (if ISCC.exe is available)

### Options

| Flag | Description |
|------|-------------|
| `-Config RelWithDebInfo` | Build with debug info |
| `-SkipPackage` | Build only, skip packaging |
| `-SkipMpv` | Skip mpv-dev download (use existing) |
| `-QtDir C:\Qt\6.8.0\msvc2022_64` | Specify Qt path manually |
| `-NoClean` | Rebuild without cleaning |

---

## Output

After a successful build you'll find:

| Artifact | Path |
|----------|------|
| Executable | `out/windows/guinea-mpeg.exe` |
| Portable ZIP | `out/GuineaMPEG-{version}-win64.zip` |
| Installer (exe) | `out/GuineaMPEG-{version}-win64.exe` |

---

## Notes

- The Rust `cdylib` target produces `guinea_mpeg_core.dll` on Windows
- The mpv-dev bundle is cached in `build/windows/.mpv-dev/` after first download
- Deleting `out/windows` and rebuilding is the recommended way to get a clean build
- File associations (.mp4, .mkv, .webm, .avi, .mov) are registered by the installer
