import 'package:pam_ll2_http/domain/entities/commerce.dart';
import 'package:pam_ll2_http/domain/usecases/commerce_usecases.dart';

import 'dart:convert';
import 'dart:io';

import 'package:pam_ll2_http/data/network/json_http_client.dart';
import 'package:pam_ll2_http/data/datasources/store_remote_data_source.dart';
import 'package:pam_ll2_http/data/datasources/feed_store_remote_data_source.dart';
import 'package:pam_ll2_http/data/repositories/store_repository_impl.dart';
import 'package:pam_ll2_http/data/models/product_dto.dart';
import 'package:pam_ll2_http/data/models/store_snapshot_dto.dart';
import 'package:pam_ll2_http/data/models/review_dto.dart';
import 'package:pam_ll2_http/domain/entities/review.dart';
import 'package:pam_ll2_http/domain/entities/store_failure.dart';
import 'package:pam_ll2_http/domain/usecases/store_usecases.dart';

/// Contract transport: no sockets or Flutter packages are needed by these checks.
class ContractTransport implements JsonHttpClient {
  final Map<String, dynamic> catalog;
  final Set<String> favorites = {};
  final Map<String, List<Map<String, dynamic>>> reviews = {};
  final List<String> calls = [];
  bool fail = false;
  bool malformed = false;
  ContractTransport(this.catalog);

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add('$method $path');
    if (fail) throw const StoreFailure('Offline');
    if (malformed) return {'catalog': []};
    if (method == 'GET' && path == 'catalog') {
      return {
        'catalog': catalog,
        'favoriteIds': favorites.toList(),
        'reviews': reviews,
      };
    }
    final parts = path.split('/').map(Uri.decodeComponent).toList();
    if (parts.first == 'favorites') {
      if (method == 'PUT') favorites.add(parts[1]);
      if (method == 'DELETE') favorites.remove(parts[1]);
      return {'favoriteIds': favorites.toList()};
    }
    if (method == 'POST') {
      final value = {
        'id': 'new-${calls.length}',
        ...body!,
        'createdAtLabel': 'now',
        'isMine': true,
      };
      reviews.putIfAbsent(parts[1], () => []).insert(0, value);
      return {'review': value};
    }
    if (method == 'DELETE') {
      reviews[parts[1]]?.removeWhere((review) => review['id'] == parts[3]);
      return {};
    }
    throw StateError('Unexpected contract call: $method $path');
  }
}

class ResponseTransport implements JsonHttpClient {
  Map<String, dynamic> response = {};
  String method = '';
  String path = '';
  Map<String, dynamic>? body;
  int calls = 0;
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls++;
    this.method = method;
    this.path = path;
    this.body = body;
    return response;
  }
}

class FeedTransport implements JsonHttpClient {
  final Map<String, dynamic> catalog;
  final List<String> calls = [];
  bool fail = false;
  FeedTransport(this.catalog);

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add('$method $path');
    if (fail) throw const StoreFailure('Feed unavailable');
    if (method == 'GET' && path == 'feed') return catalog['homePage'];
    if (method == 'GET' && path == 'feed/details') {
      return catalog['productPage'];
    }
    throw StateError('Unexpected feed endpoint: $method $path');
  }
}

