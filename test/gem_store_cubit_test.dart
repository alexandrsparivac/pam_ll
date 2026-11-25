import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pam_ll2_http/presentation/cubit/gem_store_cubit.dart';
import 'package:pam_ll2_http/presentation/cubit/gem_store_state.dart';

import 'fake_repository.dart';

void main() {
  late FakeRepository repository;
  late GemStoreCubit cubit;
  GemStoreSuccess current() => cubit.state as GemStoreSuccess;
  setUp(() {
    repository = FakeRepository();
    cubit = cubitFor(repository);
  });
  tearDown(() async {
    await cubit.close();
  });

  test('loading success and the initially selected category', () async {
    final states = <GemStoreState>[];
    final subscription = cubit.stream.listen(states.add);
    await cubit.loadData();
    await Future<void>.delayed(Duration.zero);
    expect(states.first, isA<GemStoreLoading>());
    expect(current().displayedProducts.single.id, 'w');
    await subscription.cancel();
  });
  test('loading failure supports retry', () async {
    repository.offline = true;
    await cubit.loadData();
    expect(cubit.state, isA<GemStoreError>());
    repository.offline = false;
    await cubit.loadData();
    expect(cubit.state, isA<GemStoreSuccess>());
  });
  test(
    'empty results recover without losing remote favorites, cart or profile',
    () async {
      await cubit.loadData();
      await cubit.toggleFavorite('w');
      await cubit.addToCart('w');
      await cubit.updateProfile(name: 'Valentin', email: 'test@example.com');
      cubit.searchProducts('nothing');
      expect(cubit.state, isA<GemStoreEmpty>());
      cubit.clearFilters();
      expect(current().displayedProducts.length, 2);
      expect(current().favoriteIds, contains('w'));
      expect(current().cartQuantities, {'w': 1});
      expect(current().profileName, 'Valentin');
    },
  );
  test('search and category combine; typing spaces are preserved', () async {
    await cubit.loadData();
    cubit.searchProducts('Soft ');
    expect(current().searchQuery, 'Soft ');
    cubit.selectCategory('Men');
    expect(cubit.state, isA<GemStoreEmpty>());
    cubit.searchProducts('shirt');
    expect(current().displayedProducts.single.id, 'm');
  });
  test('numeric and alphabetical sort', () async {
    await cubit.loadData();
    cubit.clearFilters();
    cubit.sortProducts('Price: Low -> High');
    expect(current().displayedProducts.first.id, 'm');
    cubit.sortProducts('Price: High -> Low');
    expect(current().displayedProducts.first.id, 'w');
    cubit.sortProducts('Name: A -> Z');
    expect(current().displayedProducts.first.id, 'm');
  });
  test(
    'mutation failure keeps loaded data and reports the server error',
    () async {
      await cubit.loadData();
      repository.failMutation = true;
      await cubit.toggleFavorite('w');
      expect(current().favoriteIds, isEmpty);
      expect(current().operationError, 'Offline');
      expect(current().isUpdating, isFalse);
      repository.failMutation = false;
      await cubit.toggleFavorite('w');
      expect(current().favoriteIds, contains('w'));
      expect(current().operationError, isNull);
    },
  );
  test('rapid favorite toggles are serialized', () async {
    await cubit.loadData();
    await Future.wait([cubit.toggleFavorite('w'), cubit.toggleFavorite('w')]);
    expect(repository.favoriteWrites, [true, false]);
    expect(current().favoriteIds, isEmpty);
  });
  test('delayed favorite does not overwrite cart or search changes', () async {
    await cubit.loadData();
    repository.favoriteGate = Completer<void>();
    final pending = cubit.toggleFavorite('w');
    await Future<void>.delayed(Duration.zero);
    cubit.searchProducts('soft');
    repository.favoriteGate!.complete();
    await pending;
    expect(current().searchQuery, 'soft');
    expect(current().favoriteIds, contains('w'));
  });
  test('profile and cart survive a server reload', () async {
    await cubit.loadData();
    await cubit.updateProfile(name: 'Valentin', email: 'test@example.com');
    await cubit.addToCart('w');
    await cubit.loadData();
    expect(current().profileName, 'Valentin');
    expect(current().cart.items.single.productId, 'w');
  });
  test('reviews use server IDs and remain available after reload', () async {
    await cubit.loadData();
    await cubit.updateProfile(name: 'Valentin', email: 'test@example.com');
    await cubit.addReview(productId: 'w', content: 'Good', rating: 5);
    final id = current().reviewsByProduct['w']!.single.id;
    expect(id, startsWith('server-'));
    await cubit.loadData();
    expect(current().reviewsByProduct['w']!.single.id, id);
    await cubit.deleteReview(productId: 'w', reviewId: id);
    expect(current().reviewsByProduct['w'], isEmpty);
  });
  test('closing during a load does not emit on a closed Cubit', () async {
    repository.loadGate = Completer<void>();
    final pending = cubit.loadData();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    repository.loadGate!.complete();
    await pending;
  });
}
