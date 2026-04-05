use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine;
use flutter_rust_bridge::frb;
use lazy_static::lazy_static;
use libloading::Library;
use lofty::config::ParseOptions;
use lofty::file::{AudioFile, TaggedFileExt};
use lofty::prelude::Accessor;
use lofty::probe::Probe;
use lofty::tag::ItemKey;
use reqwest::header::RANGE;
use reqwest::Client;
use std::ffi::{c_char, c_int, c_ulong, c_void, CStr, CString};

use std::path::{Path, PathBuf};
use std::ptr;
use std::sync::Arc;
use tokio::sync::Mutex;

const MPV_FORMAT_FLAG: c_int = 3;
const MPV_FORMAT_DOUBLE: c_int = 5;
const MPV_CLIENT_API_MAJOR: c_ulong = 2;
const MAX_MP4_METADATA_ATOM_BYTES: usize = 8 * 1024 * 1024;

#[repr(C)]
struct MpvHandle {
    _private: [u8; 0],
}

type MpvCreateFn = unsafe extern "C" fn() -> *mut MpvHandle;
type MpvInitializeFn = unsafe extern "C" fn(*mut MpvHandle) -> c_int;
type MpvTerminateDestroyFn = unsafe extern "C" fn(*mut MpvHandle);
type MpvCommandFn = unsafe extern "C" fn(*mut MpvHandle, *mut *const c_char) -> c_int;
type MpvCommandStringFn = unsafe extern "C" fn(*mut MpvHandle, *const c_char) -> c_int;
type MpvSetOptionStringFn =
    unsafe extern "C" fn(*mut MpvHandle, *const c_char, *const c_char) -> c_int;
type MpvSetPropertyFn =
    unsafe extern "C" fn(*mut MpvHandle, *const c_char, c_int, *mut c_void) -> c_int;
type MpvGetPropertyFn =
    unsafe extern "C" fn(*mut MpvHandle, *const c_char, c_int, *mut c_void) -> c_int;
type MpvGetPropertyStringFn = unsafe extern "C" fn(*mut MpvHandle, *const c_char) -> *mut c_char;
type MpvFreeFn = unsafe extern "C" fn(*mut c_void);
type MpvErrorStringFn = unsafe extern "C" fn(c_int) -> *const c_char;
type MpvClientApiVersionFn = unsafe extern "C" fn() -> c_ulong;
const METADATA_HEAD_RANGE: &str = "bytes=0-1048575";
const METADATA_HEAD_LIMIT: usize = 1024 * 1024;

#[frb(opaque)]
pub struct AudioPlayer;

#[derive(Clone, Debug)]
pub enum PlaybackState {
    Stopped,
    Playing,
    Paused,
    Error(String),
}

#[derive(Clone, Debug)]
pub struct TrackInfo {
    pub title: String,
    pub subtitle: String,
    pub artist: String,
    pub album_artist: String,
    pub album: String,
    pub genre: String,
    pub date: String,
    pub track_number: String,
    pub disc_number: String,
    pub lyrics: String,
    pub cover_art: Option<Vec<u8>>,
    pub duration_ms: i64,
}

#[derive(Clone, Debug)]
pub struct PlaybackProgress {
    pub position_ms: i64,
    pub duration_ms: i64,
}

#[derive(Clone, Debug)]
pub struct PlaybackDiagnostics {
    pub path: String,
    pub stream_open_filename: String,
    pub file_error: String,
    pub paused_for_cache: bool,
    pub idle_active: bool,
    pub eof_reached: bool,
    pub duration_ms: i64,
    pub position_ms: i64,
}

lazy_static! {
    static ref GLOBAL_MPV: Arc<Mutex<Option<RuntimeMpv>>> = Arc::new(Mutex::new(None));
    static ref PLAYER_STATE: Arc<Mutex<PlaybackState>> =
        Arc::new(Mutex::new(PlaybackState::Stopped));
    static ref HAS_ACTIVE_PLAYBACK: Arc<Mutex<bool>> = Arc::new(Mutex::new(false));
    static ref PLAYBACK_HTTP_CLIENT: Client = Client::builder()
        .redirect(reqwest::redirect::Policy::limited(10))
        .build()
        .expect("failed to build playback http client");
}

#[derive(Clone, Debug)]
struct RemoteSourceDescriptor {
    url: String,
    username: String,
    token: String,
}

#[derive(Clone, Debug)]
struct ResolvedPlaybackTarget {
    url: String,
    use_auth_header: bool,
}

#[derive(Clone, Debug)]
struct RemoteFetchContext {
    descriptor: RemoteSourceDescriptor,
    resolved: ResolvedPlaybackTarget,
}

#[derive(Clone, Copy, Debug)]
struct Mp4AtomSpan {
    start: u64,
    size: u64,
}

struct RuntimeMpv {
    _library: Library,
    ctx: *mut MpvHandle,
    mpv_terminate_destroy: MpvTerminateDestroyFn,
    mpv_command: MpvCommandFn,
    mpv_command_string: MpvCommandStringFn,
    mpv_set_option_string: MpvSetOptionStringFn,
    mpv_set_property: MpvSetPropertyFn,
    mpv_get_property: MpvGetPropertyFn,
    mpv_get_property_string: MpvGetPropertyStringFn,
    mpv_free: MpvFreeFn,
    mpv_error_string: MpvErrorStringFn,
}

unsafe impl Send for RuntimeMpv {}

impl Drop for RuntimeMpv {
    fn drop(&mut self) {
        if !self.ctx.is_null() {
            unsafe { (self.mpv_terminate_destroy)(self.ctx) };
            self.ctx = ptr::null_mut();
        }
    }
}

