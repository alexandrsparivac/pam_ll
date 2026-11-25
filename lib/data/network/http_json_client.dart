import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/store_failure.dart';
import 'json_http_client.dart';

class HttpJsonClient implements JsonHttpClient {
  final http.Client _client;
  final Uri _baseUri;
  final Duration timeout;
  HttpJsonClient({
    required this._client,
    required String baseUrl,
    this.timeout = const Duration(seconds: 12),
  }) : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/') {
    if (!['http', 'https'].contains(_baseUri.scheme) ||
        _baseUri.host.isEmpty ||
        _baseUri.hasQuery ||
        _baseUri.hasFragment ||
        _baseUri.userInfo.isNotEmpty) {
      throw ArgumentError('API_BASE_URL must be an HTTP(S) base URL.');
    }
  }

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final request = http.Request(method, _baseUri.resolve(path));
      request.headers['Accept'] = 'application/json';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        request.body = jsonEncode(body);
      }
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      final successful =
          response.statusCode >= 200 && response.statusCode < 300;
      Map<String, dynamic>? decoded;
      if (response.bodyBytes.isNotEmpty) {
        try {
          final value = jsonDecode(utf8.decode(response.bodyBytes));
          if (value is Map<String, dynamic>) decoded = value;
        } on FormatException {
          // Error responses may be non-JSON (for example a reverse proxy).
        }
      }
      if (!successful) {
        final message = decoded?['error'];
        throw StoreFailure(
          message is String
              ? message
              : 'Server returned HTTP ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode == 204) return {};
      if (decoded == null) {
        throw const StoreFailure('The server returned invalid JSON.');
      }
      return decoded;
    } on TimeoutException {
      throw const StoreFailure(
        'The server took too long to respond. Try again.',
      );
    } on http.ClientException {
      throw const StoreFailure(
        'Cannot connect to the server. Check the connection and try again.',
      );
    }
  }
}
