abstract interface class JsonHttpClient {
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  });
}
