use flutter_rust_bridge::frb;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::fs::File;
use std::io::{BufReader, Write};
use std::time::Duration;
use rodio::{OutputStream, Sink, Decoder, Source};
use tokio::sync::Mutex;
use lazy_static::lazy_static;
use reqwest::Client;

#[frb(opaque)]
pub struct AudioPlayer {
    current_state: PlaybackState,
}

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
    pub artist: String,
    pub album: String,
    pub duration_ms: u64,
}

#[derive(Clone, Debug)]
pub struct PlaybackProgress {
    pub position_ms: u64,
    pub duration_ms: u64,
}

lazy_static! {
    // Sink is Send, so we can store it in a Tokio Mutex perfectly
    static ref GLOBAL_SINK: Arc<Mutex<Option<Sink>>> = Arc::new(Mutex::new(None));
    static ref PLAYER_STATE: Arc<Mutex<PlaybackState>> = Arc::new(Mutex::new(PlaybackState::Stopped));
    static ref HTTP_CLIENT: Client = Client::new();
    static ref PLAY_REQUEST_ID: AtomicU64 = AtomicU64::new(0);
    static ref TRACK_DURATION_MS: Arc<Mutex<u64>> = Arc::new(Mutex::new(0));
    static ref CURRENT_SOURCE_PATH: Arc<Mutex<Option<String>>> = Arc::new(Mutex::new(None));
    static ref PLAYBACK_OFFSET_MS: Arc<Mutex<u64>> = Arc::new(Mutex::new(0));
}

impl AudioPlayer {
    pub fn new() -> Self {
        Self {
            current_state: PlaybackState::Stopped,
        }
    }

    /// Initializes the audio engine permanently in a background thread
    pub async fn init_engine() {
        let mut sink_lock = GLOBAL_SINK.lock().await;
        if sink_lock.is_none() {
            // Spawn a dedicated native thread to keep OutputStream alive forever
            let (tx, rx) = std::sync::mpsc::channel();
            std::thread::spawn(move || {
                match OutputStream::try_default() {
                    Ok((_stream, handle)) => {
                        if let Ok(sink) = Sink::try_new(&handle) {
                            let _ = tx.send(Some(sink));
                            // Block forever to keep _stream alive
                            loop {
                                std::thread::park();
                            }
                        } else {
                            let _ = tx.send(None);
                        }
                    }
                    Err(_) => {
                        let _ = tx.send(None);
                    }
                }
            });

            // Wait for thread to initialize Sink
            if let Ok(Some(sink)) = rx.recv() {
                *sink_lock = Some(sink);
            }
        }
    }

    /// Plays a local file
    pub async fn play_local_file(path: String) -> Result<(), String> {
        Self::init_engine().await;

        let sink_lock = GLOBAL_SINK.lock().await;
        if let Some(sink) = &*sink_lock {
            let file = File::open(&path).map_err(|e| format!("Failed to open file: {}", e))?;
            let reader = BufReader::new(file);
            let source = Decoder::new(reader).map_err(|e| format!("Decode error: {}", e))?;
            let duration_ms = source
                .total_duration()
                .unwrap_or(Duration::ZERO)
                .as_millis() as u64;

            sink.stop();
            sink.append(source);
            sink.play();

            *TRACK_DURATION_MS.lock().await = duration_ms;
            *CURRENT_SOURCE_PATH.lock().await = Some(path);
            *PLAYBACK_OFFSET_MS.lock().await = 0;
            *PLAYER_STATE.lock().await = PlaybackState::Playing;
            Ok(())
        } else {
            Err("Audio engine failed to initialize".to_string())
        }
    }