Future<void> runSelfChecks() async {
  var count = 0;
  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
    count++;
  }

  Future<void> failure(Future<void> Function() action) async {
    try {
      await action();
    } on StoreFailure {
      count++;
      return;
    }
    throw StateError('Expected a StoreFailure');
  }

  final raw = jsonDecode(
    await File('test/fixtures/api_catalog.json').readAsString(),
  ) as Map<String, dynamic>;
  final transport = ContractTransport(raw);
  final feedRaw = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  for (final item in [
    ...feedRaw['homePage']['featureProducts'],
    ...feedRaw['homePage']['recommended'],
    ...feedRaw['productPage']['product']['similarProducts'],
  ]) {
    (item as Map).remove('description');
  }
  final descriptions = jsonDecode(
    await File('assets/data/product_descriptions.json').readAsString(),
  ) as Map<String, dynamic>;
  final publicFeed = FeedTransport(feedRaw);
  final localState = ContractTransport(raw)..fail = true;
  final feedRepository = StoreRepositoryImpl(
    FeedStoreRemoteDataSource(
      feedClient: publicFeed,
      stateClient: localState,
      loadDescriptions: () async => descriptions,
    ),
  );
  final feedSnapshot = await feedRepository.loadStore();
  check(
    feedSnapshot.homeData.catalog.every((p) => p.description.trim().isNotEmpty),
    'Every feed product must have a description when the API omits it',
  );
  check(
    feedSnapshot.homeData.catalog
            .singleWhere((p) => p.id == 'p003')
            .description ==
        feedRaw['productPage']['product']['description'],
    'The description from the API must take precedence',
  );
  check(
    publicFeed.calls.join(',') == 'GET feed,GET feed/details',
    'Both public feed endpoints must be requested',
  );
  check(
    feedSnapshot.homeData.featureProducts.length == 3 &&
        feedSnapshot.homeData.recommendedProducts.length == 2 &&
        feedSnapshot.homeData.catalog.length == 8,
    'Public feed sections lost or extra products added',
  );
  check(
    feedSnapshot.favoriteIds.single == 'p003' &&
        feedSnapshot.reviewsByProduct['p003']!.length == 2,
    'Public feed favorites and reviews must work without a local server',
  );
  check(
    feedSnapshot.homeData.featureProducts.every((p) => p.category == 'Women'),
    'Feed products must remain visible in the selected category',
  );
  localState.fail = false;
  localState.favorites.add('p001');
  localState.reviews['p003'] = [];
  final restoredFeed = await feedRepository.loadStore();
  check(
    restoredFeed.favoriteIds.single == 'p001' &&
        restoredFeed.reviewsByProduct['p003']!.length == 2,
    'Saved favorites should survive and empty saved reviews must not hide feed reviews',
  );
  publicFeed.fail = true;
  await failure(() async => feedRepository.loadStore());
  final repository = StoreRepositoryImpl(StoreRemoteDataSource(transport));
  final getStore = GetStore(repository);
  final setFavorite = SetFavorite(repository);
  final addReview = AddReview(repository);
  final deleteReview = DeleteReview(repository);
  final first = await getStore();
  check(
    transport.calls.single == 'GET catalog',
    'Catalog must be requested through HTTP boundary',
  );
  check(first.homeData.catalog.length == 8, 'Expected 8 JSON products');
  check(
    first.homeData.storeName == raw['homePage']['storeName'],
    'Store name changed',
  );
  final product = first.homeData.catalog.singleWhere((p) => p.id == 'p003');
  check(
    product.colors.length == 3 && product.sizes.length == 3,
    'Typed options lost',
  );
  check(
    product.sizeAvailability['S'] == false,
    'Unavailable size became available',
  );
  check(
    product.similarProductIds.join(',') == 'p006,p007,p008',
    'Related IDs lost',
  );
  check(
    product.imageUrl == raw['productPage']['product']['mainImageUrl'],
    'Detail image changed',
  );
  final ordinary = first.homeData.catalog.singleWhere((p) => p.id == 'p001');
  check(
    ordinary.sizes.isEmpty && ordinary.colors.isEmpty,
    'Options were invented',
  );
  for (final value in first.homeData.catalog) {
    final decoded = ProductDto.fromJson(
      jsonDecode(jsonEncode(ProductDto(value).toJson()))
          as Map<String, dynamic>,
    ).entity;
    check(
      decoded.id == value.id &&
          decoded.price == value.price &&
          decoded.currency == value.currency &&
          decoded.sizes.length == value.sizes.length &&
          decoded.rating == value.rating,
      'Product JSON roundtrip failed',
    );
    final imageUri = Uri.tryParse(value.imageUrl);
    check(
      (imageUri != null &&
              imageUri.scheme == 'https' &&
              imageUri.host.isNotEmpty) ||
          File(value.imageUrl).existsSync(),
      'Missing product image or invalid remote URL',
    );
  }
  final favorites = await setFavorite('p001', true);
  check(
    favorites.contains('p001') && transport.calls.last == 'PUT favorites/p001',
    'Favorite PUT missing',
  );
  check(
    (await getStore()).favoriteIds.contains('p001'),
    'Server favorites not loaded',
  );
  check(
    !(await setFavorite('p001', false)).contains('p001') &&
        transport.calls.last == 'DELETE favorites/p001',
    'Favorite DELETE missing',
  );
  final review = await addReview(
    const NewReview(
      productId: 'p001',
      author: ' Valentin ',
      content: ' Good ',
      rating: 5,
    ),
  );
  check(
    review.id.isNotEmpty &&
        review.name == 'Valentin' &&
        review.content == 'Good' &&
        review.isMine,
    'Review response not deserialized',
  );
  check(
    transport.calls.last == 'POST products/p001/reviews',
    'Review POST missing',
  );
  check(
    ReviewDto.fromJson(ReviewDto(review).toJson()).entity.rating == 5,
    'Review serialization failed',
  );
  check(
    (await getStore()).reviewsByProduct['p001']!.single.id == review.id,
    'Saved review absent after reload',
  );
  await deleteReview('p001', review.id);
  check(
    transport.calls.last == 'DELETE products/p001/reviews/${review.id}',
    'Review DELETE missing',
  );
  check(
    (await getStore()).reviewsByProduct['p001']!.isEmpty,
    'Deleted review still present',
  );
  final callsBeforeInvalid = transport.calls.length;
  await failure(() async {
    await addReview(
      const NewReview(
        productId: 'p001',
        author: '',
        content: 'Invalid',
        rating: 6,
      ),
    );
  });
  check(
    transport.calls.length == callsBeforeInvalid,
    'Invalid review reached HTTP',
  );
  transport.fail = true;
  await failure(() async {
    await getStore();
  });
  transport.fail = false;
  transport.malformed = true;
  await failure(() async {
    await getStore();
  });
  final empty = StoreSnapshotDto.fromJson({
    'catalog': {'homePage': {}},
    'favoriteIds': [],
  }).entity;
  check(empty.homeData.catalog.isEmpty, 'Empty server catalog mishandled');
  final responses = ResponseTransport();
  final commerceRepository = StoreRepositoryImpl(
    StoreRemoteDataSource(responses),
  );
  final cartUseCase = ManageCart(commerceRepository);
  responses.response = {
    'cart': {
      'items': [
        {
          'id': 'line1',
          'productId': 'p001',
          'quantity': 2,
          'colorId': '',
          'size': '',
        },
      ],
      'totals': {'USD': 79.98},
    },
  };
  final cart = await cartUseCase.add('p001', quantity: 2);
  check(
    cart.items.single.quantity == 2 && cart.totals['USD'] == 79.98,
    'Cart response deserialization failed',
  );
  check(
    responses.method == 'POST' &&
        responses.path == 'cart/items' &&
        responses.body?['quantity'] == 2,
    'Cart request serialization failed',
  );
  await cartUseCase.change('line1', 3);
  check(
    responses.method == 'PUT' &&
        responses.path == 'cart/items/line1' &&
        responses.body?['quantity'] == 3,
    'Cart update request failed',
  );
  responses.response = {
    'cart': {'items': [], 'totals': {}},
  };
  check(
    (await cartUseCase.change('line1', 0)).items.isEmpty &&
        responses.method == 'DELETE',
    'Cart delete request failed',
  );
  await cartUseCase.clear();
  check(
    responses.path == 'cart' && responses.method == 'DELETE',
    'Cart clear request failed',
  );
  await failure(() async {
    await cartUseCase.add('p001', quantity: 100);
  });
  responses.response = {
    'profile': {'name': 'Valentin', 'email': 'test@example.com'},
  };
  final profile = await SaveProfile(commerceRepository)(
    const CustomerProfile(name: ' Valentin ', email: 'test@example.com'),
  );
  check(
    profile.name == 'Valentin' &&
        responses.path == 'profile' &&
        responses.method == 'PUT' &&
        responses.body?['name'] == 'Valentin',
    'Profile request/response failed',
  );
  await failure(() async {
    await SaveProfile(commerceRepository)(
      const CustomerProfile(name: 'V', email: 'invalid'),
    );
  });
  final orderJson = <String, dynamic>{
    'id': 'order1',
    'status': 'placed',
    'createdAt': '2026-11-23T12:00:00Z',
    'currency': 'USD',
    'total': 79.98,
    'customerName': 'Valentin',
    'email': 'test@example.com',
    'phone': '+37369123456',
    'address': 'Chisinau, strada Test 10',
    'items': [
      {
        'productId': 'p001',
        'name': 'Turtleneck Sweater',
        'unitPrice': 39.99,
        'quantity': 2,
        'colorName': '',
        'size': '',
      },
    ],
  };
  responses.response = {'order': orderJson};
  final order = await PlaceOrder(commerceRepository)(
    const OrderDraft(
      requestId: 'checkout-123',
      customerName: 'Valentin',
      email: 'test@example.com',
      phone: '+37369123456',
      address: 'Chisinau, strada Test 10',
    ),
  );
  check(
    order.items.single.quantity == 2 &&
        order.total == 79.98 &&
        order.status == 'placed',
    'Order response failed',
  );
  check(
    responses.method == 'POST' &&
        responses.path == 'orders' &&
        responses.body?['requestId'] == 'checkout-123' &&
        !responses.body!.containsKey('total'),
    'Order request must not submit client prices',
  );
  responses.response = {
    'order': {...orderJson, 'status': 'cancelled'},
  };
  check(
    (await CancelOrder(commerceRepository)('order1')).status == 'cancelled' &&
        responses.path == 'orders/order1/cancel',
    'Cancellation request failed',
  );
  await failure(() async {
    await PlaceOrder(commerceRepository)(
      const OrderDraft(
        requestId: 'checkout-123',
        customerName: 'V',
        email: 'bad',
        phone: '12',
        address: 'short',
      ),
    );
  });
  stdout.writeln(
    'PASS: $count domain, DTO serialization and repository contract checks (in-memory transport).',
  );
}

Future<void> main() => runSelfChecks();
