import '../../domain/entities/commerce.dart';
import '../../domain/usecases/commerce_usecases.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/store_failure.dart';
import '../../domain/usecases/store_usecases.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/review.dart';
import 'gem_store_state.dart';

class GemStoreCubit extends Cubit<GemStoreState> {
  final GetStore _getStore;
  final SetFavorite _setFavorite;
  final AddReview _addReview;
  final DeleteReview _deleteReview;
  final ManageCart _manageCart;
  final SaveProfile _saveProfile;
  final PlaceOrder _placeOrder;
  final CancelOrder _cancelOrder;
  final void Function()? _onClose;

  GemStoreCubit({
    required this._getStore,
    required this._setFavorite,
    required this._addReview,
    required this._deleteReview,
    required this._manageCart,
    required this._saveProfile,
    required this._placeOrder,
    required this._cancelOrder,
    this._onClose,
  }) : super(const GemStoreInitial());

  int _loadVersion = 0;
  Future<void> _operations = Future<void>.value();

  Future<void> loadData() async {
    if (isClosed) return;
    final version = ++_loadVersion;
    await _operations;
    if (isClosed || version != _loadVersion) return;
    final previous = state is GemStoreSuccess ? state as GemStoreSuccess : null;
    emit(const GemStoreLoading());
    try {
      final snapshot = await _getStore();
      final homeData = snapshot.homeData;
      final allProducts = homeData.catalog;
      if (isClosed || version != _loadVersion) return;
      final favoriteIds = snapshot.favoriteIds;
      final reviewsByProduct = snapshot.reviewsByProduct;
      final initialCategory =
          homeData.categories
              .where((category) => category.isSelected)
              .map((category) => category.label)
              .firstOrNull ??
          'All';

      final selectedCategory =
          previous != null &&
              (previous.selectedCategory == 'All' ||
                  homeData.categories.any(
                    (category) => category.label == previous.selectedCategory,
                  ))
          ? previous.selectedCategory
          : initialCategory;
      _applyFilterAndSort(
        GemStoreSuccess(
          homeData: homeData,
          allProducts: allProducts,
          displayedProducts: allProducts,
          categories: homeData.categories
              .map(
                (category) => category.copyWith(
                  isSelected: category.label == selectedCategory,
                ),
              )
              .toList(),
          selectedCategory: selectedCategory,
          searchQuery: previous?.searchQuery ?? '',
          sortOption: previous?.sortOption ?? 'Default',
          favoriteIds: favoriteIds,
          reviewsByProduct: reviewsByProduct,
          profileName: snapshot.profile.name,
          profileEmail: snapshot.profile.email,
          profileAvatarUrl: previous?.profileAvatarUrl ?? '',
          cart: snapshot.cart,
          orders: snapshot.orders,
        ),
      );
    } catch (e) {
      if (isClosed || version != _loadVersion) return;
      emit(
        GemStoreError(
          message: e is StoreFailure
              ? e.message
              : 'Could not load the catalog. Try again.',
        ),
      );
    }
  }

  void searchProducts(String query) {
    if (state is! GemStoreSuccess) return;
    final currentState = state as GemStoreSuccess;
    _applyFilterAndSort(currentState, searchQuery: query);
  }

  void selectCategory(String categoryLabel) {
    if (state is! GemStoreSuccess) return;
    final currentState = state as GemStoreSuccess;
    if (categoryLabel != 'All' &&
        !currentState.categories.any(
          (category) => category.label == categoryLabel,
        )) {
      return;
    }
    final newCategory =
        categoryLabel == 'All' || currentState.selectedCategory == categoryLabel
        ? 'All'
        : categoryLabel;

    final updatedCategories = currentState.categories.map((c) {
      return c.copyWith(isSelected: c.label == newCategory);
    }).toList();

    _applyFilterAndSort(
      currentState,
      selectedCategory: newCategory,
      categories: updatedCategories,
    );
  }

  void sortProducts(String sortOption) {
    if (state is! GemStoreSuccess) return;
    _applyFilterAndSort(state as GemStoreSuccess, sortOption: sortOption);
  }

  Future<void> toggleFavorite(String productId) => _queueMutation(() async {
    if (isClosed || state is! GemStoreSuccess) return;
    final current = state as GemStoreSuccess;
    if (!current.allProducts.any((product) => product.id == productId)) return;
    final favorites = await _setFavorite(
      productId,
      !current.favoriteIds.contains(productId),
    );
    if (isClosed || state is! GemStoreSuccess) return;
    emit((state as GemStoreSuccess).copyWith(favoriteIds: favorites));
  });

  Future<bool> addToCart(
    String productId, {
    String? colorId,
    String? size,
  }) async {
    var success = false;
    await _queueMutation(() async {
      final current = state as GemStoreSuccess;
      final product = current.allProducts.firstWhere(
        (product) => product.id == productId,
      );
      final cart = await _manageCart.add(
        productId,
        colorId: colorId ?? product.selectedColorId,
        size: size ?? product.selectedSize,
      );
      _updateCart(cart);
      success = true;
    });
    return success;
  }

  Future<void> changeCartQuantity(String lineId, int quantity) =>
      _queueMutation(
        () async => _updateCart(await _manageCart.change(lineId, quantity)),
      );
  Future<void> removeFromCart(String lineId) => changeCartQuantity(lineId, 0);
  Future<void> clearCart() =>
      _queueMutation(() async => _updateCart(await _manageCart.clear()));
  void _updateCart(ShoppingCart cart) {
    if (!isClosed && state is GemStoreSuccess) {
      emit((state as GemStoreSuccess).copyWith(cart: cart));
    }
  }

