use crate::database::{DatabaseStats, NeuralVault};
use crate::error::{NeuralVaultError, NVResult};
use crate::models::{DatabaseConfig, LogicalOperator, NVDocument, NVQuery, NVValue, QueryOperator, UpdateOperation};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

/// Global database instance
static DB_INSTANCE: Mutex<Option<Arc<NeuralVault>>> = Mutex::new(None);

/// Initialize database with configuration
pub fn init_database(path: String) -> Result<String, String> {
    let config = DatabaseConfig {
        path,
        ..Default::default()
    };

    match NeuralVault::new(config) {
        Ok(db) => {
            let mut instance = DB_INSTANCE.lock().unwrap();
            *instance = Some(Arc::new(db));
            Ok("Database initialized successfully".to_string())
        }
        Err(e) => Err(format!("Failed to initialize database: {}", e)),
    }
}

/// Get database instance
fn get_db() -> Result<Arc<NeuralVault>, String> {
    let instance = DB_INSTANCE.lock().unwrap();
    instance
        .as_ref()
        .cloned()
        .ok_or_else(|| "Database not initialized".to_string())
}

/// Create a document
pub fn create_document(
    collection: String,
    json_data: String,
) -> Result<String, String> {
    let db = get_db()?;
    
    // Parse JSON
    let json_value: serde_json::Value = serde_json::from_str(&json_data)
        .map_err(|e| format!("Invalid JSON: {}", e))?;

    // Convert to HashMap
    let data = json_to_hashmap(json_value)?;

    db.create(collection, data)
        .map_err(|e| format!("Create failed: {}", e))
}

/// Find documents
pub fn find_documents(
    collection: String,
    query_json: String,
) -> Result<String, String> {
    let db = get_db()?;

    // Parse query
    let query = parse_query_json(collection, query_json)?;

    let documents = db.find(query)
        .map_err(|e| format!("Find failed: {}", e))?;

    // Convert to JSON
    let json = serde_json::to_string(&documents)
        .map_err(|e| format!("Serialization failed: {}", e))?;

    Ok(json)
}

/// Find document by ID
pub fn find_document_by_id(id: String) -> Result<String, String> {
    let db = get_db()?;

    let document = db.find_by_id(&id)
        .map_err(|e| format!("Find failed: {}", e))?;

    let json = serde_json::to_string(&document)
        .map_err(|e| format!("Serialization failed: {}", e))?;

    Ok(json)
}

/// Update documents
pub fn update_documents(
    collection: String,
    query_json: String,
    updates_json: String,
) -> Result<usize, String> {
    let db = get_db()?;

    let query = parse_query_json(collection, query_json)?;
    let updates = parse_updates_json(updates_json)?;

    db.update(query, updates)
        .map_err(|e| format!("Update failed: {}", e))
}

/// Update document by ID
pub fn update_document_by_id(
    id: String,
    updates_json: String,
) -> Result<String, String> {
    let db = get_db()?;

    let updates = parse_updates_json(updates_json)?;

    db.update_by_id(&id, updates)
        .map_err(|e| format!("Update failed: {}", e))?;

    Ok("Document updated successfully".to_string())
}

/// Delete documents
pub fn delete_documents(
    collection: String,
    query_json: String,
) -> Result<usize, String> {
    let db = get_db()?;

    let query = parse_query_json(collection, query_json)?;

    db.kill(query)
        .map_err(|e| format!("Delete failed: {}", e))
}

/// Delete document by ID
pub fn delete_document_by_id(id: String) -> Result<String, String> {
    let db = get_db()?;

    db.kill_by_id(&id)
        .map_err(|e| format!("Delete failed: {}", e))?;

    Ok("Document deleted successfully".to_string())
}

/// Count documents in collection
pub fn count_documents(collection: String) -> Result<usize, String> {
    let db = get_db()?;

    db.count(&collection)
        .map_err(|e| format!("Count failed: {}", e))
}

/// Get all collections
pub fn get_collections() -> Result<Vec<String>, String> {
    let db = get_db()?;

    db.collections()
        .map_err(|e| format!("Failed to get collections: {}", e))
}

