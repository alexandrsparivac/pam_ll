import '../../domain/entities/store_failure.dart';
import '../models/json_fields.dart';
import '../network/json_http_client.dart';
import 'store_remote_data_source.dart';

/// Public feeds supply the catalog; the local service stores user changes.
class FeedStoreRemoteDataSource extends StoreRemoteDataSource {
  final JsonHttpClient feedClient;
  final JsonHttpClient stateClient;
  final Future<Map<String, dynamic>> Function()? loadDescriptions;

  const FeedStoreRemoteDataSource({
    required this.feedClient,
    required this.stateClient,
    this.loadDescriptions,
  }) : super(stateClient);

  Future<Map<String, dynamic>> _savedState() async {
    try {
      return await stateClient
          .request('GET', 'catalog')
          .timeout(const Duration(seconds: 3), onTimeout: () => {});
    } on StoreFailure {
      // Viewing the public catalog does not require the local demo service.
      return {};
    }
  }

  @override
  Future<Map<String, dynamic>> getCatalog() async {
    final responses = await Future.wait([
      feedClient.request('GET', 'feed'),
      feedClient.request('GET', 'feed/details'),
      _savedState(),
      loadDescriptions?.call() ?? Future.value(<String, dynamic>{}),
    ]);
    final descriptions = responses[3];
    Map<String, dynamic> withDescription(dynamic raw) {
      final item = jsonObject(raw, 'product');
      final description = jsonString(item['description'], 'description');
      return {
        ...item,
        if (description.trim().isEmpty && descriptions.containsKey(item['id']))
          'description': jsonString(descriptions[item['id']], 'description'),
      };
    }

    final home = {
      ...responses[0],
      for (final section in ['featureProducts', 'recommended'])
        section: jsonList(
          responses[0][section],
          section,
        ).map(withDescription).toList(),
    };
    final detailProduct = withDescription(responses[1]['product']);
    final details = {
      ...responses[1],
      'product': {
        ...detailProduct,
        'similarProducts': jsonList(
          detailProduct['similarProducts'],
          'similarProducts',
        ).map(withDescription).toList(),
      },
    };
    final saved = responses[2];
    final product = jsonObject(details['product'], 'product');
    final products = <String, Map<String, dynamic>>{};
    for (final raw in [
      ...jsonList(home['featureProducts'], 'featureProducts'),
      ...jsonList(home['recommended'], 'recommended'),
      ...jsonList(product['similarProducts'], 'similarProducts'),
      product,
    ]) {
      final item = jsonObject(raw, 'product');
      products[jsonString(item['id'], 'product.id', required: true)] = item;
    }
    final seedFavorites = [
      for (final entry in products.entries)
        if (entry.value['isFavorite'] == true ||
            (entry.value['actions'] as Map?)?['isFavorite'] == true)
          entry.key,
    ];
    final savedReviews = jsonObject(saved['reviews'] ?? {}, 'reviews');
    final reviews = <String, dynamic>{};
    for (final entry in products.entries) {
      final byId = <String, dynamic>{};
      for (final raw in [
        ...jsonList(entry.value['reviews'], 'reviews'),
        ...jsonList(
          savedReviews[entry.key],
          'savedReviews',
        ).where((review) => (review as Map)['isMine'] == true),
      ]) {
        final review = jsonObject(raw, 'review');
        byId[jsonString(review['id'], 'review.id', required: true)] = review;
      }
      reviews[entry.key] = byId.values.toList();
    }
    final savedCart = jsonObject(saved['cart'] ?? {}, 'cart');
    final cartItems = jsonList(savedCart['items'], 'cart.items')
        .where((line) => products.containsKey((line as Map)['productId']))
        .toList();
    final totals = <String, double>{};
    for (final raw in cartItems) {
      final line = jsonObject(raw, 'cart.item');
      final item = products[line['productId']]!;
      final currency = jsonString(item['currency'], 'currency');
      totals[currency] =
          (totals[currency] ?? 0) +
          jsonNumber(item['price'], 'price') *
              jsonInteger(line['quantity'], 'quantity');
    }
    return {
      'catalog': {'homePage': home, 'productPage': details},
      'favoriteIds': [
        for (final id in jsonList(
          saved['favoriteIds'] ?? seedFavorites,
          'favoriteIds',
        ))
          if (products.containsKey(id)) id,
      ],
      'reviews': reviews,
      'profile': saved['profile'] ?? {},
      'cart': {'items': cartItems, 'totals': totals},
      'orders': saved['orders'] ?? [],
    };
  }
}
