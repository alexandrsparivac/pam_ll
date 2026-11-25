import 'dart:convert';

import '../../domain/entities/store_failure.dart';
import '../network/json_http_client.dart';

/// Runs the existing repository commands against local JSON, without HTTP.
class LocalStoreClient implements JsonHttpClient {
  final Map<String, dynamic> catalog;
  final Future<void> Function(Map<String, dynamic>)? save;
  final Map<String, Map<String, dynamic>> _products = {};
  late Map<String, dynamic> _state;
  int _sequence = 0;
  Future<void> _pending = Future.value();

  LocalStoreClient(
    this.catalog, {
    Map<String, dynamic>? savedState,
    this.save,
  }) {
    final home = catalog['homePage'] as Map;
    final detail = catalog['productPage']['product'] as Map<String, dynamic>;
    for (final raw in [
      ...home['featureProducts'],
      ...home['recommended'],
      ...detail['similarProducts'],
    ]) {
      final item = Map<String, dynamic>.from(raw as Map);
      _products.putIfAbsent(item['id'] as String, () => item);
    }
    final detailId = detail['id'] as String;
    _products[detailId] = {...?_products[detailId], ...detail};
    _state = savedState == null
        ? {
            'favoriteIds': [
              for (final p in _products.values)
                if (p['isFavorite'] == true ||
                    (p['actions'] as Map?)?['isFavorite'] == true)
                  p['id'],
            ],
            'reviews': {
              for (final p in _products.values) p['id']: p['reviews'] ?? [],
            },
            'profile': {'name': '', 'email': ''},
            'cart': [],
            'orders': [],
          }
        : _clone(savedState);
    // A catalog update can remove products referenced by a previous session.
    (_state['favoriteIds'] as List).removeWhere(
      (id) => !_products.containsKey(id),
    );
    (_state['cart'] as List).removeWhere(
      (line) => !_products.containsKey(line['productId']),
    );
    final reviews = _state['reviews'] as Map;
    reviews.removeWhere((id, _) => !_products.containsKey(id));
    for (final product in _products.values) {
      reviews.putIfAbsent(product['id'], () => product['reviews'] ?? []);
    }
  }