impl RuntimeMpv {
    fn new() -> Result<Self, String> {
        let library = load_mpv_library()?;
        let mpv_client_api_version: MpvClientApiVersionFn =
            load_symbol(&library, b"mpv_client_api_version\0")?;
        let api_major = unsafe { mpv_client_api_version() >> 16 };
        if api_major != MPV_CLIENT_API_MAJOR {
            return Err(format!(
                "Unsupported mpv client API major version: {}",
                api_major
            ));
        }

        let mpv_create: MpvCreateFn = load_symbol(&library, b"mpv_create\0")?;
        let mpv_initialize: MpvInitializeFn = load_symbol(&library, b"mpv_initialize\0")?;
        let mpv_terminate_destroy: MpvTerminateDestroyFn =
            load_symbol(&library, b"mpv_terminate_destroy\0")?;
        let mpv_command: MpvCommandFn = load_symbol(&library, b"mpv_command\0")?;
        let mpv_command_string: MpvCommandStringFn =
            load_symbol(&library, b"mpv_command_string\0")?;
        let mpv_set_option_string: MpvSetOptionStringFn =
            load_symbol(&library, b"mpv_set_option_string\0")?;
        let mpv_set_property: MpvSetPropertyFn = load_symbol(&library, b"mpv_set_property\0")?;
        let mpv_get_property: MpvGetPropertyFn = load_symbol(&library, b"mpv_get_property\0")?;
        let mpv_get_property_string: MpvGetPropertyStringFn =
            load_symbol(&library, b"mpv_get_property_string\0")?;
        let mpv_free: MpvFreeFn = load_symbol(&library, b"mpv_free\0")?;
        let mpv_error_string: MpvErrorStringFn = load_symbol(&library, b"mpv_error_string\0")?;

        let ctx = unsafe { mpv_create() };
        if ctx.is_null() {
            return Err("mpv_create returned null".to_string());
        }

        let runtime = Self {
            _library: library,
            ctx,
            mpv_terminate_destroy,
            mpv_command,
            mpv_command_string,
            mpv_set_option_string,
            mpv_set_property,
            mpv_get_property,
            mpv_get_property_string,
            mpv_free,
            mpv_error_string,
        };

        let log_path = std::env::temp_dir().join("arkpulse_mpv.log");
        let log_path_string = log_path.to_string_lossy().replace('\\', "/");
        eprintln!("[mpv] log_file={}", log_path_string);
        let _ = std::fs::remove_file(&log_path);
        runtime.set_option_string("msg-level", "all=v")?;
        runtime.set_option_string("log-file", &log_path_string)?;
        runtime.set_option_string("vid", "no")?;
        runtime.set_option_string("audio-display", "no")?;
        runtime.set_option_string("keep-open", "no")?;
        let _ = runtime.set_option_string("ytdl", "no"); // optional: not all libmpv builds include ytdl
        runtime.set_option_string("cache", "yes")?;
        runtime.set_option_string("cache-on-disk", "yes")?;
        runtime.set_option_string("demuxer-readahead-secs", "4")?;
        runtime.set_option_string("cache-secs", "5")?;
        runtime.set_option_string("demuxer-max-bytes", "16MiB")?;
        runtime.set_option_string("demuxer-max-back-bytes", "4MiB")?;
        runtime.set_option_string("network-timeout", "10")?;

        let init_code = unsafe { mpv_initialize(runtime.ctx) };
        runtime.check_error(init_code, "mpv_initialize")?;
        Ok(runtime)
    }

    fn command(&self, command: &str) -> Result<(), String> {
        let raw = CString::new(command).map_err(|e| format!("Invalid mpv command: {e}"))?;
        let code = unsafe { (self.mpv_command_string)(self.ctx, raw.as_ptr()) };
        self.check_error(code, command)
    }

    fn command_args(&self, args: &[&str]) -> Result<(), String> {
        let raw_args = args
            .iter()
            .map(|arg| CString::new(*arg).map_err(|e| format!("Invalid mpv arg: {e}")))
            .collect::<Result<Vec<_>, _>>()?;
        let mut argv = raw_args
            .iter()
            .map(|arg| arg.as_ptr())
            .collect::<Vec<*const c_char>>();
        argv.push(ptr::null());
        let code = unsafe { (self.mpv_command)(self.ctx, argv.as_mut_ptr()) };
        self.check_error(code, args.first().copied().unwrap_or("mpv_command"))
    }

    fn set_option_string(&self, name: &str, value: &str) -> Result<(), String> {
        let raw_name = CString::new(name).map_err(|e| format!("Invalid option name: {e}"))?;
        let raw_value = CString::new(value).map_err(|e| format!("Invalid option value: {e}"))?;
        let code = unsafe {
            (self.mpv_set_option_string)(self.ctx, raw_name.as_ptr(), raw_value.as_ptr())
        };
        self.check_error(code, name)
    }

    fn set_property_bool(&self, name: &str, value: bool) -> Result<(), String> {
        let raw_name = CString::new(name).map_err(|e| format!("Invalid property name: {e}"))?;
        let mut flag: c_int = if value { 1 } else { 0 };
        let code = unsafe {
            (self.mpv_set_property)(
                self.ctx,
                raw_name.as_ptr(),
                MPV_FORMAT_FLAG,
                (&mut flag as *mut c_int).cast::<c_void>(),
            )
        };
        self.check_error(code, name)
    }

    fn get_property_bool(&self, name: &str) -> Result<bool, String> {
        let raw_name = CString::new(name).map_err(|e| format!("Invalid property name: {e}"))?;
        let mut flag: c_int = 0;
        let code = unsafe {
            (self.mpv_get_property)(
                self.ctx,
                raw_name.as_ptr(),
                MPV_FORMAT_FLAG,
                (&mut flag as *mut c_int).cast::<c_void>(),
            )
        };
        self.check_error(code, name)?;
        Ok(flag != 0)
    }

