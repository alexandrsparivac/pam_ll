import '../../domain/entities/product.dart';
import 'json_fields.dart';
import 'review_dto.dart';

class ProductDto {
  final Product entity;
  const ProductDto(this.entity);

  factory ProductDto.fromJson(Map<String, dynamic> json) {
    if (json['price'] == null) {
      throw const FormatException('Missing product price');
    }
    final actions = json['actions'] == null
        ? <String, dynamic>{}
        : jsonObject(json['actions'], 'actions');
    final rating = json['rating'] == null
        ? null
        : jsonNumber(json['rating'], 'rating');
    if (rating != null && rating > 5) {
      throw const FormatException('Invalid product rating');
    }
    final image = jsonString(
      json['mainImageUrl'] ?? json['imageUrl'],
      'imageUrl',
    );
    final availability = json['sizeAvailability'] == null
        ? <String, dynamic>{}
        : jsonObject(json['sizeAvailability'], 'sizeAvailability');
    return ProductDto(
      Product(
        id: jsonString(json['id'], 'product.id', required: true),
        name: jsonString(json['name'], 'product.name', required: true),
        price: jsonNumber(json['price'], 'product.price'),
        currency: jsonString(json['currency'], 'currency'),
        category: jsonString(json['category'], 'category'),
        imageUrl: image,
        isFavorite: jsonBool(
          json['isFavorite'] ?? actions['isFavorite'],
          'isFavorite',
        ),
        rating: rating,
        ratingCount: jsonInteger(json['ratingCount'], 'ratingCount'),
        reviewCount: jsonInteger(json['reviewCount'], 'reviewCount'),
        description: jsonString(json['description'], 'description'),
        galleryImages: json['galleryImageUrls'] == null
            ? (image.isEmpty ? [] : [image])
            : [
                for (final item in jsonList(
                  json['galleryImageUrls'],
                  'galleryImageUrls',
                ))
                  jsonString(item, 'galleryImage', required: true),
              ],
        colors: [
          for (final item in jsonList(
            json['availableColors'],
            'availableColors',
          ))
            _color(jsonObject(item, 'color')),
        ],
        sizes: [
          for (final item in jsonList(json['availableSizes'], 'availableSizes'))
            jsonString(item, 'size', required: true),
        ],
        sizeAvailability: {
          for (final item in availability.entries)
            item.key: jsonBool(item.value, 'availability'),
        },
        selectedColorId: jsonString(json['selectedColor'], 'selectedColor'),
        selectedSize: jsonString(json['selectedSize'], 'selectedSize'),
        descriptionExpanded: jsonBool(
          json['descriptionExpanded'],
          'descriptionExpanded',
          fallback: true,
        ),
        ratingBreakdown: {
          for (final item in jsonList(
            json['ratingBreakdown'],
            'ratingBreakdown',
          ))
            _stars(jsonObject(item, 'ratingBreakdown')): _percentage(
              jsonObject(item, 'ratingBreakdown'),
            ),
        },
        reviews: [
          for (final item in jsonList(json['reviews'], 'reviews'))
            ReviewDto.fromJson(jsonObject(item, 'review')).entity,
        ],
        similarProductIds: [
          for (final item in jsonList(
            json['similarProducts'],
            'similarProducts',
          ))
            jsonString(
              jsonObject(item, 'similarProduct')['id'],
              'similarProduct.id',
              required: true,
            ),
        ],
        canAddToCart: jsonBool(
          actions['canAddToCart'],
          'canAddToCart',
          fallback: true,
        ),
        addToCartLabel: jsonString(actions['addToCartLabel'], 'addToCartLabel'),
      ),
    );
  }

  static ProductColor _color(Map<String, dynamic> value) {
    final hex = jsonString(value['value'], 'color.value', required: true);
    if (!RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(hex)) {
      throw const FormatException('Invalid product color');
    }
    return ProductColor(
      id: jsonString(value['id'], 'color.id', required: true),
      name: jsonString(value['name'], 'color.name', required: true),
      hexValue: hex,
    );
  }

  static int _stars(Map<String, dynamic> value) {
    final stars = jsonInteger(value['stars'], 'stars');
    if (stars < 1 || stars > 5) {
      throw const FormatException('Invalid rating stars');
    }
    return stars;
  }

  static double _percentage(Map<String, dynamic> value) {
    final number = jsonNumber(value['percentage'], 'percentage');
    if (number > 100) throw const FormatException('Invalid percentage');
    return number / 100;
  }

  Map<String, dynamic> toJson() => {
    'id': entity.id,
    'name': entity.name,
    'price': entity.price,
    'currency': entity.currency,
    'category': entity.category,
    'imageUrl': entity.imageUrl,
    'isFavorite': entity.isFavorite,
    if (entity.rating != null) 'rating': entity.rating,
    'ratingCount': entity.ratingCount,
    'reviewCount': entity.reviewCount,
    'description': entity.description,
    'galleryImageUrls': entity.galleryImages,
    'availableColors': [
      for (final color in entity.colors)
        {'id': color.id, 'name': color.name, 'value': color.hexValue},
    ],
    'availableSizes': entity.sizes,
    'sizeAvailability': entity.sizeAvailability,
    'selectedColor': entity.selectedColorId,
    'selectedSize': entity.selectedSize,
    'descriptionExpanded': entity.descriptionExpanded,
    'ratingBreakdown': [
      for (final item in entity.ratingBreakdown.entries)
        {'stars': item.key, 'percentage': item.value * 100},
    ],
    'reviews': [
      for (final review in entity.reviews) ReviewDto(review).toJson(),
    ],
    'similarProducts': [
      for (final id in entity.similarProductIds) {'id': id},
    ],
    'actions': {
      'canAddToCart': entity.canAddToCart,
      'addToCartLabel': entity.addToCartLabel,
    },
  };
}
