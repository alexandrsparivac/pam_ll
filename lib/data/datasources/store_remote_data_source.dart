import '../network/json_http_client.dart';

class StoreRemoteDataSource {
  final JsonHttpClient _client;
  const StoreRemoteDataSource(this._client);
  Future<Map<String, dynamic>> getCatalog() =>
      _client.request('GET', 'catalog');
  Future<Map<String, dynamic>> setFavorite(String productId, bool selected) =>
      _client.request(
        selected ? 'PUT' : 'DELETE',
        'favorites/${Uri.encodeComponent(productId)}',
      );
  Future<Map<String, dynamic>> addReview(
    String productId,
    Map<String, dynamic> review,
  ) => _client.request(
    'POST',
    'products/${Uri.encodeComponent(productId)}/reviews',
    body: review,
  );
  Future<void> deleteReview(String productId, String reviewId) async {
    await _client.request(
      'DELETE',
      'products/${Uri.encodeComponent(productId)}/reviews/${Uri.encodeComponent(reviewId)}',
    );
  }

  Future<Map<String, dynamic>> addCartItem(Map<String, dynamic> body) =>
      _client.request('POST', 'cart/items', body: body);
  Future<Map<String, dynamic>> changeCartQuantity(String id, int quantity) =>
      _client.request(
        quantity == 0 ? 'DELETE' : 'PUT',
        'cart/items/${Uri.encodeComponent(id)}',
        body: quantity == 0 ? null : {'quantity': quantity},
      );
  Future<Map<String, dynamic>> clearCart() => _client.request('DELETE', 'cart');
  Future<Map<String, dynamic>> saveProfile(Map<String, dynamic> body) =>
      _client.request('PUT', 'profile', body: body);
  Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> body) =>
      _client.request('POST', 'orders', body: body);
  Future<Map<String, dynamic>> cancelOrder(String id) => _client.request(
    'POST',
    'orders/${Uri.encodeComponent(id)}/cancel',
    body: {},
  );
}