    fn get_property_f64(&self, name: &str) -> Result<f64, String> {
        let raw_name = CString::new(name).map_err(|e| format!("Invalid property name: {e}"))?;
        let mut value: f64 = 0.0;
        let code = unsafe {
            (self.mpv_get_property)(
                self.ctx,
                raw_name.as_ptr(),
                MPV_FORMAT_DOUBLE,
                (&mut value as *mut f64).cast::<c_void>(),
            )
        };
        self.check_error(code, name)?;
        Ok(value)
    }

    fn get_property_string(&self, name: &str) -> Option<String> {
        let raw_name = CString::new(name).ok()?;
        let value_ptr = unsafe { (self.mpv_get_property_string)(self.ctx, raw_name.as_ptr()) };
        if value_ptr.is_null() {
            return None;
        }
        let value = unsafe { CStr::from_ptr(value_ptr) }
            .to_string_lossy()
            .trim()
            .to_string();
        unsafe { (self.mpv_free)(value_ptr.cast::<c_void>()) };
        if value.is_empty() {
            None
        } else {
            Some(value)
        }
    }

    fn check_error(&self, code: c_int, context: &str) -> Result<(), String> {
        if code >= 0 {
            return Ok(());
        }
        let error_text = unsafe { (self.mpv_error_string)(code) };
        let message = if error_text.is_null() {
            format!("mpv error {}", code)
        } else {
            unsafe { CStr::from_ptr(error_text) }
                .to_string_lossy()
                .into_owned()
        };
        Err(format!("{context}: {message}"))
    }
}

impl AudioPlayer {
    pub fn new() -> Self {
        Self
    }

    pub async fn init_engine() -> Result<(), String> {
        let mut mpv_lock = GLOBAL_MPV.lock().await;
        if mpv_lock.is_none() {
            *mpv_lock = Some(RuntimeMpv::new()?);
        }
        Ok(())
    }

    pub async fn play_local_file(path: String) -> Result<(), String> {
        Self::init_engine().await?;
        let mut mpv_lock = GLOBAL_MPV.lock().await;
        let mpv = mpv_lock
            .as_mut()
            .ok_or_else(|| "mpv backend is not initialized".to_string())?;

        eprintln!("[mpv] play_local_file path={}", path);
        load_file(mpv, &path, None)?;
        mpv.set_property_bool("pause", false)?;
        *HAS_ACTIVE_PLAYBACK.lock().await = true;
        *PLAYER_STATE.lock().await = PlaybackState::Playing;
        Ok(())
    }

    pub async fn play_remote_file(
        url: String,
        username: String,
        token: String,
    ) -> Result<(), String> {
        Self::init_engine().await?;
        let descriptor = RemoteSourceDescriptor {
            url,
            username,
            token,
        };

        let mut mpv_lock = GLOBAL_MPV.lock().await;
        let mpv = mpv_lock
            .as_mut()
            .ok_or_else(|| "mpv backend is not initialized".to_string())?;

        eprintln!("[mpv] play_remote_file url={}", descriptor.url);
        let resolved = resolve_remote_playback_target(&descriptor).await?;
        eprintln!(
            "[mpv] play_remote_file resolved_url={} use_auth_header={}",
            resolved.url, resolved.use_auth_header
        );
        let per_file_options = resolved.use_auth_header.then(|| {
            format!(
                "http-header-fields=Authorization: {}",
                build_basic_auth_header(&descriptor)
            )
        });
        load_file(mpv, &resolved.url, per_file_options.as_deref())?;
        mpv.set_property_bool("pause", false)?;
        *HAS_ACTIVE_PLAYBACK.lock().await = true;
        *PLAYER_STATE.lock().await = PlaybackState::Playing;
        Ok(())
    }

    pub async fn pause() {
        let mut mpv_lock = GLOBAL_MPV.lock().await;
        if let Some(mpv) = mpv_lock.as_mut() {
            let _ = mpv.set_property_bool("pause", true);
            *PLAYER_STATE.lock().await = PlaybackState::Paused;
        }
    }

    pub async fn resume() {
        let mut mpv_lock = GLOBAL_MPV.lock().await;
        if let Some(mpv) = mpv_lock.as_mut() {
            let _ = mpv.set_property_bool("pause", false);
            *PLAYER_STATE.lock().await = PlaybackState::Playing;
        }
    }

    pub async fn stop() {
        let mut mpv_lock = GLOBAL_MPV.lock().await;
        if let Some(mpv) = mpv_lock.as_mut() {
            let _ = mpv.command("stop");
        }
        *HAS_ACTIVE_PLAYBACK.lock().await = false;
        *PLAYER_STATE.lock().await = PlaybackState::Stopped;
    }

    pub async fn get_state() -> PlaybackState {
        let mpv_lock = GLOBAL_MPV.lock().await;
        let mut cached_state = PLAYER_STATE.lock().await;
        let mut has_active_playback = HAS_ACTIVE_PLAYBACK.lock().await;
        let Some(mpv) = mpv_lock.as_ref() else {
            *has_active_playback = false;
            *cached_state = PlaybackState::Stopped;
            return cached_state.clone();
        };

        if !*has_active_playback {
            *cached_state = PlaybackState::Stopped;
            return cached_state.clone();
        }

        let file_error = mpv.get_property_string("file-error").unwrap_or_default();
        if !file_error.is_empty() {
            *has_active_playback = false;
            *cached_state = PlaybackState::Error(file_error);
            return cached_state.clone();
        }

        match mpv.get_property_bool("idle-active") {
            Ok(true) => {
                let position_ms = property_seconds_to_ms(mpv, "time-pos");
                let duration_ms = property_seconds_to_ms(mpv, "duration");
                let eof_reached = mpv.get_property_bool("eof-reached").unwrap_or(false);
                let playback_completed = eof_reached
                    || (duration_ms > 0 && position_ms >= duration_ms.saturating_sub(250));

                if playback_completed {
                    *has_active_playback = false;
                    *cached_state = PlaybackState::Stopped;
                }
            }
            Ok(false) => {
                *cached_state = match mpv.get_property_bool("pause") {
                    Ok(true) => PlaybackState::Paused,
                    Ok(false) => PlaybackState::Playing,
                    Err(error) => PlaybackState::Error(error),
                };
            }
            Err(error) => {
                *cached_state = PlaybackState::Error(error);
            }
        }
        cached_state.clone()
    }

