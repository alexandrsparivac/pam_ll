import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/store_failure.dart';
import '../network/json_http_client.dart';
import 'local_store_client.dart';
import 'state_storage.dart';

class AssetStoreClient implements JsonHttpClient {
  Future<LocalStoreClient>? _client;

  Future<LocalStoreClient> _open() async {
    try {
      final catalog = jsonDecode(
        await rootBundle.loadString('assets/data/gemstore_data.json'),
      ) as Map<String, dynamic>;
      return LocalStoreClient(
        catalog,
        savedState: await readLocalState(),
        save: writeLocalState,
      );
    } catch (_) {
      throw const StoreFailure(
        'Could not load the local catalog or saved data.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final pending = _client ??= _open();
    late LocalStoreClient client;
    try {
      client = await pending;
    } catch (_) {
      _client = null;
      rethrow;
    }
    return client.request(method, path, body: body);
  }
}
