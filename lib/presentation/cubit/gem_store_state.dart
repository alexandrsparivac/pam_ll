import '../../domain/entities/commerce.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/home_data.dart';
import '../../domain/entities/review.dart';

abstract class GemStoreState {
  const GemStoreState();
}

class GemStoreInitial extends GemStoreState {
  const GemStoreInitial();
}

class GemStoreLoading extends GemStoreState {
  const GemStoreLoading();
}

class GemStoreSuccess extends GemStoreState {
  final HomePageData homeData;
  final List<Product> allProducts;
  final List<Product> displayedProducts;
  final List<CategoryModel> categories;
  final String selectedCategory;
  final String searchQuery;
  final String sortOption;
  final Set<String> favoriteIds;
  final Map<String, List<ReviewModel>> reviewsByProduct;
  final String profileName;
  final String profileEmail;
  final String profileAvatarUrl;
  final ShoppingCart cart;
  final List<StoreOrder> orders;
  Map<String, int> get cartQuantities {
    final quantities = <String, int>{};
    for (final item in cart.items) {
      quantities.update(
        item.productId,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
    return quantities;
  }

  final bool isUpdating;
  final String? operationError;

  const GemStoreSuccess({
    required this.homeData,
    required this.allProducts,
    required this.displayedProducts,
    required this.categories,
    required this.selectedCategory,
    required this.searchQuery,
    required this.sortOption,
    required this.favoriteIds,
    required this.reviewsByProduct,
    required this.profileName,
    required this.profileEmail,
    required this.profileAvatarUrl,
    this.cart = const ShoppingCart(),
    this.orders = const [],
    this.isUpdating = false,
    this.operationError,
  });

  GemStoreSuccess copyWith({
    HomePageData? homeData,
    List<Product>? allProducts,
    List<Product>? displayedProducts,
    List<CategoryModel>? categories,
    String? selectedCategory,
    String? searchQuery,
    String? sortOption,
    Set<String>? favoriteIds,
    Map<String, List<ReviewModel>>? reviewsByProduct,
    String? profileName,
    String? profileEmail,
    String? profileAvatarUrl,
    ShoppingCart? cart,
    List<StoreOrder>? orders,
    bool? isUpdating,
    String? operationError,
    bool clearOperationError = false,
  }) {
    final updated = GemStoreSuccess(
      homeData: homeData ?? this.homeData,
      allProducts: allProducts ?? this.allProducts,
      displayedProducts: displayedProducts ?? this.displayedProducts,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      sortOption: sortOption ?? this.sortOption,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      reviewsByProduct: reviewsByProduct ?? this.reviewsByProduct,
      profileName: profileName ?? this.profileName,
      profileEmail: profileEmail ?? this.profileEmail,
      profileAvatarUrl: profileAvatarUrl ?? this.profileAvatarUrl,
      cart: cart ?? this.cart,
      orders: orders ?? this.orders,
      isUpdating: isUpdating ?? this.isUpdating,
      operationError: clearOperationError
          ? null
          : operationError ?? this.operationError,
    );
    return updated.displayedProducts.isEmpty
        ? GemStoreEmpty.fromSuccess(updated)
        : updated;
  }
}

// Empty keeps the loaded catalog and user data so filtering remains reversible.
class GemStoreEmpty extends GemStoreSuccess {
  final String message;

  GemStoreEmpty.fromSuccess(GemStoreSuccess data)
    : message = data.allProducts.isEmpty
          ? 'The catalog is empty.'
          : 'Try another search or clear the filters.',
      super(
        homeData: data.homeData,
        allProducts: data.allProducts,
        displayedProducts: data.displayedProducts,
        categories: data.categories,
        selectedCategory: data.selectedCategory,
        searchQuery: data.searchQuery,
        sortOption: data.sortOption,
        favoriteIds: data.favoriteIds,
        reviewsByProduct: data.reviewsByProduct,
        profileName: data.profileName,
        profileEmail: data.profileEmail,
        profileAvatarUrl: data.profileAvatarUrl,
        cart: data.cart,
        orders: data.orders,
        isUpdating: data.isUpdating,
        operationError: data.operationError,
      );
}

class GemStoreError extends GemStoreState {
  final String message;

  const GemStoreError({required this.message});
}
