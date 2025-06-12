use std::env;
use std::fs::{File, metadata};
use std::io;
use std::time::{SystemTime, Duration};
use std::fmt;

const SESSION_FILE: &str = "/tmp/.session-start";

fn main() -> Result<(), String> {
    let mut args = env::args();
    let program = args.next().unwrap_or_default();

    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--reset" => {
                let file = File::open(SESSION_FILE).map_err(|e| format!("Failed to open session file: {}", e))?;
                file.set_modified(SystemTime::now()).map_err(|e| format!("Failed to set session file modified time: {}", e))?;
                return Ok(());
            }
            _ => {
                return Err(format!("Usage: {} [--reset]", program));
            }
        }
    }

    let elapsed = match metadata(SESSION_FILE) {
        Ok(meta) => {
            let modified = meta.modified().map_err(|e| format!("Failed to get session file modified time: {}", e))?;
            let now = SystemTime::now();
            now.duration_since(modified).unwrap_or(Duration::ZERO)
        }
        Err(e) => {
            File::create(SESSION_FILE).map_err(|e| format!("Failed to create session file: {}", e))?;
            Duration::ZERO
        }
    };
    let hours = elapsed.as_secs() / 3600;
    let minutes = (elapsed.as_secs() % 3600) / 60;
    println!("{:02}:{:02}", hours, minutes);
    Ok(())
}