  Future<void> addReview({
    required String productId,
    required String content,
    required int rating,
  }) => _queueMutation(() async {
    if (isClosed || state is! GemStoreSuccess) return;
    final current = state as GemStoreSuccess;
    final review = await _addReview(
      NewReview(
        productId: productId,
        author: current.profileName,
        content: content,
        rating: rating,
        avatarUrl: current.profileAvatarUrl,
      ),
    );
    if (isClosed || state is! GemStoreSuccess) return;
    final latest = state as GemStoreSuccess;
    emit(
      latest.copyWith(
        reviewsByProduct: {
          ...latest.reviewsByProduct,
          productId: [review, ...latest.reviewsByProduct[productId] ?? []],
        },
      ),
    );
  });

  Future<void> deleteReview({
    required String productId,
    required String reviewId,
  }) => _queueMutation(() async {
    await _deleteReview(productId, reviewId);
    if (isClosed || state is! GemStoreSuccess) return;
    final latest = state as GemStoreSuccess;
    emit(
      latest.copyWith(
        reviewsByProduct: {
          ...latest.reviewsByProduct,
          productId: [...latest.reviewsByProduct[productId] ?? []]
            ..removeWhere((review) => review.id == reviewId),
        },
      ),
    );
  });

  Future<void> _queueMutation(Future<void> Function() action) {
    final result = _operations.then((_) async {
      if (isClosed || state is! GemStoreSuccess) return;
      emit(
        (state as GemStoreSuccess).copyWith(
          isUpdating: true,
          clearOperationError: true,
        ),
      );
      try {
        await action();
      } catch (error) {
        if (!isClosed && state is GemStoreSuccess) {
          emit(
            (state as GemStoreSuccess).copyWith(
              operationError: error is StoreFailure
                  ? error.message
                  : 'Could not save the change. Try again.',
            ),
          );
        }
      } finally {
        if (!isClosed && state is GemStoreSuccess) {
          emit((state as GemStoreSuccess).copyWith(isUpdating: false));
        }
      }
    });
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  @override
  Future<void> close() async {
    _onClose?.call();
    await super.close();
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
  }) async {
    var success = false;
    await _queueMutation(() async {
      final profile = await _saveProfile(
        CustomerProfile(name: name, email: email),
      );
      if (!isClosed && state is GemStoreSuccess) {
        emit(
          (state as GemStoreSuccess).copyWith(
            profileName: profile.name,
            profileEmail: profile.email,
          ),
        );
        success = true;
      }
    });
    return success;
  }

  Future<StoreOrder?> placeOrder(OrderDraft draft) async {
    StoreOrder? order;
    await _queueMutation(() async {
      order = await _placeOrder(draft);
      if (!isClosed && state is GemStoreSuccess) {
        final current = state as GemStoreSuccess;
        emit(
          current.copyWith(
            cart: const ShoppingCart(),
            orders: [
              order!,
              ...current.orders.where((item) => item.id != order!.id),
            ],
          ),
        );
      }
    });
    return order;
  }

  Future<void> cancelOrder(String id) => _queueMutation(() async {
    final updated = await _cancelOrder(id);
    if (!isClosed && state is GemStoreSuccess) {
      final current = state as GemStoreSuccess;
      emit(
        current.copyWith(
          orders: [
            for (final order in current.orders)
              order.id == id ? updated : order,
          ],
        ),
      );
    }
  });

  void clearFilters() {
    if (state is! GemStoreSuccess) return;
    final current = state as GemStoreSuccess;
    _applyFilterAndSort(
      current,
      searchQuery: '',
      selectedCategory: 'All',
      sortOption: 'Default',
      categories: current.categories
          .map((category) => category.copyWith(isSelected: false))
          .toList(),
    );
  }

  void _applyFilterAndSort(
    GemStoreSuccess currentState, {
    String? searchQuery,
    String? selectedCategory,
    String? sortOption,
    List<CategoryModel>? categories,
  }) {
    final query = searchQuery ?? currentState.searchQuery;
    final normalizedQuery = query.trim().toLowerCase();
    final category = selectedCategory ?? currentState.selectedCategory;
    final sort = sortOption ?? currentState.sortOption;

    List<Product> filtered = currentState.allProducts.where((product) {
      final searchableText =
          '${product.name} ${product.category} ${product.description}'
              .toLowerCase();
      final matchesSearch =
          normalizedQuery.isEmpty || searchableText.contains(normalizedQuery);
      final matchesCategory = category == 'All' || product.category == category;
      return matchesSearch && matchesCategory;
    }).toList();

    // Sort
    if (sort == 'Price: Low -> High') {
      filtered.sort((a, b) => a.price.compareTo(b.price));
    } else if (sort == 'Price: High -> Low') {
      filtered.sort((a, b) => b.price.compareTo(a.price));
    } else if (sort == 'Name: A -> Z') {
      filtered.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    emit(
      currentState.copyWith(
        displayedProducts: filtered,
        searchQuery: query,
        selectedCategory: category,
        sortOption: sort,
        categories: categories ?? currentState.categories,
      ),
    );
  }
}
