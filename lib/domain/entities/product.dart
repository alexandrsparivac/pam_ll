import 'review.dart';

class ProductColor {
  final String id;
  final String name;
  final String hexValue;
  const ProductColor({
    required this.id,
    required this.name,
    required this.hexValue,
  });
}

class Product {
  final String id;
  final String name;
  final double price;
  final String currency;
  final String category;
  final String imageUrl;
  final bool isFavorite;
  final double? rating;
  final int ratingCount;
  final int reviewCount;
  final String description;
  final List<String> galleryImages;
  final List<ProductColor> colors;
  final List<String> sizes;
  final Map<String, bool> sizeAvailability;
  final String selectedColorId;
  final String selectedSize;
  final bool descriptionExpanded;
  final Map<int, double> ratingBreakdown;
  final List<ReviewModel> reviews;
  final List<String> similarProductIds;
  final bool canAddToCart;
  final String addToCartLabel;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.currency = '',
    this.category = '',
    this.imageUrl = '',
    this.isFavorite = false,
    this.rating,
    this.ratingCount = 0,
    this.reviewCount = 0,
    this.description = '',
    this.galleryImages = const [],
    this.colors = const [],
    this.sizes = const [],
    this.sizeAvailability = const {},
    this.selectedColorId = '',
    this.selectedSize = '',
    this.descriptionExpanded = true,
    this.ratingBreakdown = const {},
    this.reviews = const [],
    this.similarProductIds = const [],
    this.canAddToCart = true,
    this.addToCartLabel = '',
  });
}
