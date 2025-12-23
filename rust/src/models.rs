use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use chrono::{DateTime, Utc};

/// Core data types supported by NeuralVault
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(untagged)]
pub enum NVValue {
    Null,
    Bool(bool),
    Number(f64),
    String(String),
    Array(Vec<NVValue>),
    Object(HashMap<String, NVValue>),
}

impl From<serde_json::Value> for NVValue {
    fn from(value: serde_json::Value) -> Self {
        match value {
            serde_json::Value::Null => NVValue::Null,
            serde_json::Value::Bool(b) => NVValue::Bool(b),
            serde_json::Value::Number(n) => NVValue::Number(n.as_f64().unwrap_or(0.0)),
            serde_json::Value::String(s) => NVValue::String(s),
            serde_json::Value::Array(arr) => {
                NVValue::Array(arr.into_iter().map(NVValue::from).collect())
            }
            serde_json::Value::Object(obj) => {
                NVValue::Object(obj.into_iter().map(|(k, v)| (k, NVValue::from(v))).collect())
            }
        }
    }
}

impl From<NVValue> for serde_json::Value {
    fn from(value: NVValue) -> Self {
        match value {
            NVValue::Null => serde_json::Value::Null,
            NVValue::Bool(b) => serde_json::Value::Bool(b),
            NVValue::Number(n) => serde_json::Number::from_f64(n)
                .map(serde_json::Value::Number)
                .unwrap_or(serde_json::Value::Null),
            NVValue::String(s) => serde_json::Value::String(s),
            NVValue::Array(arr) => {
                serde_json::Value::Array(arr.into_iter().map(serde_json::Value::from).collect())
            }
            NVValue::Object(obj) => {
                serde_json::Value::Object(
                    obj.into_iter()
                        .map(|(k, v)| (k, serde_json::Value::from(v)))
                        .collect(),
                )
            }
        }
    }
}

/// A document record in the database
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NVDocument {
    /// Unique identifier
    pub id: String,
    /// Collection name
    pub collection: String,
    /// Document data
    pub data: HashMap<String, NVValue>,
    /// Creation timestamp
    pub created_at: DateTime<Utc>,
    /// Last update timestamp
    pub updated_at: DateTime<Utc>,
    /// Soft delete flag
    #[serde(default)]
    pub deleted: bool,
}

impl NVDocument {
    pub fn new(id: String, collection: String, data: HashMap<String, NVValue>) -> Self {
        let now = Utc::now();
        Self {
            id,
            collection,
            data,
            created_at: now,
            updated_at: now,
            deleted: false,
        }
    }

    pub fn get(&self, field: &str) -> Option<&NVValue> {
        self.data.get(field)
    }

    pub fn set(&mut self, field: String, value: NVValue) {
        self.data.insert(field, value);
        self.updated_at = Utc::now();
    }
}

/// Query operators
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum QueryOperator {
    Equals,
    NotEquals,
    GreaterThan,
    GreaterThanOrEqual,
    LessThan,
    LessThanOrEqual,
    Contains,
    StartsWith,
    EndsWith,
    In,
    NotIn,
}

/// Query condition
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QueryCondition {
    pub field: String,
    pub operator: QueryOperator,
    pub value: NVValue,
}

/// Logical operators for combining conditions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum LogicalOperator {
    And,
    Or,
}

/// Query structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NVQuery {
    pub collection: String,
    pub conditions: Vec<QueryCondition>,
    pub logical_operators: Vec<LogicalOperator>,
    pub order_by: Option<String>,
    pub order_desc: bool,
    pub limit: Option<usize>,
    pub skip: Option<usize>,
}

impl NVQuery {
    pub fn new(collection: String) -> Self {
        Self {
            collection,
            conditions: Vec::new(),
            logical_operators: Vec::new(),
            order_by: None,
            order_desc: false,
            limit: None,
            skip: None,
        }
    }

    pub fn add_condition(
        &mut self,
        field: String,
        operator: QueryOperator,
        value: NVValue,
        logical_op: Option<LogicalOperator>,
    ) {
        if let Some(op) = logical_op {
            self.logical_operators.push(op);
        }
        self.conditions.push(QueryCondition {
            field,
            operator,
            value,
        });
    }
}

/// Database configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabaseConfig {
    /// Path to database directory
    pub path: String,
    /// Enable compression
    pub enable_compression: bool,
    /// Maximum cache size in MB
    pub cache_size_mb: usize,
    /// Enable encryption
    pub enable_encryption: bool,
    /// Auto-compact threshold (ratio of dead data)
    pub auto_compact_threshold: f32,
}

impl Default for DatabaseConfig {
    fn default() -> Self {
        Self {
            path: "./neural_vault_data".to_string(),
            enable_compression: false,
            cache_size_mb: 100,
            enable_encryption: false,
            auto_compact_threshold: 0.3,
        }
    }
}

/// Update operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateOperation {
    pub field: String,
    pub value: NVValue,
}
