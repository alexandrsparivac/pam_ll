import 'dart:convert';

import '../domain/usecases/commerce_usecases.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../data/network/http_json_client.dart';
import '../data/datasources/feed_store_remote_data_source.dart';
import '../data/repositories/store_repository_impl.dart';
import '../domain/usecases/store_usecases.dart';
import '../presentation/cubit/gem_store_cubit.dart';

GemStoreCubit createGemStoreCubit() {
  const configured = String.fromEnvironment('API_BASE_URL');
  final baseUrl = configured.isNotEmpty
      ? configured
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8888/api'
      : 'http://localhost:8888/api';
  final client = http.Client();
  final api = HttpJsonClient(client: client, baseUrl: baseUrl);
  const feedBaseUrl = String.fromEnvironment(
    'FEED_BASE_URL',
    defaultValue: 'https://test-api-jlbn.onrender.com/lab2026/v1/',
  );
  final feedApi = HttpJsonClient(
    client: client,
    baseUrl: feedBaseUrl,
    timeout: const Duration(seconds: 60),
  );
  final repository = StoreRepositoryImpl(
    FeedStoreRemoteDataSource(
      feedClient: feedApi,
      stateClient: api,
      loadDescriptions: () async => jsonDecode(
        await rootBundle.loadString('assets/data/product_descriptions.json'),
      ) as Map<String, dynamic>,
    ),
  );
  return GemStoreCubit(
    getStore: GetStore(repository),
    setFavorite: SetFavorite(repository),
    addReview: AddReview(repository),
    deleteReview: DeleteReview(repository),
    manageCart: ManageCart(repository),
    saveProfile: SaveProfile(repository),
    placeOrder: PlaceOrder(repository),
    cancelOrder: CancelOrder(repository),
    onClose: client.close,
  );
}
