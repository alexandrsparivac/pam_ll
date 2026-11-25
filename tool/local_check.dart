import 'dart:convert';
import 'dart:io';

import 'package:pam_ll2_http/data/local/local_store_client.dart';
import 'package:pam_ll2_http/data/datasources/store_remote_data_source.dart';
import 'package:pam_ll2_http/data/repositories/store_repository_impl.dart';
import 'package:pam_ll2_http/domain/entities/commerce.dart';
import 'package:pam_ll2_http/domain/entities/review.dart';
import 'package:pam_ll2_http/domain/entities/store_failure.dart';
import 'package:pam_ll2_http/domain/usecases/commerce_usecases.dart';
import 'package:pam_ll2_http/domain/usecases/store_usecases.dart';

Future<void> main() async {
  var checks = 0;
  void check(bool valid, String message) {
    if (!valid) {
      throw StateError(message);
    }
    checks++;
  }

  Future<void> rejects(Future<void> Function() action) async {
    try {
      await action();
    } on StoreFailure {
      checks++;
      return;
    }
    throw StateError('Expected a validation failure');
  }

  final catalog = jsonDecode(
    await File('assets/data/gemstore_data.json').readAsString(),
  ) as Map<String, dynamic>;
  final temp = await Directory.systemTemp.createTemp('gemstore_json_check_');
  try {
    final file = File('${temp.path}/state.json');
    final local = LocalStoreClient(
      catalog,
      save: (state) async {
        await file.writeAsString(jsonEncode(state));
      },
    );
    final repository = StoreRepositoryImpl(StoreRemoteDataSource(local));
    final initial = await GetStore(repository)();
    check(
      initial.homeData.catalog.length == 16,
      'All sixteen pam_ll-main products must load from JSON',
    );
    check(
      initial.reviewsByProduct['p003']!.length == 2,
      'Seed reviews missing',
    );
    check(
      initial.homeData.catalog.every((p) => p.description.isNotEmpty),
      'Descriptions missing',
    );
    check(
      initial.homeData.catalog.map((p) => p.id).toSet().containsAll({
            'p009',
            'p010',
            'p011',
            'p013',
            'p014',
            'p015',
            'p016',
            'p017',
            'p018',
          }) &&
          !initial.homeData.catalog.any((p) => p.id == 'p005'),
      'The catalog must use pam_ll-main products instead of the old API set',
    );
    check(
      initial.homeData.catalog.singleWhere((p) => p.id == 'p010').category ==
              'Accessories' &&
          initial.homeData.catalog
                  .singleWhere((p) => p.id == 'p014')
                  .category ==
              'Beauty',
      'Source categories lost',
    );
    void checkImages(dynamic value) {
      if (value is Map) {
        for (final entry in value.entries) {
          // Category icons are rendered by the UI, not loaded as images.
          if (entry.key == 'iconUrl') continue;
          checkImages(entry.value);
        }
      } else if (value is List) {
        for (final item in value) {
          checkImages(item);
        }
      } else if (value is String && value.startsWith('photos/')) {
        check(File(value).existsSync(), 'Missing local photo: $value');
      } else if (value is String && value.startsWith('http')) {
        throw StateError('The catalog must use local photos: $value');
      }
    }

    checkImages(catalog);
    final migrated = StoreRepositoryImpl(
      StoreRemoteDataSource(
        LocalStoreClient(
          catalog,
          savedState: {
            'favoriteIds': ['p001', 'p005'],
            'reviews': {'p005': []},
            'profile': {'name': 'Existing user', 'email': ''},
            'cart': [
              {
                'id': 'old',
                'productId': 'p005',
                'quantity': 1,
                'colorId': '',
                'size': '',
              },
              {
                'id': 'kept',
                'productId': 'p010',
                'quantity': 1,
                'colorId': '',
                'size': '',
              },
            ],
            'orders': [],
          },
        ),
      ),
    );
    final migratedSnapshot = await GetStore(migrated)();
    check(
      migratedSnapshot.favoriteIds.length == 1 &&
          migratedSnapshot.favoriteIds.contains('p001') &&
          migratedSnapshot.cart.items.single.productId == 'p010' &&
          migratedSnapshot.cart.totals['USD'] == 120 &&
          migratedSnapshot.profile.name == 'Existing user' &&
          migratedSnapshot.reviewsByProduct['p003']!.length == 2,
      'Catalog updates must remove stale references and preserve valid saved data',
    );
    await SetFavorite(repository)('p001', true);
    check(
      (await GetStore(repository)()).favoriteIds.contains('p001'),
      'Favorite not saved',
    );
    await SaveProfile(repository)(
      const CustomerProfile(name: 'Local Test', email: 'local@example.com'),
    );
    check(
      (await GetStore(repository)()).profile.name == 'Local Test',
      'Profile not saved',
    );
    final review = await AddReview(repository)(
      const NewReview(
        productId: 'p001',
        author: 'Local Test',
        content: 'Good product',
        rating: 4,
      ),
    );
    check(
      (await GetStore(repository)()).reviewsByProduct['p001']!.single.id ==
          review.id,
      'Review missing',
    );
    await DeleteReview(repository)('p001', review.id);
    check(
      (await GetStore(repository)()).reviewsByProduct['p001']!.isEmpty,
      'Review not deleted',
    );
    await rejects(() async => DeleteReview(repository)('p003', 'r001'));
    await rejects(
      () async =>
          ManageCart(repository).add('p003', colorId: 'beige', size: 'S'),
    );
    final cart = await ManageCart(repository)
        .add('p003', colorId: 'beige', size: 'L', quantity: 2);
    check(cart.totals['USD'] == 160, 'Wrong variant cart total');
    final changed = await ManageCart(repository)
        .change(cart.items.single.id, 1);
    check(changed.totals['USD'] == 80, 'Wrong changed cart total');
    await ManageCart(repository).clear();
    final merged = await ManageCart(repository).add('p001');
    await ManageCart(repository).add('p001');
    check(
      (await GetStore(repository)()).cart.items.single.quantity == 2,
      'Matching variants should merge',
    );
    await rejects(() async => ManageCart(repository).add('p001', quantity: 99));
    final removed = await ManageCart(repository)
        .change(merged.items.single.id, 0);
    check(
      removed.items.isEmpty && removed.totals.isEmpty,
      'Cart removal failed',
    );
    await ManageCart(repository).add('p001', quantity: 3);
    check(
      (await GetStore(repository)()).cart.totals['USD'] == 119.97,
      'Money rounding failed',
    );
    const draft = OrderDraft(
      requestId: 'local-checkout-001',
      customerName: 'Local Test',
      email: 'local@example.com',
      phone: '+37360000000',
      address: 'Chisinau, Test street 1',
    );
    final order = await PlaceOrder(repository)(draft);
    check(
      order.total == 119.97 && order.items.single.quantity == 3,
      'Order details incorrect',
    );
    check(
      (await GetStore(repository)()).cart.items.isEmpty,
      'Checkout must empty cart',
    );
    final duplicate = await PlaceOrder(repository)(draft);
    check(
      duplicate.id == order.id &&
          (await GetStore(repository)()).orders.length == 1,
      'Checkout duplicated',
    );
    check(
      (await CancelOrder(repository)(order.id)).status == 'cancelled',
      'Cancellation failed',
    );
    final saved = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final restored = StoreRepositoryImpl(
      StoreRemoteDataSource(LocalStoreClient(catalog, savedState: saved)),
    );
    final snapshot = await GetStore(restored)();
    check(
      snapshot.favoriteIds.contains('p001') &&
          snapshot.profile.name == 'Local Test' &&
          snapshot.orders.single.status == 'cancelled',
      'Restart did not restore local data',
    );
    final failing = LocalStoreClient(
      catalog,
      save: (_) async => throw const FileSystemException('Disk unavailable'),
    );
    await rejects(() async => failing.request('PUT', 'favorites/p001'));
    check(
      !((await failing.request('GET', 'catalog'))['favoriteIds'] as List)
          .contains('p001'),
      'Failed disk write changed memory',
    );
    stdout.writeln(
      'PASS: $checks local JSON checks, including persistence, variants, totals, reviews, profile, orders and failed writes.',
    );
  } finally {
    await temp.delete(recursive: true);
  }
}
