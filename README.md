# ArkPulse

**ArkPulse** is a high-performance, scifi-industrial music player built with Flutter and Rust. It specializes in integrating remote WebDAV libraries into a seamless, high-fidelity local listening experience.

## 🚀 Project Overview
ArkPulse (codename: *The Pulse*) is designed with a "Bright Orthogonal Industrial" aesthetic. It targets users who manage large remote music collections and want a native-feeling application that bridges the gap between cloud storage and local playback.

- **Frontend**: Flutter (3.2x+)
- **Backend Core**: Rust (via `flutter_rust_bridge`)
- **Audio Engine**: Rodio + Symphonia (Native Rust)
- **Persistence**: SQLite (via `sqflite_common_ffi`)
- **Connectivity**: WebDAV (BFS Recursive Listing)

---

## 🛠 Features & Requirements
### Core Functionality
- **WebDAV Hub**: Add, edit, and persist multiple WebDAV nodes. 
- **Recursive Listing**: High-speed Breadth-First Search (BFS) for audio files across all directory levels.
- **Native Streaming**: Remote files are streamed directly to the native Rust audio engine with temporary file buffering for seek support.
- **Industrial UI**: Strict 90-degree geometry, Neon Lime accents (`#C0FA4D`), and high-contrast scifi panels.

### Interaction Chain
1.  **Config**: `Settings` -> `Add WebDAV` -> Enter credentials (URL, User, Pass, Path).
2.  **Sync**: `Dashboard` -> `Sync Node` -> BFS listing of `.flac`, `.mp3`, `.ogg`, etc.
3.  **Deploy**: `Double Tap Song` -> Rust Backend downloads to temp -> Native Sink play.
4.  **Active**: `Mini Player` / `Player View` -> Full control over playback state.

---

## 🏗 Implementation Path
- **Phase 1: Foundation**: Established the "Neon Industrial" design system and global routing.
- **Phase 2: High-Performance Core**: Built the Rust `WebDavClient` and `AudioPlayer` with FFI bindings.
- **Phase 3: Persistence Layer**: Integrated SQLite to store WebDAV configurations and (coming soon) metadata cache.
- **Phase 4: Integration [Current]**: Recursive listing, remote streaming playback, and config editing.

---

## 📝 TODO List
### Priority: High (Critical Integration)
- [x] **Player UI Fix**: Resolve layout overflow in `PlayerView` and connect to real `AppState` track data.
- [x] **Metadata Scraper**: Implement Rust-side ID3/Vorbis tag extraction using `symphonia`.
- [ ] **Sync State Persistence**: Store listed songs in SQLite to avoid re-scanning on every sync.
- [x] **Lyric Integration**: Wire the lyric scraper to the player view.

### Priority: Medium (UX & Organization)
- [x] **Playlist System**: Create, rename, and manage local playlists referencing WebDAV tracks.
- [ ] **Global Search**: Complete the dashboard search logic to filter across all synced tracks.
- [ ] **Audio Visualizer**: Implement real-time frequency data pass-through from Rust to Flutter.

### Priority: Low (Polish)
- [ ] **Theme Personalization**: High-contrast mode and custom "industrial accent" colors.
- [ ] **System Notifications**: Native OS playback controls integration.

---

## ⚙️ Development Requirements
- **Flutter SDK**: Stable channel.
- **Rust Toolchain**: `latest-stable`.
- **LLVM**: Required for `flutter_rust_bridge` codegen.
- **FFmpeg**: (Optional) for broader codec support if needed beyond Symphonia.

ArkPulse // *The architecture of sound.*