  static Map<String, dynamic> _clone(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  String _id() => '${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';
  Never _fail(String message) => throw StoreFailure(message);
  Map<String, dynamic> _product(String id) =>
      _products[id] ?? _fail('Product not found.');

  Map<String, dynamic> _cart(Map<String, dynamic> state) {
    final cents = <String, int>{};
    for (final line in state['cart'] as List) {
      final product = _product(line['productId'] as String);
      final currency = product['currency'] as String;
      cents[currency] =
          (cents[currency] ?? 0) +
          ((product['price'] as num) * 100).round() * (line['quantity'] as int);
    }
    return {
      'items': state['cart'],
      'totals': {
        for (final entry in cents.entries) entry.key: entry.value / 100,
      },
    };
  }

  void _variant(Map<String, dynamic> product, String color, String size) {
    final colors = product['availableColors'] as List? ?? [];
    final sizes = product['availableSizes'] as List? ?? [];
    if ((colors.isEmpty
            ? color.isNotEmpty
            : !colors.any((c) => c['id'] == color)) ||
        (sizes.isEmpty ? size.isNotEmpty : !sizes.contains(size)) ||
        (product['sizeAvailability'] as Map?)?[size] == false ||
        (product['actions'] as Map?)?['canAddToCart'] == false) {
      _fail('Choose an available product, color and size.');
    }
  }

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    // Serialize writes so a slow disk save cannot overwrite a newer change.
    final operation = _pending.then((_) => _request(method, path, body ?? {}));
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final parts = path.split('/').map(Uri.decodeComponent).toList();
    if (method == 'GET' && path == 'catalog') {
      return _clone({'catalog': catalog, ..._state, 'cart': _cart(_state)});
    }
    final next = _clone(_state);
    late Map<String, dynamic> result;
    if (parts.length == 2 &&
        parts.first == 'favorites' &&
        ['PUT', 'DELETE'].contains(method)) {
      _product(parts[1]);
      final favorites = Set<String>.from(next['favoriteIds'] as List);
      if (method == 'PUT') {
        favorites.add(parts[1]);
      } else {
        favorites.remove(parts[1]);
      }
      next['favoriteIds'] = favorites.toList();
      result = {'favoriteIds': next['favoriteIds']};
    } else if (parts.length >= 3 &&
        parts.first == 'products' &&
        parts[2] == 'reviews') {
      _product(parts[1]);
      final reviews = (next['reviews'] as Map).putIfAbsent(
        parts[1],
        () => <dynamic>[],
      ) as List;
      if (method == 'POST' && parts.length == 3) {
        final text = (body['text'] as String? ?? '').trim();
        final author = (body['author'] as String? ?? '').trim();
        final rating = body['rating'];
        if (text.isEmpty ||
            text.length > 2000 ||
            author.isEmpty ||
            rating is! int ||
            rating < 1 ||
            rating > 5) {
          _fail('Enter a name, review and rating from 1 to 5.');
        }
        final review = {
          ...body,
          'id': _id(),
          'text': text,
          'author': author,
          'isMine': true,
          'createdAtLabel': DateTime.now().toUtc().toIso8601String(),
        };
        reviews.insert(0, review);
        result = {'review': review};
      } else if (method == 'DELETE' && parts.length == 4) {
        final review = reviews.where((r) => r['id'] == parts[3]).firstOrNull;
        if (review == null) {
          _fail('Review not found.');
        }
        if (review['isMine'] != true) {
          _fail('Only your own reviews can be deleted.');
        }
        reviews.remove(review);
        result = {};
      } else {
        _fail('Unsupported review operation.');
      }
    } else if (method == 'POST' && path == 'cart/items') {
      final id = body['productId'] as String;
      final product = _product(id);
      final color = body['colorId'] as String? ?? '';
      final size = body['size'] as String? ?? '';
      final quantity = body['quantity'] ?? 1;
      if (quantity is! int || quantity < 1 || quantity > 99) {
        _fail('Quantity must be between 1 and 99.');
      }
      _variant(product, color, size);
      final cart = next['cart'] as List;
      final line = cart
          .where(
            (l) =>
                l['productId'] == id &&
                l['colorId'] == color &&
                l['size'] == size,
          )
          .firstOrNull;
      if (line == null) {
        cart.add({
          'id': _id(),
          'productId': id,
          'colorId': color,
          'size': size,
          'quantity': quantity,
        });
      } else {
        final updatedQuantity = (line['quantity'] as int) + quantity;
        if (updatedQuantity > 99) {
          _fail('Maximum quantity is 99.');
        }
        line['quantity'] = updatedQuantity;
      }
      result = {'cart': _cart(next)};
    } else if (parts.length == 3 &&
        parts[0] == 'cart' &&
        parts[1] == 'items' &&
        ['PUT', 'DELETE'].contains(method)) {
      final cart = next['cart'] as List;
      final line = cart.where((l) => l['id'] == parts[2]).firstOrNull;
      if (line == null) {
        _fail('Cart item not found.');
      }
      final quantity = method == 'DELETE' ? 0 : body['quantity'];
      if (quantity is! int || quantity < 0 || quantity > 99) {
        _fail('Quantity must be between 0 and 99.');
      }
      if (quantity == 0) {
        cart.remove(line);
      } else {
        line['quantity'] = quantity;
      }
      result = {'cart': _cart(next)};
    } else if (method == 'DELETE' && path == 'cart') {
      next['cart'] = [];
      result = {'cart': _cart(next)};
    } else if (method == 'PUT' && path == 'profile') {
      next['profile'] = {
        'name': (body['name'] as String).trim(),
        'email': (body['email'] as String).trim(),
      };
      result = {'profile': next['profile']};
    } else if (method == 'POST' && path == 'orders') {
      final orders = next['orders'] as List;
      final previous = orders
          .where((o) => o['requestId'] == body['requestId'])
          .firstOrNull;
      if (previous != null) {
        if (jsonEncode(previous['request']) != jsonEncode(body)) {
          _fail('This checkout ID was already used with different details.');
        }
        return _clone({'order': previous});
      }
      final cart = _cart(next);
      final totals = cart['totals'] as Map;
      if ((cart['items'] as List).isEmpty) {
        _fail('Your cart is empty.');
      }
      if (totals.length != 1) {
        _fail('An order must use a single currency.');
      }
      final items = <Map<String, dynamic>>[];
      for (final line in cart['items'] as List) {
        final product = _product(line['productId'] as String);
        _variant(product, line['colorId'] as String, line['size'] as String);
        final colors = product['availableColors'] as List? ?? [];
        final color = colors
            .where((c) => c['id'] == line['colorId'])
            .firstOrNull;
        items.add({
          'productId': product['id'],
          'name': product['name'],
          'unitPrice': product['price'],
          'quantity': line['quantity'],
          'colorName': color == null ? '' : color['name'],
          'size': line['size'],
        });
      }
      final order = {
        ...body,
        'id': _id(),
        'request': body,
        'status': 'placed',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'currency': totals.keys.single,
        'total': totals.values.single,
        'items': items,
        'paymentMethod': 'pay_on_delivery',
      };
      orders.insert(0, order);
      next['cart'] = [];
      result = {'order': order};
    } else if (method == 'POST' &&
        parts.length == 3 &&
        parts.first == 'orders' &&
        parts.last == 'cancel') {
      final order = (next['orders'] as List)
          .where((o) => o['id'] == parts[1])
          .firstOrNull;
      if (order == null) {
        _fail('Order not found.');
      }
      if (!['placed', 'cancelled'].contains(order['status'])) {
        _fail('This order can no longer be cancelled.');
      }
      order['status'] = 'cancelled';
      result = {'order': order};
    } else {
      _fail('Unsupported local operation.');
    }
    try {
      await save?.call(_clone(next));
    } catch (_) {
      _fail('Could not save your changes on this device.');
    }
    _state = next;
    return _clone(result);
  }
}
