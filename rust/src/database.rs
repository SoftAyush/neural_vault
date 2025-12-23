use crate::error::{NeuralVaultError, NVResult};
use crate::models::{DatabaseConfig, NVDocument, NVQuery, NVValue, UpdateOperation};
use crate::query::QueryProcessor;
use crate::storage::FileManager;
use parking_lot::RwLock;
use std::collections::HashMap;
use std::sync::Arc;
use uuid::Uuid;

/// Main database engine
pub struct NeuralVault {
    config: DatabaseConfig,
    storage: Arc<FileManager>,
    query_processor: QueryProcessor,
    initialized: bool,
}

impl NeuralVault {
    /// Create a new database instance
    pub fn new(config: DatabaseConfig) -> NVResult<Self> {
        let storage = Arc::new(FileManager::new(&config.path)?);
        
        // Rebuild index on startup
        storage.rebuild_index()?;

        Ok(Self {
            config,
            storage,
            query_processor: QueryProcessor::new(),
            initialized: true,
        })
    }

    /// Create a new document
    pub fn create(&self, collection: String, data: HashMap<String, NVValue>) -> NVResult<String> {
        self.ensure_initialized()?;

        // Generate unique ID
        let id = Uuid::new_v4().to_string();

        // Create document
        let document = NVDocument::new(id.clone(), collection, data);

        // Persist to storage
        self.storage.append(&document)?;

        Ok(id)
    }

    /// Find documents matching a query
    pub fn find(&self, query: NVQuery) -> NVResult<Vec<NVDocument>> {
        self.ensure_initialized()?;

        // Scan collection
        let documents = self.storage.scan_collection(&query.collection)?;

        // Apply query filters
        self.query_processor.filter(documents, &query)
    }

    /// Find a single document by ID
    pub fn find_by_id(&self, id: &str) -> NVResult<NVDocument> {
        self.ensure_initialized()?;
        self.storage.read(id)
    }

    /// Update documents matching a query
    pub fn update(&self, query: NVQuery, updates: Vec<UpdateOperation>) -> NVResult<usize> {
        self.ensure_initialized()?;

        // Find matching documents
        let documents = self.find(query)?;
        let count = documents.len();

        // Update each document
        for mut doc in documents {
            // Apply updates
            for update in &updates {
                doc.set(update.field.clone(), update.value.clone());
            }

            // Save updated document
            self.storage.append(&doc)?;
        }

        Ok(count)
    }

    /// Update a single document by ID
    pub fn update_by_id(&self, id: &str, updates: Vec<UpdateOperation>) -> NVResult<()> {
        self.ensure_initialized()?;

        // Read document
        let mut document = self.storage.read(id)?;

        // Apply updates
        for update in updates {
            document.set(update.field, update.value);
        }

        // Save updated document
        self.storage.append(&document)?;

        Ok(())
    }

    /// Delete documents matching a query (soft delete)
    pub fn kill(&self, query: NVQuery) -> NVResult<usize> {
        self.ensure_initialized()?;

        // Find matching documents
        let documents = self.find(query)?;
        let count = documents.len();

        // Mark each as deleted
        for doc in documents {
            self.storage.mark_deleted(&doc.id)?;
        }

        Ok(count)
    }

    /// Delete a single document by ID
    pub fn kill_by_id(&self, id: &str) -> NVResult<()> {
        self.ensure_initialized()?;
        self.storage.mark_deleted(id)?;
        Ok(())
    }

    /// Count documents in a collection
    pub fn count(&self, collection: &str) -> NVResult<usize> {
        self.ensure_initialized()?;
        let documents = self.storage.scan_collection(collection)?;
        Ok(documents.len())
    }

    /// Get all collection names
    pub fn collections(&self) -> NVResult<Vec<String>> {
        self.ensure_initialized()?;
        
        let documents = self.storage.scan_all()?;
        let mut collections: Vec<String> = documents
            .into_iter()
            .map(|doc| doc.collection)
            .collect();
        
        collections.sort();
        collections.dedup();
        
        Ok(collections)
    }

    /// Get database statistics
    pub fn stats(&self) -> NVResult<DatabaseStats> {
        self.ensure_initialized()?;
        
        let storage_stats = self.storage.statistics();
        let collections = self.collections()?;

        Ok(DatabaseStats {
            total_documents: storage_stats.document_count,
            total_collections: collections.len(),
            storage_size_bytes: storage_stats.file_size_bytes,
            collections,
        })
    }

    /// Ensure database is initialized
    fn ensure_initialized(&self) -> NVResult<()> {
        if !self.initialized {
            return Err(NeuralVaultError::NotInitialized);
        }
        Ok(())
    }
}

/// Database statistics
#[derive(Debug, Clone)]
pub struct DatabaseStats {
    pub total_documents: usize,
    pub total_collections: usize,
    pub storage_size_bytes: u64,
    pub collections: Vec<String>,
}
