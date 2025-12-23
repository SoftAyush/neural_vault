use thiserror::Error;

/// Custom error types for NeuralVault
#[derive(Error, Debug, Clone)]
pub enum NeuralVaultError {
    #[error("Document not found: {0}")]
    DocumentNotFound(String),

    #[error("Collection not found: {0}")]
    CollectionNotFound(String),

    #[error("Invalid query: {0}")]
    InvalidQuery(String),

    #[error("Storage error: {0}")]
    StorageError(String),

    #[error("Serialization error: {0}")]
    SerializationError(String),

    #[error("IO error: {0}")]
    IoError(String),

    #[error("Lock error: {0}")]
    LockError(String),

    #[error("Index error: {0}")]
    IndexError(String),

    #[error("Database not initialized")]
    NotInitialized,

    #[error("Database already exists at path: {0}")]
    AlreadyExists(String),

    #[error("Invalid configuration: {0}")]
    InvalidConfiguration(String),

    #[error("Transaction error: {0}")]
    TransactionError(String),

    #[error("Validation error: {0}")]
    ValidationError(String),
}

impl From<std::io::Error> for NeuralVaultError {
    fn from(err: std::io::Error) -> Self {
        NeuralVaultError::IoError(err.to_string())
    }
}

impl From<bincode::Error> for NeuralVaultError {
    fn from(err: bincode::Error) -> Self {
        NeuralVaultError::SerializationError(err.to_string())
    }
}

impl From<serde_json::Error> for NeuralVaultError {
    fn from(err: serde_json::Error) -> Self {
        NeuralVaultError::SerializationError(err.to_string())
    }
}

pub type NVResult<T> = Result<T, NeuralVaultError>;
