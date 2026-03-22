#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("ArkPulse FFI says: Hello, {name}!")
}

#[flutter_rust_bridge::frb(sync)]
pub fn add(left: u64, right: u64) -> u64 {
    left + right
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
