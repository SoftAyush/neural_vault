/// NeuralVault exceptions
class NeuralVaultException implements Exception {
  final String message;
  final StackTrace? stackTrace;

  NeuralVaultException(this.message, [this.stackTrace]);

  @override
  String toString() => 'NeuralVaultException: $message';
}

class DocumentNotFoundException extends NeuralVaultException {
  DocumentNotFoundException(String id) : super('Document not found: $id');
}

class CollectionNotFoundException extends NeuralVaultException {
  CollectionNotFoundException(String collection)
    : super('Collection not found: $collection');
}

class InvalidQueryException extends NeuralVaultException {
  InvalidQueryException(String message) : super('Invalid query: $message');
}

class StorageException extends NeuralVaultException {
  StorageException(String message) : super('Storage error: $message');
}

class DatabaseNotInitializedException extends NeuralVaultException {
  DatabaseNotInitializedException() : super('Database not initialized');
}

class ValidationException extends NeuralVaultException {
  ValidationException(String message) : super('Validation error: $message');
}
