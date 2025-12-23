use crate::error::{NeuralVaultError, NVResult};
use crate::models::{LogicalOperator, NVDocument, NVQuery, NVValue, QueryCondition, QueryOperator};

/// Query processor for filtering and sorting documents
pub struct QueryProcessor;

impl QueryProcessor {
    pub fn new() -> Self {
        Self
    }

    /// Filter documents based on query conditions
    pub fn filter(&self, documents: Vec<NVDocument>, query: &NVQuery) -> NVResult<Vec<NVDocument>> {
        if documents.is_empty() {
            return Ok(Vec::new());
        }

        let mut results: Vec<NVDocument> = documents
            .into_iter()
            .filter(|doc| self.matches_query(doc, query))
            .collect();

        // Apply ordering
        if let Some(order_field ) = &query.order_by {
            self.sort_documents(&mut results, order_field, query.order_desc);
        }

        // Apply skip
        if let Some(skip) = query.skip {
            results = results.into_iter().skip(skip).collect();
        }

        // Apply limit
        if let Some(limit) = query.limit {
            results.truncate(limit);
        }

        Ok(results)
    }

    /// Check if a document matches all query conditions
    fn matches_query(&self, document: &NVDocument, query: &NVQuery) -> bool {
        if query.conditions.is_empty() {
            return true;
        }

        // Start with the first condition
        let mut result = self.evaluate_condition(document, &query.conditions[0]);

        // Apply logical operators
        for (i, logical_op) in query.logical_operators.iter().enumerate() {
            let next_condition_idx = i + 1;
            if next_condition_idx >= query.conditions.len() {
                break;
            }

            let next_result = self.evaluate_condition(document, &query.conditions[next_condition_idx]);

            result = match logical_op {
                LogicalOperator::And => result && next_result,
                LogicalOperator::Or => result || next_result,
            };
        }

        result
    }

    /// Evaluate a single condition
    fn evaluate_condition(&self, document: &NVDocument, condition: &QueryCondition) -> bool {
        let field_value = match document.get(&condition.field) {
            Some(v) => v,
            None => return false,
        };

        self.compare_values(field_value, &condition.value, &condition.operator)
    }

    /// Compare two values based on the operator
    fn compare_values(&self, left: &NVValue, right: &NVValue, operator: &QueryOperator) -> bool {
        match operator {
            QueryOperator::Equals => self.values_equal(left, right),
            QueryOperator::NotEquals => !self.values_equal(left, right),
            QueryOperator::GreaterThan => self.compare_numeric(left, right, |a, b| a > b),
            QueryOperator::GreaterThanOrEqual => self.compare_numeric(left, right, |a, b| a >= b),
            QueryOperator::LessThan => self.compare_numeric(left, right, |a, b| a < b),
            QueryOperator::LessThanOrEqual => self.compare_numeric(left, right, |a, b| a <= b),
            QueryOperator::Contains => self.string_contains(left, right),
            QueryOperator::StartsWith => self.string_starts_with(left, right),
            QueryOperator::EndsWith => self.string_ends_with(left, right),
            QueryOperator::In => self.value_in_array(left, right),
            QueryOperator::NotIn => !self.value_in_array(left, right),
        }
    }

    /// Check if two values are equal
    fn values_equal(&self, left: &NVValue, right: &NVValue) -> bool {
        match (left, right) {
            (NVValue::Null, NVValue::Null) => true,
            (NVValue::Bool(a), NVValue::Bool(b)) => a == b,
            (NVValue::Number(a), NVValue::Number(b)) => (a - b).abs() < f64::EPSILON,
            (NVValue::String(a), NVValue::String(b)) => a == b,
            _ => false,
        }
    }

    /// Compare numeric values
    fn compare_numeric<F>(&self, left: &NVValue, right: &NVValue, comparator: F) -> bool
    where
        F: Fn(f64, f64) -> bool,
    {
        match (left, right) {
            (NVValue::Number(a), NVValue::Number(b)) => comparator(*a, *b),
            _ => false,
        }
    }

    /// Check if string contains substring
    fn string_contains(&self, left: &NVValue, right: &NVValue) -> bool {
        match (left, right) {
            (NVValue::String(haystack), NVValue::String(needle)) => haystack.contains(needle.as_str()),
            _ => false,
        }
    }

    /// Check if string starts with prefix
    fn string_starts_with(&self, left: &NVValue, right: &NVValue) -> bool {
        match (left, right) {
            (NVValue::String(s), NVValue::String(prefix)) => s.starts_with(prefix.as_str()),
            _ => false,
        }
    }

    /// Check if string ends with suffix
    fn string_ends_with(&self, left: &NVValue, right: &NVValue) -> bool {
        match (left, right) {
            (NVValue::String(s), NVValue::String(suffix)) => s.ends_with(suffix.as_str()),
            _ => false,
        }
    }

    /// Check if value is in array
    fn value_in_array(&self, value: &NVValue, array: &NVValue) -> bool {
        match array {
            NVValue::Array(arr) => arr.iter().any(|item| self.values_equal(value, item)),
            _ => false,
        }
    }

    /// Sort documents by field
    fn sort_documents(&self, documents: &mut [NVDocument], field: &str, descending: bool) {
        documents.sort_by(|a, b| {
            let a_val = a.get(field);
            let b_val = b.get(field);

            let ordering = match (a_val, b_val) {
                (Some(NVValue::Number(a)), Some(NVValue::Number(b))) => {
                    a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal)
                }
                (Some(NVValue::String(a)), Some(NVValue::String(b))) => a.cmp(b),
                (Some(NVValue::Bool(a)), Some(NVValue::Bool(b))) => a.cmp(b),
                (Some(_), None) => std::cmp::Ordering::Less,
                (None, Some(_)) => std::cmp::Ordering::Greater,
                _ => std::cmp::Ordering::Equal,
            };

            if descending {
                ordering.reverse()
            } else {
                ordering
            }
        });
    }
}

impl Default for QueryProcessor {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    #[test]
    fn test_equals_operator() {
        let processor = QueryProcessor::new();
        
        let left = NVValue::String("test".to_string());
        let right = NVValue::String("test".to_string());
        
        assert!(processor.compare_values(&left, &right, &QueryOperator::Equals));
    }

    #[test]
    fn test_greater_than_operator() {
        let processor = QueryProcessor::new();
        
        let left = NVValue::Number(10.0);
        let right = NVValue::Number(5.0);
        
        assert!(processor.compare_values(&left, &right, &QueryOperator::GreaterThan));
    }

    #[test]
    fn test_contains_operator() {
        let processor = QueryProcessor::new();
        
        let left = NVValue::String("hello world".to_string());
        let right = NVValue::String("world".to_string());
        
        assert!(processor.compare_values(&left, &right, &QueryOperator::Contains));
    }
}
