import 'dart:async';

import 'package:pam_ll2_http/domain/entities/category.dart';
import 'package:pam_ll2_http/domain/entities/commerce.dart';
import 'package:pam_ll2_http/domain/entities/home_data.dart';
import 'package:pam_ll2_http/domain/entities/product.dart';
import 'package:pam_ll2_http/domain/entities/review.dart';
import 'package:pam_ll2_http/domain/entities/store_failure.dart';
import 'package:pam_ll2_http/domain/repositories/store_repository.dart';
import 'package:pam_ll2_http/domain/usecases/store_usecases.dart';
import 'package:pam_ll2_http/domain/usecases/commerce_usecases.dart';
import 'package:pam_ll2_http/presentation/cubit/gem_store_cubit.dart';

class FakeRepository implements StoreRepository {
  bool offline = false;
  bool empty = false;
  bool failMutation = false;
  Completer<void>? loadGate;
  Completer<void>? favoriteGate;
  Set<String> favorites = {};
  ShoppingCart cart = const ShoppingCart();
  CustomerProfile profile = const CustomerProfile();
  final reviews = <String, List<ReviewModel>>{};
  final favoriteWrites = <bool>[];
  final products = const [
    Product(
      id: 'w',
      name: 'Soft Sweater',
      price: 40,
      currency: 'USD',
      category: 'Women',
    ),
    Product(
      id: 'm',
      name: 'Blue Shirt',
      price: 20,
      currency: 'USD',
      category: 'Men',
    ),
  ];
  void check() {
    if (offline || failMutation) throw const StoreFailure('Offline');
  }

  @override
  Future<StoreSnapshot> loadStore() async {
    await loadGate?.future;
    if (offline) throw const StoreFailure('Offline');
    return StoreSnapshot(
      homeData: HomePageData(
        storeName: 'Test store',
        categories: const [
          CategoryModel(
            id: 'women',
            label: 'Women',
            iconType: 'women',
            isSelected: true,
          ),
          CategoryModel(id: 'men', label: 'Men', iconType: 'men'),
        ],
        catalog: empty ? [] : products,
        featureProducts: empty ? [] : products,
        recommendedProducts: const [],
      ),
      favoriteIds: Set.from(favorites),
      reviewsByProduct: {
        for (final p in products) p.id: [...reviews[p.id] ?? []],
      },
      profile: profile,
      cart: cart,
    );
  }

  @override
  Future<Set<String>> setFavorite(String id, bool selected) async {
    await favoriteGate?.future;
    check();
    favoriteWrites.add(selected);
    selected ? favorites.add(id) : favorites.remove(id);
    return Set.from(favorites);
  }

  @override
  Future<ReviewModel> addReview(NewReview value) async {
    check();
    final review = ReviewModel(
      id: 'server-${reviews.length}',
      name: value.author,
      time: 'now',
      rating: value.rating,
      avatarUrl: '',
      content: value.content,
      isMine: true,
    );
    reviews.putIfAbsent(value.productId, () => []).add(review);
    return review;
  }

  @override
  Future<void> deleteReview(String productId, String reviewId) async {
    check();
    reviews[productId]?.removeWhere((r) => r.id == reviewId);
  }

  @override
  Future<ShoppingCart> addCartItem(
    String id,
    int quantity,
    String colorId,
    String size,
  ) async {
    check();
    cart = ShoppingCart(
      items: [
        ...cart.items,
        CartLine(
          id: 'line-${cart.items.length}',
          productId: id,
          quantity: quantity,
          colorId: colorId,
          size: size,
        ),
      ],
      totals: {'USD': 40},
    );
    return cart;
  }

  @override
  Future<ShoppingCart> changeCartQuantity(String id, int quantity) async {
    check();
    cart = ShoppingCart(
      items: [
        for (final item in cart.items)
          if (item.id != id)
            item
          else if (quantity > 0)
            CartLine(
              id: id,
              productId: item.productId,
              quantity: quantity,
              colorId: item.colorId,
              size: item.size,
            ),
      ],
    );
    return cart;
  }

  @override
  Future<ShoppingCart> clearCart() async {
    check();
    return cart = const ShoppingCart();
  }

  @override
  Future<CustomerProfile> saveProfile(CustomerProfile value) async {
    check();
    return profile = value;
  }

  @override
  Future<StoreOrder> placeOrder(OrderDraft draft) async =>
      throw const StoreFailure('Order service unavailable');
  @override
  Future<StoreOrder> cancelOrder(String id) async =>
      throw const StoreFailure('Order service unavailable');
}

GemStoreCubit cubitFor(FakeRepository repository) => GemStoreCubit(
  getStore: GetStore(repository),
  setFavorite: SetFavorite(repository),
  addReview: AddReview(repository),
  deleteReview: DeleteReview(repository),
  manageCart: ManageCart(repository),
  saveProfile: SaveProfile(repository),
  placeOrder: PlaceOrder(repository),
  cancelOrder: CancelOrder(repository),
);