/// Get database statistics
pub fn get_stats() -> Result<String, String> {
    let db = get_db()?;

    let stats = db.stats()
        .map_err(|e| format!("Failed to get stats: {}", e))?;

    let json = serde_json::to_string(&serde_json::json!({
        "total_documents": stats.total_documents,
        "total_collections": stats.total_collections,
        "storage_size_bytes": stats.storage_size_bytes,
        "collections": stats.collections,
    }))
    .map_err(|e| format!("Serialization failed: {}", e))?;

    Ok(json)
}

// Helper functions

fn json_to_hashmap(value: serde_json::Value) -> Result<HashMap<String, NVValue>, String> {
    match value {
        serde_json::Value::Object(obj) => {
            Ok(obj.into_iter().map(|(k, v)| (k, NVValue::from(v))).collect())
        }
        _ => Err("Expected JSON object".to_string()),
    }
}

fn parse_query_json(collection: String, query_json: String) -> Result<NVQuery, String> {
    if query_json.is_empty() || query_json == "{}" {
        return Ok(NVQuery::new(collection));
    }

    let json: serde_json::Value = serde_json::from_str(&query_json)
        .map_err(|e| format!("Invalid query JSON: {}", e))?;

    let mut query = NVQuery::new(collection);

    // Parse conditions
    if let Some(conditions) = json.get("conditions").and_then(|v| v.as_array()) {
        for (i, cond) in conditions.iter().enumerate() {
            let field = cond.get("field")
                .and_then(|v| v.as_str())
                .ok_or("Missing field in condition")?
                .to_string();

            let operator_str = cond.get("operator")
                .and_then(|v| v.as_str())
                .ok_or("Missing operator in condition")?;

            let operator = parse_operator(operator_str)?;

            let value = cond.get("value")
                .ok_or("Missing value in condition")?
                .clone();

            let logical_op = if i > 0 {
                let op_str = cond.get("logical")
                    .and_then(|v| v.as_str())
                    .unwrap_or("and");
                Some(parse_logical_operator(op_str)?)
            } else {
                None
            };

            query.add_condition(field, operator, NVValue::from(value), logical_op);
        }
    }

    // Parse order_by
    if let Some(order_by) = json.get("order_by").and_then(|v| v.as_str()) {
        query.order_by = Some(order_by.to_string());
        query.order_desc = json.get("order_desc").and_then(|v| v.as_bool()).unwrap_or(false);
    }

    // Parse limit and skip
    query.limit = json.get("limit").and_then(|v| v.as_u64()).map(|v| v as usize);
    query.skip = json.get("skip").and_then(|v| v.as_u64()).map(|v| v as usize);

    Ok(query)
}

fn parse_updates_json(updates_json: String) -> Result<Vec<UpdateOperation>, String> {
    let json: serde_json::Value = serde_json::from_str(&updates_json)
        .map_err(|e| format!("Invalid updates JSON: {}", e))?;

    let mut updates = Vec::new();

    if let serde_json::Value::Object(obj) = json {
        for (field, value) in obj {
            updates.push(UpdateOperation {
                field,
                value: NVValue::from(value),
            });
        }
    }

    Ok(updates)
}

fn parse_operator(op: &str) -> Result<QueryOperator, String> {
    match op {
        "==" | "equals" => Ok(QueryOperator::Equals),
        "!=" | "not_equals" => Ok(QueryOperator::NotEquals),
        ">" | "greater_than" => Ok(QueryOperator::GreaterThan),
        ">=" | "greater_than_or_equal" => Ok(QueryOperator::GreaterThanOrEqual),
        "<" | "less_than" => Ok(QueryOperator::LessThan),
        "<=" | "less_than_or_equal" => Ok(QueryOperator::LessThanOrEqual),
        "contains" => Ok(QueryOperator::Contains),
        "starts_with" => Ok(QueryOperator::StartsWith),
        "ends_with" => Ok(QueryOperator::EndsWith),
        "in" => Ok(QueryOperator::In),
        "not_in" => Ok(QueryOperator::NotIn),
        _ => Err(format!("Unknown operator: {}", op)),
    }
}

fn parse_logical_operator(op: &str) -> Result<LogicalOperator, String> {
    match op.to_lowercase().as_str() {
        "and" | "&&" => Ok(LogicalOperator::And),
        "or" | "||" => Ok(LogicalOperator::Or),
        _ => Err(format!("Unknown logical operator: {}", op)),
    }
}