    pub async fn get_progress() -> PlaybackProgress {
        let mpv_lock = GLOBAL_MPV.lock().await;
        let Some(mpv) = mpv_lock.as_ref() else {
            return PlaybackProgress {
                position_ms: 0,
                duration_ms: 0,
            };
        };

        PlaybackProgress {
            position_ms: property_seconds_to_ms(mpv, "time-pos"),
            duration_ms: property_seconds_to_ms(mpv, "duration"),
        }
    }

    pub async fn get_track_info() -> Result<TrackInfo, String> {
        let mpv_lock = GLOBAL_MPV.lock().await;
        let mpv = mpv_lock
            .as_ref()
            .ok_or_else(|| "mpv backend is not initialized".to_string())?;

        Ok(TrackInfo {
            title: first_property_value(
                mpv,
                &[
                    "metadata/by-key/title",
                    "metadata/by-key/TITLE",
                    "metadata/by-key/\u{00A9}nam",
                    "media-title",
                ],
            )
            .unwrap_or_default(),
            subtitle: first_property_value(
                mpv,
                &[
                    "metadata/by-key/subtitle",
                    "metadata/by-key/SUBTITLE",
                    "metadata/by-key/version",
                    "metadata/by-key/VERSION",
                ],
            )
            .unwrap_or_default(),
            artist: first_property_value(
                mpv,
                &[
                    "metadata/by-key/artist",
                    "metadata/by-key/ARTIST",
                    "metadata/by-key/Artist",
                    "metadata/by-key/\u{00A9}ART",
                ],
            )
            .unwrap_or_default(),
            album_artist: first_property_value(
                mpv,
                &[
                    "metadata/by-key/album_artist",
                    "metadata/by-key/ALBUM_ARTIST",
                    "metadata/by-key/Album Artist",
                    "metadata/by-key/aART",
                ],
            )
            .unwrap_or_default(),
            album: first_property_value(
                mpv,
                &[
                    "metadata/by-key/album",
                    "metadata/by-key/ALBUM",
                    "metadata/by-key/Album",
                    "metadata/by-key/\u{00A9}alb",
                ],
            )
            .unwrap_or_default(),
            genre: first_property_value(
                mpv,
                &[
                    "metadata/by-key/genre",
                    "metadata/by-key/GENRE",
                    "metadata/by-key/Genre",
                    "metadata/by-key/\u{00A9}gen",
                ],
            )
            .unwrap_or_default(),
            date: first_property_value(
                mpv,
                &[
                    "metadata/by-key/date",
                    "metadata/by-key/DATE",
                    "metadata/by-key/year",
                    "metadata/by-key/YEAR",
                    "metadata/by-key/\u{00A9}day",
                ],
            )
            .unwrap_or_default(),
            track_number: first_property_value(
                mpv,
                &[
                    "metadata/by-key/track",
                    "metadata/by-key/TRACK",
                    "metadata/by-key/tracknumber",
                    "metadata/by-key/TRACKNUMBER",
                    "metadata/by-key/trkn",
                ],
            )
            .unwrap_or_default(),
            disc_number: first_property_value(
                mpv,
                &[
                    "metadata/by-key/disc",
                    "metadata/by-key/DISC",
                    "metadata/by-key/discnumber",
                    "metadata/by-key/DISCNUMBER",
                    "metadata/by-key/disk",
                ],
            )
            .unwrap_or_default(),
            lyrics: first_property_value(
                mpv,
                &[
                    "metadata/by-key/lyrics",
                    "metadata/by-key/LYRICS",
                    "metadata/by-key/Lyrics",
                    "metadata/by-key/\u{00A9}lyr",
                ],
            )
            .unwrap_or_default(),
            cover_art: None,
            duration_ms: property_seconds_to_ms(mpv, "duration"),
        })
    }

    pub async fn extract_remote_track_info(
        url: String,
        username: String,
        token: String,
    ) -> Result<TrackInfo, String> {
        let descriptor = RemoteSourceDescriptor {
            url,
            username,
            token,
        };
        let temp_path = download_remote_track_to_temp(&descriptor).await?;
        let extracted = extract_track_info_from_path(&temp_path).await;
        let _ = tokio::fs::remove_file(&temp_path).await;
        extracted
    }

    pub async fn get_diagnostics() -> PlaybackDiagnostics {
        let mpv_lock = GLOBAL_MPV.lock().await;
        let Some(mpv) = mpv_lock.as_ref() else {
            return PlaybackDiagnostics {
                path: String::new(),
                stream_open_filename: String::new(),
                file_error: "mpv backend is not initialized".to_string(),
                paused_for_cache: false,
                idle_active: true,
                eof_reached: false,
                duration_ms: 0,
                position_ms: 0,
            };
        };

        PlaybackDiagnostics {
            path: mpv.get_property_string("path").unwrap_or_default(),
            stream_open_filename: mpv
                .get_property_string("stream-open-filename")
                .unwrap_or_default(),
            file_error: mpv.get_property_string("file-error").unwrap_or_default(),
            paused_for_cache: mpv.get_property_bool("paused-for-cache").unwrap_or(false),
            idle_active: mpv.get_property_bool("idle-active").unwrap_or(true),
            eof_reached: mpv.get_property_bool("eof-reached").unwrap_or(false),
            duration_ms: property_seconds_to_ms(mpv, "duration"),
            position_ms: property_seconds_to_ms(mpv, "time-pos"),
        }
    }

