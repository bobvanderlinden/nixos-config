use std::env;
use std::fs::{metadata, File};
use std::path::PathBuf;
use std::time::{Duration, SystemTime};

const SESSION_FILE_NAME: &str = "session-time-start";

fn session_file() -> PathBuf {
    // The runtime directory is created per user session and cleared at boot.
    // Unlike /tmp, it cannot retain an unlock time from a previous boot.
    env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(env::temp_dir)
        .join(SESSION_FILE_NAME)
}

fn main() -> Result<(), String> {
    let mut args = env::args();
    let program = args.next().unwrap_or_default();
    let session_file = session_file();

    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--reset" => {
                File::create(&session_file)
                    .map_err(|e| format!("Failed to reset session file: {}", e))?;
                return Ok(());
            }
            _ => {
                return Err(format!("Usage: {} [--reset]", program));
            }
        }
    }

    let elapsed = match metadata(&session_file) {
        Ok(meta) => {
            let modified = meta
                .modified()
                .map_err(|e| format!("Failed to get session file modified time: {}", e))?;
            let now = SystemTime::now();
            now.duration_since(modified).unwrap_or(Duration::ZERO)
        }
        Err(_) => {
            File::create(&session_file)
                .map_err(|e| format!("Failed to create session file: {}", e))?;
            Duration::ZERO
        }
    };
    let hours = elapsed.as_secs() / 3600;
    let minutes = (elapsed.as_secs() % 3600) / 60;
    println!("{:02}:{:02}", hours, minutes);
    Ok(())
}
