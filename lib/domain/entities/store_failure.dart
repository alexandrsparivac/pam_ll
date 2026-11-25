class StoreFailure implements Exception {
  final String message;
  final int? statusCode;
  const StoreFailure(this.message, {this.statusCode});
  @override
  String toString() => message;
}