    pub async fn seek(position_ms: i64) -> Result<(), String> {
        let mut mpv_lock = GLOBAL_MPV.lock().await;
        let mpv = mpv_lock
            .as_mut()
            .ok_or_else(|| "mpv backend is not initialized".to_string())?;
        let seconds = format!("{:.3}", (position_ms as f64) / 1000.0);
        eprintln!("[mpv] seek target_ms={}", position_ms);
        mpv.command_args(&["seek", &seconds, "absolute", "exact"])
    }
}

fn load_file(mpv: &RuntimeMpv, target: &str, options: Option<&str>) -> Result<(), String> {
    match options {
        Some(options) => mpv.command_args(&["loadfile", target, "replace", options]),
        None => mpv.command_args(&["loadfile", target, "replace"]),
    }
}

fn property_seconds_to_ms(mpv: &RuntimeMpv, property: &str) -> i64 {
    match mpv.get_property_f64(property) {
        Ok(value) if value.is_finite() && value > 0.0 => (value * 1000.0).round() as i64,
        _ => 0,
    }
}

fn first_property_value(mpv: &RuntimeMpv, properties: &[&str]) -> Option<String> {
    for property in properties {
        if let Some(value) = mpv.get_property_string(property) {
            return Some(value);
        }
    }
    None
}

fn build_basic_auth_header(descriptor: &RemoteSourceDescriptor) -> String {
    let credentials = format!("{}:{}", descriptor.username, descriptor.token);
    format!("Basic {}", BASE64_STANDARD.encode(credentials))
}

async fn download_remote_track_to_temp(
    descriptor: &RemoteSourceDescriptor,
) -> Result<PathBuf, String> {
    let context = RemoteFetchContext {
        descriptor: descriptor.clone(),
        resolved: resolve_remote_playback_target(descriptor).await?,
    };
    let head_bytes =
        fetch_remote_range_bytes(&context, METADATA_HEAD_RANGE, METADATA_HEAD_LIMIT).await?;
    let metadata_bytes = if is_mp4_url(&context.resolved.url) {
        build_mp4_metadata_payload(&context, &head_bytes).await?
    } else {
        head_bytes
    };

    let path_only = context
        .resolved
        .url
        .split('?')
        .next()
        .unwrap_or(&context.resolved.url);
    let extension = Path::new(path_only)
        .extension()
        .and_then(|value| value.to_str())
        .filter(|value| !value.is_empty() && value.chars().all(|c| c.is_ascii_alphanumeric()))
        .unwrap_or("audio");
    let temp_path =
        std::env::temp_dir().join(format!("arkpulse-meta-{}.{}", uuid_suffix(), extension));
    let mut file = tokio::fs::File::create(&temp_path)
        .await
        .map_err(|error| format!("Failed to create temp metadata file: {error}"))?;
    tokio::io::AsyncWriteExt::write_all(&mut file, &metadata_bytes)
        .await
        .map_err(|error| format!("Failed to write temp metadata file: {error}"))?;
    Ok(temp_path)
}

async fn extract_track_info_from_path(path: &Path) -> Result<TrackInfo, String> {
    let path = path.to_owned();
    tokio::task::spawn_blocking(move || {
        let raw_bytes = std::fs::read(&path)
            .map_err(|error| format!("Failed to read metadata payload: {error}"))?;
        let mut track_info = match Probe::open(&path).and_then(|probe| {
            probe
                .options(ParseOptions::new().read_properties(false))
                .read()
        }) {
            Ok(tagged_file) => {
                let primary_tag = tagged_file
                    .primary_tag()
                    .or_else(|| tagged_file.first_tag());
                let properties = tagged_file.properties();

                let title = primary_tag
                    .and_then(|tag| tag.title().as_deref().map(str::to_string))
                    .unwrap_or_default();
                let artist = primary_tag
                    .and_then(|tag| tag.artist().as_deref().map(str::to_string))
                    .unwrap_or_default();
                let album = primary_tag
                    .and_then(|tag| tag.album().as_deref().map(str::to_string))
                    .unwrap_or_default();
                let genre = primary_tag
                    .and_then(|tag| tag.genre().as_deref().map(str::to_string))
                    .unwrap_or_default();
                let lyrics = primary_tag
                    .and_then(|tag| item_string(tag, &[ItemKey::Lyrics, ItemKey::Comment]))
                    .or_else(|| mp4_lyrics_fallback(&tagged_file))
                    .unwrap_or_default();
                let cover_art = primary_tag
                    .and_then(|tag| tag.pictures().first().map(|pic| pic.data().to_vec()));

                TrackInfo {
                    title,
                    subtitle: String::new(),
                    artist,
                    album_artist: primary_tag
                        .and_then(|tag| item_string(tag, &[ItemKey::AlbumArtist]))
                        .unwrap_or_default(),
                    album,
                    genre,
                    date: primary_tag
                        .and_then(|tag| item_string(tag, &[ItemKey::RecordingDate, ItemKey::Year]))
                        .unwrap_or_default(),
                    track_number: primary_tag
                        .and_then(|tag| tag.track().map(|value| value.to_string()))
                        .unwrap_or_default(),
                    disc_number: primary_tag
                        .and_then(|tag| tag.disk().map(|value| value.to_string()))
                        .unwrap_or_default(),
                    lyrics,
                    cover_art,
                    duration_ms: properties.duration().as_millis() as i64,
                }
            }
            Err(_) => TrackInfo {
                title: String::new(),
                subtitle: String::new(),
                artist: String::new(),
                album_artist: String::new(),
                album: String::new(),
                genre: String::new(),
                date: String::new(),
                track_number: String::new(),
                disc_number: String::new(),
                lyrics: String::new(),
                cover_art: None,
                duration_ms: 0,
            },
        };

        if is_mp4_url(&path.to_string_lossy()) {
            merge_mp4_atom_metadata(&mut track_info, &raw_bytes);
        }

        if track_info.title.trim().is_empty()
            && track_info.artist.trim().is_empty()
            && track_info.album.trim().is_empty()
            && track_info.album_artist.trim().is_empty()
            && track_info.genre.trim().is_empty()
            && track_info.date.trim().is_empty()
            && track_info.track_number.trim().is_empty()
            && track_info.disc_number.trim().is_empty()
            && track_info.lyrics.trim().is_empty()
            && track_info.cover_art.is_none()
            && track_info.duration_ms == 0
        {
            return Err("No usable metadata was found in the file header payload".to_string());
        }

        Ok(track_info)
    })
    .await
    .map_err(|error| format!("Metadata extraction task failed: {error}"))?
}

