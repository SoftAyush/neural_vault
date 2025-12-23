# Future Release Roadmap

This document outlines the planned features and improvements for upcoming releases of NeuralVault.

## 🚀 Upcoming Features

### 1. Rust Backend Integration (High Priority)
Replace the current pure Dart implementation with a high-performance Rust backend via FFI.
- **Goal**: Significantly improve query performance and memory management.
- **Tasks**:
    - [ ] Complete Rust `database` module implementation.
    - [ ] Expose C-compatible API from Rust.
    - [ ] Implement Dart FFI bindings (`flutter_rust_bridge` or `ffi` package).
    - [ ] Benchmark comparison between Dart-only and Rust-backed implementations.

### 2. Advanced Security
Implement data encryption to secure sensitive information.
- **Planned Features**:
    - [ ] AES-256 encryption for data at rest.
    - [ ] Secure key management integration.
    - [ ] Configurable encryption levels (per-collection or full database).

### 3. Data Compression
Reduce disk usage and improve I/O performance for large datasets.
- **Planned Features**:
    - [ ] LZ4 or Zstd compression algorithms.
    - [ ] Automatic compression for old/archived data.

### 4. Reliability & ACID Transactions
Ensure data integrity during complex operations.
- **Planned Features**:
    - [ ] Multi-document ACID transactions.
    - [ ] Rollback capabilities on failure.
    - [ ] Write-ahead logging (WAL) for crash recovery.

### 5. Indexing Improvements
Enhance query speed for complex lookups.
- **Planned Features**:
    - [ ] Secondary indexes (B-Tree or Hash-based).
    - [ ] Compound indexes for multi-field queries.
    - [ ] Index usage analysis/statistics.

## 📅 Release Schedule (Tentative)

| Version | Focus | Key Features |
|---------|-------|--------------|
| **0.2.0** | Performance | Rust Core Integration, Basic Benchmarks |
| **0.3.0** | Security | Encryption, Compression |
| **0.4.0** | Reliability | Transactions, WAL |
| **1.0.0** | Stability | Full Feature Complete, Production Ready |

---
*Note: This roadmap is subject to change based on user feedback and technical challenges.*