    /// Downloads a remote WebDAV audio file to a temp file and plays it.
    /// username / token are used for HTTP Basic Auth.
    pub async fn play_remote_file(
        url: String,
        username: String,
        token: String,
    ) -> Result<(), String> {
        Self::init_engine().await;
        let request_id = PLAY_REQUEST_ID.fetch_add(1, Ordering::SeqCst) + 1;

        {
            let sink_lock = GLOBAL_SINK.lock().await;
            if let Some(sink) = &*sink_lock {
                sink.stop();
            }
        }
        *PLAYER_STATE.lock().await = PlaybackState::Stopped;

        // 1. Download file bytes via HTTP
        let response = HTTP_CLIENT
            .get(&url)
            .basic_auth(&username, Some(&token))
            .send()
            .await
            .map_err(|e| format!("WebDAV download failed: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("WebDAV HTTP error: {}", response.status()));
        }

        let bytes = response
            .bytes()
            .await
            .map_err(|e| format!("Stream read error: {}", e))?;

        // 2. Write to a temporary file so Decoder can seek
        let ext = url
            .split('/')
            .last()
            .and_then(|name| name.split('.').last())
            .unwrap_or("tmp");
        let tmp_path = std::env::temp_dir().join(format!("arkpulse_stream.{}", ext));
        let mut tmp_file = std::fs::File::create(&tmp_path)
            .map_err(|e| format!("Temp file create error: {}", e))?;
        tmp_file
            .write_all(&bytes)
            .map_err(|e| format!("Temp file write error: {}", e))?;

        // 3. Play from temp file
        let file = File::open(&tmp_path).map_err(|e| format!("Temp file open error: {}", e))?;
        let reader = BufReader::new(file);
        let source = Decoder::new(reader).map_err(|e| format!("Decode error: {}", e))?;
        let duration_ms = source
            .total_duration()
            .unwrap_or(Duration::ZERO)
            .as_millis() as u64;

        let sink_lock = GLOBAL_SINK.lock().await;
        if let Some(sink) = &*sink_lock {
            if PLAY_REQUEST_ID.load(Ordering::SeqCst) != request_id {
                return Ok(());
            }
            sink.stop();
            sink.append(source);
            sink.play();
            *TRACK_DURATION_MS.lock().await = duration_ms;
            *CURRENT_SOURCE_PATH.lock().await =
                Some(tmp_path.to_string_lossy().to_string());
            *PLAYBACK_OFFSET_MS.lock().await = 0;
            *PLAYER_STATE.lock().await = PlaybackState::Playing;
            Ok(())
        } else {
            Err("Audio engine not initialized".to_string())
        }
    }

    pub async fn pause() {
        let sink_lock = GLOBAL_SINK.lock().await;
        if let Some(sink) = &*sink_lock {
            sink.pause();
            *PLAYER_STATE.lock().await = PlaybackState::Paused;
        }
    }

    pub async fn resume() {
        let sink_lock = GLOBAL_SINK.lock().await;
        if let Some(sink) = &*sink_lock {
            sink.play();
            *PLAYER_STATE.lock().await = PlaybackState::Playing;
        }
    }

    pub async fn stop() {
        let sink_lock = GLOBAL_SINK.lock().await;
        if let Some(sink) = &*sink_lock {
            sink.stop();
            *TRACK_DURATION_MS.lock().await = 0;
            *CURRENT_SOURCE_PATH.lock().await = None;
            *PLAYBACK_OFFSET_MS.lock().await = 0;
            *PLAYER_STATE.lock().await = PlaybackState::Stopped;
        }
    }

    pub async fn get_state() -> PlaybackState {
        let sink_lock = GLOBAL_SINK.lock().await;
        let mut state = PLAYER_STATE.lock().await;
        if let Some(sink) = &*sink_lock {
            if sink.empty() {
                *state = PlaybackState::Stopped;
                *TRACK_DURATION_MS.lock().await = 0;
            }
        }
        state.clone()
    }

    pub async fn get_progress() -> PlaybackProgress {
        let duration_ms = *TRACK_DURATION_MS.lock().await;
        let offset_ms = *PLAYBACK_OFFSET_MS.lock().await;
        let sink_lock = GLOBAL_SINK.lock().await;
        let position_ms = if let Some(sink) = &*sink_lock {
            offset_ms + (sink.get_pos().as_millis() as u64)
        } else {
            0
        };
        PlaybackProgress {
            position_ms,
            duration_ms,
        }
    }

    pub async fn seek(position_ms: u64) -> Result<(), String> {
        let source_path = CURRENT_SOURCE_PATH
            .lock()
            .await
            .clone()
            .ok_or_else(|| "No active source to seek".to_string())?;
        let duration_ms = *TRACK_DURATION_MS.lock().await;
        let target_ms = if duration_ms > 0 {
            position_ms.min(duration_ms)
        } else {
            position_ms
        };

        let sink_lock = GLOBAL_SINK.lock().await;
        if let Some(sink) = &*sink_lock {
            let was_paused = sink.is_paused();
            sink.stop();
            let file = File::open(&source_path)
                .map_err(|e| format!("Failed to reopen source: {}", e))?;
            let reader = BufReader::new(file);
            let source = Decoder::new(reader)
                .map_err(|e| format!("Decode error during seek: {}", e))?
                .skip_duration(Duration::from_millis(target_ms));
            sink.append(source);
            *PLAYBACK_OFFSET_MS.lock().await = target_ms;
            if was_paused {
                sink.pause();
            } else {
                sink.play();
            }
            Ok(())
        } else {
            Err("Audio engine not initialized".to_string())
        }
    }
}