fn mp4_lyrics_fallback(tagged_file: &lofty::file::TaggedFile) -> Option<String> {
    let tag = tagged_file
        .primary_tag()
        .or_else(|| tagged_file.first_tag())?;

    for item in tag.items() {
        let key = item.key();
        let text = item.value().text()?;
        if text.trim().is_empty() {
            continue;
        }
        let key_name = format!("{key:?}").to_ascii_lowercase();
        if key_name.contains("lyrics") || key_name.contains("lyr") {
            return Some(text.to_string());
        }
    }

    None
}

fn merge_mp4_atom_metadata(track_info: &mut TrackInfo, bytes: &[u8]) {
    let Some(ilst) = find_atom_in_payload(bytes, b"ilst") else {
        return;
    };

    if track_info.title.trim().is_empty() {
        track_info.title = read_mp4_text_atom(ilst, b"\xa9nam").unwrap_or_default();
    }
    if track_info.artist.trim().is_empty() {
        track_info.artist = read_mp4_text_atom(ilst, b"\xa9ART").unwrap_or_default();
    }
    if track_info.album.trim().is_empty() {
        track_info.album = read_mp4_text_atom(ilst, b"\xa9alb").unwrap_or_default();
    }
    if track_info.album_artist.trim().is_empty() {
        track_info.album_artist = read_mp4_text_atom(ilst, b"aART").unwrap_or_default();
    }
    if track_info.genre.trim().is_empty() {
        track_info.genre = read_mp4_text_atom(ilst, b"\xa9gen").unwrap_or_default();
    }
    if track_info.date.trim().is_empty() {
        track_info.date = read_mp4_text_atom(ilst, b"\xa9day").unwrap_or_default();
    }
    if track_info.lyrics.trim().is_empty() {
        track_info.lyrics = read_mp4_text_atom(ilst, b"\xa9lyr").unwrap_or_default();
    }
    if track_info.track_number.trim().is_empty() {
        track_info.track_number = read_mp4_pair_atom(ilst, b"trkn").unwrap_or_default();
    }
    if track_info.disc_number.trim().is_empty() {
        track_info.disc_number = read_mp4_pair_atom(ilst, b"disk").unwrap_or_default();
    }

    if track_info.cover_art.is_none() {
        if let Some(covr) = find_atom_in_payload(ilst, b"covr") {
            if let Some(data) = find_atom_in_payload(covr, b"data") {
                if data.len() > 16 {
                    track_info.cover_art = Some(data[16..].to_vec());
                }
            }
        }
    }
}

fn find_atom_in_payload<'a>(bytes: &'a [u8], target: &[u8; 4]) -> Option<&'a [u8]> {
    let mut offset = 0usize;
    while offset + 8 <= bytes.len() {
        let (atom_size, header_size) = parse_atom_size(&bytes[offset..])?;
        let end = offset.checked_add(atom_size)?;
        let payload_end = end.min(bytes.len());

        let atom_type: [u8; 4] = bytes[offset + 4..offset + 8].try_into().ok()?;
        if &atom_type == target {
            return Some(&bytes[offset..payload_end]);
        }

        let payload_offset = offset + header_size;
        let children_start = if &atom_type == b"meta" || &atom_type == b"stsd" {
            if &atom_type == b"meta" {
                payload_offset + 4
            } else {
                payload_offset
            }
        } else {
            payload_offset
        };

        if children_start < payload_end {
            if let Some(found) = find_atom_in_payload(&bytes[children_start..payload_end], target) {
                return Some(found);
            }
        }
        offset = end;
    }
    None
}

fn read_mp4_text_atom(ilst: &[u8], atom_type: &[u8; 4]) -> Option<String> {
    let atom = find_child_atom(ilst, atom_type, 8, false)?;
    let data_atom = find_child_atom(atom, b"data", 8, false)?;
    if data_atom.len() <= 16 {
        return None;
    }
    decode_mp4_text(&data_atom[16..])
}

fn read_mp4_pair_atom(ilst: &[u8], atom_type: &[u8; 4]) -> Option<String> {
    let atom = find_child_atom(ilst, atom_type, 8, false)?;
    let data_atom = find_child_atom(atom, b"data", 8, false)?;
    if data_atom.len() < 22 {
        return None;
    }
    let value = u16::from_be_bytes([
        data_atom[data_atom.len() - 4],
        data_atom[data_atom.len() - 3],
    ]);
    if value == 0 {
        return None;
    }
    Some(value.to_string())
}

fn find_child_atom<'a>(
    container: &'a [u8],
    target: &[u8; 4],
    start_offset: usize,
    meta_children: bool,
) -> Option<&'a [u8]> {
    let mut offset = if meta_children {
        start_offset.checked_add(4)?
    } else {
        start_offset
    };
    while offset + 8 <= container.len() {
        let (atom_size, _) = parse_atom_size(&container[offset..])?;
        let end = offset.checked_add(atom_size)?;
        if end > container.len() {
            return None;
        }
        let atom_name: [u8; 4] = container[offset + 4..offset + 8].try_into().ok()?;
        if &atom_name == target {
            return Some(&container[offset..end]);
        }
        offset = end;
    }
    None
}

