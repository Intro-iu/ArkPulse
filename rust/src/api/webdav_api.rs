use flutter_rust_bridge::frb;
use reqwest::{Client, Url};

pub struct WebDavEntry {
    pub path: String,
    pub name: String,
    pub is_dir: bool,
    pub size: u64,
    pub last_modified: String,
}

#[frb(opaque)]
pub struct WebDavClient {
    pub server_url: String,
    pub username: String,
    pub token: String,
    client: Client,
}

impl WebDavClient {
    #[frb(sync)]
    pub fn new(server_url: String, username: String, token: String) -> Self {
        Self {
            server_url,
            username,
            token,
            client: Client::new(),
        }
    }

    /// Lists a single directory (Depth: 1) via PROPFIND.
    /// Returns all immediate children (files and subdirs).
    pub async fn list_directory(&self, path: String) -> Result<Vec<WebDavEntry>, String> {
        self.propfind(&path).await
    }

    /// Recursively lists all entries under [root_path] using BFS PROPFIND.
    /// Only returns files (is_dir == false) that are audio files.
    pub async fn list_all_audio_recursive(&self, root_path: String) -> Result<Vec<WebDavEntry>, String> {
        let audio_exts = [
            "flac", "mp3", "ogg", "opus", "aac", "m4a", "wav",
            "wv", "ape", "alac", "aiff", "aif", "dsf", "dff",
        ];

        let mut audio_files: Vec<WebDavEntry> = Vec::new();
        let mut dirs_to_visit: Vec<String> = vec![root_path];

        while let Some(current_dir) = dirs_to_visit.first().cloned() {
            dirs_to_visit.remove(0);

            let entries = match self.propfind(&current_dir).await {
                Ok(e) => e,
                Err(e) => {
                    // Log and skip directories we can't read
                    eprintln!("WebDAV PROPFIND error for {}: {}", current_dir, e);
                    continue;
                }
            };

            for entry in entries {
                if entry.is_dir {
                    dirs_to_visit.push(entry.path.clone());
                } else {
                    let ext = entry.name
                        .split('.')
                        .last()
                        .unwrap_or("")
                        .to_lowercase();
                    if audio_exts.contains(&ext.as_str()) {
                        audio_files.push(entry);
                    }
                }
            }
        }

        Ok(audio_files)
    }

    /// Low-level PROPFIND for a single path (Depth: 1).
    async fn propfind(&self, path: &str) -> Result<Vec<WebDavEntry>, String> {
        let url = self.resolve_request_url(path)?;
        eprintln!("WebDAV PROPFIND request path={} resolved_url={}", path, url);

        let request = self
            .client
            .request(
                reqwest::Method::from_bytes(b"PROPFIND").unwrap(),
                &url,
            )
            .basic_auth(&self.username, Some(&self.token))
            .header("Depth", "1")
            .send()
            .await
            .map_err(|e| e.to_string())?;

        let status = request.status();
        if !status.is_success() {
            return Err(format!("WebDAV Error: {}", status));
        }

        let xml = request.text().await.map_err(|e| e.to_string())?;

        let mut entries = Vec::new();
        let re_response = regex::Regex::new(
            r"(?s)<(?:[a-zA-Z0-9_]+:)?response[^>]*>(.*?)</(?:[a-zA-Z0-9_]+:)?response>",
        )
        .unwrap();
        let re_href =
            regex::Regex::new(r"<(?:[a-zA-Z0-9_]+:)?href[^>]*>(.*?)</").unwrap();
        let re_len =
            regex::Regex::new(r"<(?:[a-zA-Z0-9_]+:)?getcontentlength[^>]*>(.*?)</").unwrap();
        let re_mod =
            regex::Regex::new(r"<(?:[a-zA-Z0-9_]+:)?getlastmodified[^>]*>(.*?)</").unwrap();
        let re_col = regex::Regex::new(r"<(?:[a-zA-Z0-9_]+:)?collection").unwrap();

        for cap in re_response.captures_iter(&xml) {
            let block = &cap[1];

            let href = re_href
                .captures(block)
                .map(|c| c[1].to_string())
                .unwrap_or_default();
            let mut name = href
                .trim_end_matches('/')
                .split('/')
                .last()
                .unwrap_or("")
                .to_string();
            name = urlencoding::decode(&name)
                .unwrap_or(std::borrow::Cow::Borrowed(&name))
                .to_string();

            let is_dir = re_col.is_match(block);
            let size: u64 = re_len
                .captures(block)
                .and_then(|c| c[1].parse().ok())
                .unwrap_or(0);
            let last_modified = re_mod
                .captures(block)
                .map(|c| c[1].to_string())
                .unwrap_or_default();

            if href.is_empty() || name.is_empty() {
                continue;
            }

            entries.push(WebDavEntry {
                path: href,
                name,
                is_dir,
                size,
                last_modified,
            });
        }

        // Drop the first entry (the directory itself in PROPFIND response)
        if !entries.is_empty() {
            entries.remove(0);
        }

        Ok(entries)
    }

    fn resolve_request_url(&self, path: &str) -> Result<String, String> {
        let base = Url::parse(&self.server_url)
            .map_err(|e| format!("Invalid WebDAV server URL {}: {}", self.server_url, e))?;
        let raw_path = path.trim();

        if raw_path.is_empty() {
            return Ok(base.to_string());
        }

        if let Ok(absolute_url) = Url::parse(raw_path) {
            return Ok(absolute_url.to_string());
        }

        let origin = match base.port() {
            Some(port) => format!(
                "{}://{}:{}",
                base.scheme(),
                base.host_str().unwrap_or_default(),
                port
            ),
            None => format!("{}://{}", base.scheme(), base.host_str().unwrap_or_default()),
        };

        let mut collection_root = base.clone();
        if !collection_root.path().ends_with('/') {
            let with_slash = format!("{}/", collection_root.path());
            collection_root.set_path(&with_slash);
        }

        if raw_path.starts_with('/') {
            let base_path = base.path().trim_end_matches('/');
            if !base_path.is_empty() && raw_path.starts_with(base_path) {
                return Ok(format!("{}{}", origin, raw_path));
            }
        }

        collection_root
            .join(raw_path.trim_start_matches('/'))
            .map(|url| url.to_string())
            .map_err(|e| format!("Failed to resolve WebDAV path {}: {}", path, e))
    }
}
