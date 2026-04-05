# ArkPulse

**ArkPulse** is a high-performance, scifi-industrial music player built with Flutter and Rust. It specializes in integrating remote WebDAV libraries into a seamless, high-fidelity local listening experience.

## 📖 Introduction
ArkPulse (codename: *The Pulse*) is designed with a "Flat Industrial" Neo-Brutalist aesthetic. It targets users who manage large remote music collections and want a native-feeling application that bridges the gap between cloud storage and local playback.

- **Frontend**: Flutter (3.2x+)
- **Backend Core**: Rust (via `flutter_rust_bridge`)
- **Audio Engine**: libmpv runtime backend (Native Rust)
- **Persistence**: SQLite (via `sqflite_common_ffi`)
- **Connectivity**: WebDAV (BFS Recursive Listing)

---

## 📝 TODO Checklist

### Core Playback & Metadata
- [x] **WebDAV Mounts**: Support for adding, editing, and persisting multiple WebDAV node profiles.
- [x] **Remote Streaming Playback**: Native stream fetching and high-performance caching via Rust `libmpv`.
- [x] **Remote Metadata Extraction**: Highly efficient retrieval of ID3/MP4/Vorbis tags and covert art using `lofty` and HTTP chunk range requests without fetching the full files.
- [x] **Lyric Integration**: Embedded/external synchronized lyric scrolling tightly bound to the player view timeline.

### UI & User Experience
- [x] **Virtual Playlists System**: Support for creating, maintaining, and deleting local virtual playlists mapping to remote WebDAV files.
- [x] **Neo-Brutalism Interface**: Strict flat sci-fi industrial aesthetic with mechanical interactions, responsive hover states, and dynamic glow matrices.
- [x] **State Persistence & Caching**: Cache traversed file trees in SQLite to avoid recurring full sweeps upon restart.
- [x] **Global Deep Search**: Multi-threaded fuzzy filtering across the entire synced WebDAV dashboard grid.

---

## ⚙️ Build Instructions

### Core Requirements
- **Flutter SDK**: Stable channel is recommended.
- **Rust Toolchain**: `latest-stable` branch.
- **LLVM**: Required by `flutter_rust_bridge` to execute underlying FFI C-binding code generation.
- **mpv Runtime**: The native engine required at runtime. Ensure the compiled executable is bundled with the target OS library for production:
  - Windows: `mpv-2.dll` / `libmpv-2.dll` / `mpv.dll`
  - macOS: `libmpv.2.dylib` / `libmpv.dylib`
  - Linux: `libmpv.so.2` / `libmpv.so`

### Windows Build Specifics
Before executing `flutter build windows` or initiating a local Windows debug session, it is strongly advised to configure one of the following Environment Variables. Our CMake build phase extracts this variable and copies the DLL dynamically to the execution folder:

- `MPV_DLL_PATH`
  - Points to the **exact absolute path** of the required library file (e.g. `mpv-2.dll`).
- `MPV_RUNTIME_DIR`
  - Points to the **parent folder absolute path** containing the required dynamic linked libraries.

ArkPulse // *The architecture of sound.*
