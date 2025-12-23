use crate::error::{NeuralVaultError, NVResult};
use crate::models::NVDocument;
use parking_lot::RwLock;
use std::collections::HashMap;
use std::fs::{File, OpenOptions};
use std::io::{BufReader, BufWriter, Read, Seek, SeekFrom, Write};
use std::path::PathBuf;
use std::sync::Arc;

/// Position in the storage file
#[derive(Debug, Clone, Copy)]
pub struct StoragePosition {
    pub file_offset: u64,
    pub length: u32,
}

/// File-based storage manager
pub struct FileManager {
    base_path: PathBuf,
    data_file: Arc<RwLock<File>>,
    index: Arc<RwLock<HashMap<String, StoragePosition>>>,
}

impl FileManager {
    /// Create or open a file manager
    pub fn new(path: &str) -> NVResult<Self> {
        let base_path = PathBuf::from(path);
        
        // Create directory if it doesn't exist
        std::fs::create_dir_all(&base_path)?;

        let data_file_path = base_path.join("data.nvdb");
        
        // Open or create data file
        let data_file = OpenOptions::new()
            .create(true)
            .read(true)
            .write(true)
            .open(&data_file_path)?;

        Ok(Self {
            base_path,
            data_file: Arc::new(RwLock::new(data_file)),
            index: Arc::new(RwLock::new(HashMap::new())),
        })
    }

    /// Append a document to storage
    pub fn append(&self, document: &NVDocument) -> NVResult<StoragePosition> {
        let mut file = self.data_file.write();
        
        // Serialize document
        let data = bincode::serialize(document)?;
        let data_len = data.len() as u32;

        // Calculate checksum
        let checksum = self.calculate_checksum(&data);

        // Get current file position
        let offset = file.seek(SeekFrom::End(0))?;

        // Write record: [length(4)][checksum(8)][data][tombstone(1)]
        file.write_all(&data_len.to_le_bytes())?;
        file.write_all(&checksum.to_le_bytes())?;
        file.write_all(&data)?;
        file.write_all(&[0u8])?; // Not deleted

        file.sync_all()?;

        let position = StoragePosition {
            file_offset: offset,
            length: data_len,
        };

        // Update index
        self.index.write().insert(document.id.clone(), position);

        Ok(position)
    }

    /// Read a document from storage
    pub fn read(&self, id: &str) -> NVResult<NVDocument> {
        let index = self.index.read();
        let position = index
            .get(id)
            .ok_or_else(|| NeuralVaultError::DocumentNotFound(id.to_string()))?;

        self.read_at(*position)
    }

    /// Read document at specific position
    fn read_at(&self, position: StoragePosition) -> NVResult<NVDocument> {
        let mut file = self.data_file.write();
        file.seek(SeekFrom::Start(position.file_offset))?;

        // Read length
        let mut len_buf = [0u8; 4];
        file.read_exact(&mut len_buf)?;
        let data_len = u32::from_le_bytes(len_buf);

        // Read checksum
        let mut checksum_buf = [0u8; 8];
        file.read_exact(&mut checksum_buf)?;
        let expected_checksum = u64::from_le_bytes(checksum_buf);

        // Read data
        let mut data = vec![0u8; data_len as usize];
        file.read_exact(&mut data)?;

        // Read tombstone
        let mut tombstone = [0u8; 1];
        file.read_exact(&mut tombstone)?;

        // Verify checksum
        let actual_checksum = self.calculate_checksum(&data);
        if actual_checksum != expected_checksum {
            return Err(NeuralVaultError::StorageError(
                "Checksum mismatch - data corruption detected".to_string(),
            ));
        }

        // Check if deleted
        if tombstone[0] == 1 {
            return Err(NeuralVaultError::DocumentNotFound(
                "Document has been deleted".to_string(),
            ));
        }

        // Deserialize
        let document: NVDocument = bincode::deserialize(&data)?;
        Ok(document)
    }