fn parse_atom_size(bytes: &[u8]) -> Option<(usize, usize)> {
    if bytes.len() < 8 {
        return None;
    }
    let size32 = u32::from_be_bytes(bytes[0..4].try_into().ok()?);
    if size32 == 1 {
        if bytes.len() < 16 {
            return None;
        }
        let size64 = u64::from_be_bytes(bytes[8..16].try_into().ok()?);
        let size = usize::try_from(size64).ok()?;
        if size < 16 {
            return None;
        }
        return Some((size, 16));
    }
    let size = usize::try_from(size32).ok()?;
    if size < 8 {
        return None;
    }
    Some((size, 8))
}

fn decode_mp4_text(bytes: &[u8]) -> Option<String> {
    if bytes.is_empty() {
        return None;
    }
    if bytes.len() >= 2 {
        let bom = &bytes[..2];
        if bom == [0xFE, 0xFF] || bom == [0xFF, 0xFE] {
            let big_endian = bom == [0xFE, 0xFF];
            let mut code_units = Vec::new();
            let mut cursor = 2usize;
            while cursor + 1 < bytes.len() {
                let pair = [bytes[cursor], bytes[cursor + 1]];
                code_units.push(if big_endian {
                    u16::from_be_bytes(pair)
                } else {
                    u16::from_le_bytes(pair)
                });
                cursor += 2;
            }
            return String::from_utf16(&code_units)
                .ok()
                .map(|value| value.trim_end_matches('\0').to_string())
                .filter(|value| !value.trim().is_empty());
        }
    }
    String::from_utf8(bytes.to_vec())
        .ok()
        .map(|value| value.trim_end_matches('\0').to_string())
        .filter(|value| !value.trim().is_empty())
        .or_else(|| {
            Some(
                String::from_utf8_lossy(bytes)
                    .trim_end_matches('\0')
                    .to_string(),
            )
            .filter(|value| !value.trim().is_empty())
        })
}

fn item_string(tag: &lofty::tag::Tag, keys: &[ItemKey]) -> Option<String> {
    for key in keys {
        if let Some(item) = tag.get(key) {
            let text = item.value().text()?;
            if !text.trim().is_empty() {
                return Some(text.to_string());
            }
        }
    }
    None
}

async fn fetch_remote_range_bytes(
    context: &RemoteFetchContext,
    range: &str,
    max_bytes: usize,
) -> Result<Vec<u8>, String> {
    let (requested_start, requested_end) = parse_http_byte_range(range)?;
    let mut request = PLAYBACK_HTTP_CLIENT.get(&context.resolved.url);
    if context.resolved.use_auth_header {
        request = request.basic_auth(
            &context.descriptor.username,
            Some(&context.descriptor.token),
        );
    }
    let response = request
        .header(RANGE, range)
        .send()
        .await
        .map_err(|error| format!("Failed to download metadata range {range}: {error}"))?;

    if !response.status().is_success() && response.status().as_u16() != 206 {
        return Err(format!(
            "Metadata range request failed with status {} for {range}",
            response.status()
        ));
    }

    let status_code = response.status().as_u16();
    let bytes = response
        .bytes()
        .await
        .map_err(|error| format!("Failed to read metadata range {range}: {error}"))?;
    let sliced = if status_code == 206 || requested_start == 0 {
        bytes.to_vec()
    } else {
        let start = usize::try_from(requested_start)
            .map_err(|_| format!("Requested range start is too large: {requested_start}"))?;
        if start >= bytes.len() {
            return Err(format!(
                "Range fallback received only {} bytes, cannot reach offset {}",
                bytes.len(),
                requested_start
            ));
        }
        let requested_len = requested_end
            .checked_sub(requested_start)
            .and_then(|value| value.checked_add(1))
            .and_then(|value| usize::try_from(value).ok())
            .unwrap_or(max_bytes);
        let end = start.saturating_add(requested_len).min(bytes.len());
        bytes[start..end].to_vec()
    };

    if sliced.len() > max_bytes {
        return Ok(sliced[..max_bytes].to_vec());
    }
    Ok(sliced)
}

async fn build_mp4_metadata_payload(
    context: &RemoteFetchContext,
    head_bytes: &[u8],
) -> Result<Vec<u8>, String> {
    let mut offset = 0u64;
    let mut ftyp_span = None;
    let mut moov_span = None;

    loop {
        let (atom_type, atom_size) = if offset + 16 <= head_bytes.len() as u64 {
            let o = offset as usize;
            let size32 = u32::from_be_bytes(head_bytes[o..o + 4].try_into().unwrap());
            let a_type: [u8; 4] = head_bytes[o + 4..o + 8].try_into().unwrap();
            if size32 == 1 {
                let size64 = u64::from_be_bytes(head_bytes[o + 8..o + 16].try_into().unwrap());
                (a_type, size64)
            } else if size32 == 0 {
                break;
            } else {
                (a_type, size32 as u64)
            }
        } else {
            let range = format!("bytes={}-{}", offset, offset + 15);
            let header = fetch_remote_range_bytes(context, &range, 16)
                .await
                .unwrap_or_default();
            if header.len() < 8 {
                break;
            }
            let size32 = u32::from_be_bytes(header[0..4].try_into().unwrap());
            let a_type: [u8; 4] = header[4..8].try_into().unwrap();
            if size32 == 1 {
                if header.len() < 16 {
                    break;
                }
                let size64 = u64::from_be_bytes(header[8..16].try_into().unwrap());
                (a_type, size64)
            } else if size32 == 0 {
                break;
            } else {
                (a_type, size32 as u64)
            }
        };

        let span = Mp4AtomSpan {
            start: offset,
            size: atom_size,
        };
        if &atom_type == b"ftyp" {
            ftyp_span = Some(span);
        } else if &atom_type == b"moov" {
            moov_span = Some(span);
            break; // Stop searching once moov is found
        }

        if atom_size < 8 {
            break;
        }

        let next = offset.checked_add(atom_size);
        if let Some(n) = next {
            offset = n;
        } else {
            break;
        }
    }

    let ftyp =
        ftyp_span.ok_or_else(|| "MP4 header does not contain a readable ftyp atom".to_string())?;
    let moov =
        moov_span.ok_or_else(|| "MP4 header scan did not locate the moov atom".to_string())?;

    let ftyp_end = usize::try_from(ftyp.start + ftyp.size)
        .map_err(|_| "ftyp atom size overflow".to_string())?;

    if ftyp.start > head_bytes.len() as u64 || ftyp_end > head_bytes.len() {
        return Err("ftyp atom extends beyond the fetched MP4 header bytes".to_string());
    }

    let moov_size =
        usize::try_from(moov.size).map_err(|_| "moov atom size overflow".to_string())?;
    if moov_size > MAX_MP4_METADATA_ATOM_BYTES {
        return Err(format!(
            "MP4 moov atom is too large to fetch safely: {} bytes",
            moov.size
        ));
    }

    let mut moov_bytes = if moov.start + moov.size <= head_bytes.len() as u64 {
        head_bytes[moov.start as usize..(moov.start + moov.size) as usize].to_vec()
    } else {
        let range = format!("bytes={}-{}", moov.start, moov.start + moov.size - 1);
        fetch_remote_range_bytes(context, &range, moov_size).await?
    };

    if moov_bytes.len() >= 8 {
        let actual_size = moov_bytes.len() as u32;
        moov_bytes[0..4].copy_from_slice(&actual_size.to_be_bytes());
    }

    let mut payload = Vec::with_capacity(ftyp_end + moov_bytes.len());
    payload.extend_from_slice(&head_bytes[..ftyp_end]);
    payload.extend_from_slice(&moov_bytes);
    Ok(payload)
}

