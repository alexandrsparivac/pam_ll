import 'commerce.dart';
import 'category.dart';
import 'product.dart';
import 'review.dart';

class Promotion {
  final String id;
  final String title;
  final String label;
  final String imageUrl;
  final String action;
  const Promotion({
    this.id = '',
    this.title = '',
    this.label = '',
    this.imageUrl = '',
    this.action = '',
  });
}

class HomePageData {
  final String storeName;
  final List<CategoryModel> categories;
  final Promotion? heroBanner;
  final Promotion? newCollection;
  final List<Product> catalog;
  final List<Product> featureProducts;
  final List<Product> recommendedProducts;
  final List<Promotion> topCollections;
  final List<Promotion> categoryPromos;

  const HomePageData({
    required this.storeName,
    required this.categories,
    required this.catalog,
    required this.featureProducts,
    required this.recommendedProducts,
    this.heroBanner,
    this.newCollection,
    this.topCollections = const [],
    this.categoryPromos = const [],
  });
}

class StoreSnapshot {
  final HomePageData homeData;
  final Set<String> favoriteIds;
  final CustomerProfile profile;
  final ShoppingCart cart;
  final List<StoreOrder> orders;
  final Map<String, List<ReviewModel>> reviewsByProduct;
  const StoreSnapshot({
    required this.homeData,
    required this.favoriteIds,
    required this.reviewsByProduct,
    this.profile = const CustomerProfile(),
    this.cart = const ShoppingCart(),
    this.orders = const [],
  });
}