    /// Mark a document as deleted (soft delete)
    pub fn mark_deleted(&self, id: &str) -> NVResult<()> {
        let index = self.index.read();
        let position = index
            .get(id)
            .ok_or_else(|| NeuralVaultError::DocumentNotFound(id.to_string()))?;

        let mut file = self.data_file.write();
        
        // Seek to tombstone byte (length(4) + checksum(8) + data + tombstone)
        let tombstone_offset = position.file_offset + 4 + 8 + position.length as u64;
        file.seek(SeekFrom::Start(tombstone_offset))?;
        
        // Write tombstone
        file.write_all(&[1u8])?;
        file.sync_all()?;

        Ok(())
    }

    /// Scan all non-deleted documents in a collection
    pub fn scan_collection(&self, collection: &str) -> NVResult<Vec<NVDocument>> {
        let mut documents = Vec::new();
        let index = self.index.read().clone();

        for position in index.values() {
            match self.read_at(*position) {
                Ok(doc) => {
                    if doc.collection == collection && !doc.deleted {
                        documents.push(doc);
                    }
                }
                Err(_) => continue, // Skip corrupted or deleted documents
            }
        }

        Ok(documents)
    }

    /// Get all documents (for rebuilding index)
    pub fn scan_all(&self) -> NVResult<Vec<NVDocument>> {
        let mut documents = Vec::new();
        let mut file = self.data_file.write();
        file.seek(SeekFrom::Start(0))?;

        loop {
            let offset = file.stream_position()?;

            // Read length
            let mut len_buf = [0u8; 4];
            match file.read_exact(&mut len_buf) {
                Ok(_) => {}
                Err(e) if e.kind() == std::io::ErrorKind::UnexpectedEof => break,
                Err(e) => return Err(e.into()),
            }

            let data_len = u32::from_le_bytes(len_buf);

            // Skip checksum
            file.seek(SeekFrom::Current(8))?;

            // Read data
            let mut data = vec![0u8; data_len as usize];
            file.read_exact(&mut data)?;

            // Read tombstone
            let mut tombstone = [0u8; 1];
            file.read_exact(&mut tombstone)?;

            if tombstone[0] == 0 {
                if let Ok(doc) = bincode::deserialize::<NVDocument>(&data) {
                    documents.push(doc);
                }
            }
        }

        Ok(documents)
    }

    /// Rebuild index from storage file
    pub fn rebuild_index(&self) -> NVResult<()> {
        let documents = self.scan_all()?;
        let mut index = self.index.write();
        index.clear();

        let mut file = self.data_file.write();
        file.seek(SeekFrom::Start(0))?;

        for doc in documents {
            let offset = file.stream_position()?;
            
            // Calculate position
            let data = bincode::serialize(&doc)?;
            let data_len = data.len() as u32;
            
            let position = StoragePosition {
                file_offset: offset,
                length: data_len,
            };

            index.insert(doc.id.clone(), position);

            // Skip to next record
            let skip_bytes = 4 + 8 + data_len as i64 + 1;
            file.seek(SeekFrom::Current(skip_bytes))?;
        }

        Ok(())
    }

    /// Calculate simple checksum (FNV-1a hash)
    fn calculate_checksum(&self, data: &[u8]) -> u64 {
        let mut hash: u64 = 0xcbf29ce484222325;
        for &byte in data {
            hash ^= byte as u64;
            hash = hash.wrapping_mul(0x100000001b3);
        }
        hash
    }

    /// Get storage statistics
    pub fn statistics(&self) -> StorageStats {
        let index_count = self.index.read().len();
        let file_size = self
            .data_file
            .read()
            .metadata()
            .map(|m| m.len())
            .unwrap_or(0);

        StorageStats {
            document_count: index_count,
            file_size_bytes: file_size,
        }
    }
}

#[derive(Debug)]
pub struct StorageStats {
    pub document_count: usize,
    pub file_size_bytes: u64,
}