fn is_mp4_url(url: &str) -> bool {
    let path_only = url.split('?').next().unwrap_or(url);
    Path::new(path_only)
        .extension()
        .and_then(|value| value.to_str())
        .map(|value| {
            let lower = value.to_lowercase();
            lower == "mp4" || lower == "m4a" || lower == "m4v"
        })
        .unwrap_or(false)
}

fn parse_http_byte_range(range: &str) -> Result<(u64, u64), String> {
    let raw = range
        .strip_prefix("bytes=")
        .ok_or_else(|| format!("Unsupported HTTP range format: {range}"))?;
    let (start, end) = raw
        .split_once('-')
        .ok_or_else(|| format!("Malformed HTTP range: {range}"))?;
    let start = start
        .parse::<u64>()
        .map_err(|error| format!("Invalid HTTP range start in {range}: {error}"))?;
    let end = end
        .parse::<u64>()
        .map_err(|error| format!("Invalid HTTP range end in {range}: {error}"))?;
    if end < start {
        return Err(format!("HTTP range end precedes start: {range}"));
    }
    Ok((start, end))
}

fn uuid_suffix() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    format!("{}-{}", now.as_secs(), now.subsec_nanos())
}

async fn resolve_remote_playback_target(
    descriptor: &RemoteSourceDescriptor,
) -> Result<ResolvedPlaybackTarget, String> {
    let response = PLAYBACK_HTTP_CLIENT
        .get(&descriptor.url)
        .basic_auth(&descriptor.username, Some(&descriptor.token))
        .header(RANGE, "bytes=0-0")
        .send()
        .await
        .map_err(|error| format!("Failed to resolve playback URL: {error}"))?;

    let status = response.status();
    if !status.is_success() && status.as_u16() != 206 {
        return Err(format!("Playback URL probe failed: {}", status));
    }

    let final_url = response.url().to_string();
    let use_auth_header = same_origin(&descriptor.url) == same_origin(&final_url);
    Ok(ResolvedPlaybackTarget {
        url: final_url,
        use_auth_header,
    })
}

fn same_origin(url: &str) -> Option<(String, String, u16)> {
    let parsed = reqwest::Url::parse(url).ok()?;
    Some((
        parsed.scheme().to_string(),
        parsed.host_str()?.to_string(),
        parsed.port_or_known_default()?,
    ))
}

fn load_mpv_library() -> Result<Library, String> {
    let candidates = library_candidates();
    let mut last_error = None;
    for candidate in &candidates {
        let attempt = unsafe { Library::new(candidate) };
        match attempt {
            Ok(library) => return Ok(library),
            Err(error) => last_error = Some(format!("{}: {}", candidate, error)),
        }
    }
    Err(format!(
        "Unable to load mpv runtime library. Tried: {}. Last error: {}",
        candidates.join(", "),
        last_error.unwrap_or_else(|| "unknown".to_string())
    ))
}

fn library_candidates() -> Vec<String> {
    let names: Vec<&str>;
    #[cfg(target_os = "windows")]
    {
        names = vec!["mpv-2.dll", "libmpv-2.dll", "mpv.dll"];
    }
    #[cfg(target_os = "macos")]
    {
        names = vec!["libmpv.2.dylib", "libmpv.dylib"];
    }
    #[cfg(all(not(target_os = "windows"), not(target_os = "macos")))]
    {
        names = vec!["libmpv.so.2", "libmpv.so"];
    }

    let mut candidates: Vec<String> = Vec::new();

    // Try exe-relative paths first (where media_kit_libs bundles the DLL)
    if let Ok(exe_path) = std::env::current_exe() {
        if let Some(exe_dir) = exe_path.parent() {
            for name in &names {
                let full = exe_dir.join(name);
                candidates.push(full.to_string_lossy().into_owned());
            }
        }
    }

    // Fall back to bare filenames (system PATH / LD_LIBRARY_PATH)
    for name in &names {
        candidates.push(name.to_string());
    }

    candidates
}

fn load_symbol<T: Copy>(library: &Library, name: &[u8]) -> Result<T, String> {
    let symbol = unsafe { library.get::<T>(name) }
        .map_err(|e| format!("Failed to load symbol {}: {}", display_symbol(name), e))?;
    Ok(*symbol)
}

fn display_symbol(name: &[u8]) -> String {
    String::from_utf8_lossy(name)
        .trim_end_matches('\0')
        .to_string()
}
