pub mod api;
pub mod database;
pub mod error;
pub mod models;
pub mod query;
pub mod storage;

// Re-export main types
pub use database::{DatabaseStats, NeuralVault};
pub use error::{NeuralVaultError, NVResult};
pub use models::{
    DatabaseConfig, LogicalOperator, NVDocument, NVQuery, NVValue, QueryCondition, QueryOperator,
    UpdateOperation,
};

// Re-export API functions for FFI
pub use api::*;

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    use tempfile::tempdir;

    #[test]
    fn test_create_and_find() {
        let dir = tempdir().unwrap();
        let config = DatabaseConfig {
            path: dir.path().to_str().unwrap().to_string(),
            ..Default::default()
        };

        let db = NeuralVault::new(config).unwrap();

        // Create a document
        let mut data = HashMap::new();
        data.insert("name".to_string(), NVValue::String("John".to_string()));
        data.insert("age".to_string(), NVValue::Number(30.0));

        let id = db.create("users".to_string(), data).unwrap();

        // Find by ID
        let doc = db.find_by_id(&id).unwrap();
        assert_eq!(doc.id, id);
        assert_eq!(doc.collection, "users");
    }

    #[test]
    fn test_query_with_filter() {
        let dir = tempdir().unwrap();
        let config = DatabaseConfig {
            path: dir.path().to_str().unwrap().to_string(),
            ..Default::default()
        };

        let db = NeuralVault::new(config).unwrap();

        // Create documents
        for i in 1..=5 {
            let mut data = HashMap::new();
            data.insert("name".to_string(), NVValue::String(format!("User{}", i)));
            data.insert("age".to_string(), NVValue::Number(20.0 + i as f64));
            db.create("users".to_string(), data).unwrap();
        }

        // Query with filter
        let mut query = NVQuery::new("users".to_string());
        query.add_condition(
            "age".to_string(),
            QueryOperator::GreaterThan,
            NVValue::Number(22.0),
            None,
        );

        let results = db.find(query).unwrap();
        assert_eq!(results.len(), 3); // Users with age > 22
    }

    #[test]
    fn test_update_and_delete() {
        let dir = tempdir().unwrap();
        let config = DatabaseConfig {
            path: dir.path().to_str().unwrap().to_string(),
            ..Default::default()
        };

        let db = NeuralVault::new(config).unwrap();

        // Create a document
        let mut data = HashMap::new();
        data.insert("name".to_string(), NVValue::String("Alice".to_string()));
        data.insert("status".to_string(), NVValue::String("active".to_string()));

        let id = db.create("users".to_string(), data).unwrap();

        // Update
        let updates = vec![UpdateOperation {
            field: "status".to_string(),
            value: NVValue::String("inactive".to_string()),
        }];
        db.update_by_id(&id, updates).unwrap();

        // Verify update
        let doc = db.find_by_id(&id).unwrap();
        assert_eq!(
            doc.get("status"),
            Some(&NVValue::String("inactive".to_string()))
        );

        // Delete
        db.kill_by_id(&id).unwrap();

        // Verify deletion
        assert!(db.find_by_id(&id).is_err());
    }
}
