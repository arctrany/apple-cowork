use chrono::Utc;
use rand::Rng;
use serde::{Deserialize, Serialize};
use std::fmt;

/// A human-readable, filesystem-safe task identifier.
///
/// Format: `YYYYMMDD-HHMMSS-XXXX` where XXXX is a random hex suffix.
/// Example: `20260604-171523-a3f2`
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct TaskId(String);

impl TaskId {
    /// Generate a new TaskId with current timestamp and random suffix.
    pub fn generate() -> Self {
        let now = Utc::now();
        let suffix: u16 = rand::thread_rng().gen();
        TaskId(format!("{}-{:04x}", now.format("%Y%m%d-%H%M%S"), suffix))
    }

    /// Parse a TaskId from a string, validating format.
    pub fn parse(s: &str) -> Result<Self, TaskIdError> {
        // Validate format: YYYYMMDD-HHMMSS-XXXX (20 chars)
        if s.len() != 20 {
            return Err(TaskIdError::InvalidFormat(s.to_string()));
        }
        // Basic structure check: digits-digits-hex
        let parts: Vec<&str> = s.split('-').collect();
        if parts.len() != 3 || parts[0].len() != 8 || parts[1].len() != 6 || parts[2].len() != 4 {
            return Err(TaskIdError::InvalidFormat(s.to_string()));
        }
        if !parts[0].chars().all(|c| c.is_ascii_digit())
            || !parts[1].chars().all(|c| c.is_ascii_digit())
            || !parts[2].chars().all(|c| c.is_ascii_hexdigit())
        {
            return Err(TaskIdError::InvalidFormat(s.to_string()));
        }
        Ok(TaskId(s.to_string()))
    }

    /// Get the raw string value.
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for TaskId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl AsRef<str> for TaskId {
    fn as_ref(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, thiserror::Error)]
pub enum TaskIdError {
    #[error("invalid task ID format: '{0}' (expected YYYYMMDD-HHMMSS-XXXX)")]
    InvalidFormat(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_format() {
        let id = TaskId::generate();
        let s = id.as_str();
        assert_eq!(s.len(), 20);
        assert_eq!(&s[8..9], "-");
        assert_eq!(&s[15..16], "-");
    }

    #[test]
    fn test_parse_valid() {
        let id = TaskId::parse("20260604-171523-a3f2").unwrap();
        assert_eq!(id.as_str(), "20260604-171523-a3f2");
    }

    #[test]
    fn test_parse_invalid() {
        assert!(TaskId::parse("bad-id").is_err());
        assert!(TaskId::parse("20260604-171523-zzzz").is_err()); // non-hex
        assert!(TaskId::parse("2026060-0171523-a3f2").is_err()); // wrong segment lengths
    }

    #[test]
    fn test_serde_roundtrip() {
        let id = TaskId::generate();
        let json = serde_json::to_string(&id).unwrap();
        let parsed: TaskId = serde_json::from_str(&json).unwrap();
        assert_eq!(id, parsed);
    }
}
