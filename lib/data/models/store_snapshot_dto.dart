import '../../domain/entities/home_data.dart';
import '../../domain/entities/category.dart';
import 'json_fields.dart';
import 'commerce_dto.dart';
import 'product_dto.dart';
import 'review_dto.dart';

class StoreSnapshotDto {
  final StoreSnapshot entity;
  const StoreSnapshotDto(this.entity);

  factory StoreSnapshotDto.fromJson(Map<String, dynamic> response) {
    if (!response.containsKey('favoriteIds')) {
      throw const FormatException('Missing favoriteIds');
    }
    final catalog = jsonObject(response['catalog'], 'catalog');
    final home = jsonObject(catalog['homePage'], 'homePage');
    final feature = jsonList(home['featureProducts'], 'featureProducts');
    final recommended = jsonList(home['recommended'], 'recommended');
    final byId = <String, Map<String, dynamic>>{};
    for (final item in [...feature, ...recommended]) {
      final json = jsonObject(item, 'product');
      byId.putIfAbsent(
        jsonString(json['id'], 'product.id', required: true),
        () => json,
      );
    }
    final productPage = catalog['productPage'] == null
        ? <String, dynamic>{}
        : jsonObject(catalog['productPage'], 'productPage');
    if (productPage['product'] != null) {
      final detail = jsonObject(productPage['product'], 'productPage.product');
      final id = jsonString(detail['id'], 'detail.id', required: true);
      byId[id] = {...?byId[id], ...detail};
      for (final item in jsonList(
        detail['similarProducts'],
        'similarProducts',
      )) {
        final json = jsonObject(item, 'similarProduct');
        byId.putIfAbsent(
          jsonString(json['id'], 'similarProduct.id', required: true),
          () => json,
        );
      }
    }
    // The public feed groups its products under the selected category but
    // omits category on each product. Preserve explicit categories when present.
    final defaultCategory = jsonList(home['categories'], 'categories')
        .map((value) => _category(jsonObject(value, 'category')))
        .where((category) => category.isSelected)
        .firstOrNull
        ?.label;
    final products = {
      for (final item in byId.entries)
        item.key: ProductDto.fromJson({
          ...item.value,
          if (item.value['category'] == null && defaultCategory != null)
            'category': defaultCategory,
        }).entity,
    };
    final reviews = response['reviews'] == null
        ? <String, dynamic>{}
        : jsonObject(response['reviews'], 'reviews');
    final cart = CartDto.fromJson(
      jsonObject(response['cart'] ?? <String, dynamic>{}, 'cart'),
    ).entity;
    if (cart.items.any((item) => !products.containsKey(item.productId))) {
      throw const FormatException('Unknown cart product');
    }
    final favorites = {
      for (final id in jsonList(response['favoriteIds'], 'favoriteIds'))
        jsonString(id, 'favoriteId', required: true),
    };
    if (favorites.any((id) => !products.containsKey(id))) {
      throw const FormatException('Unknown favorite product');
    }
    return StoreSnapshotDto(
      StoreSnapshot(
        homeData: HomePageData(
          storeName: jsonString(home['storeName'], 'storeName'),
          categories: [
            for (final item in jsonList(home['categories'], 'categories'))
              _category(jsonObject(item, 'category')),
          ],
          heroBanner: home['heroBanner'] == null
              ? null
              : _promotion(jsonObject(home['heroBanner'], 'heroBanner')),
          newCollection: home['newCollection'] == null
              ? null
              : _promotion(jsonObject(home['newCollection'], 'newCollection')),
          catalog: products.values.toList(growable: false),
          featureProducts: [
            for (final item in feature) products[(item as Map)['id']]!,
          ],
          recommendedProducts: [
            for (final item in recommended) products[(item as Map)['id']]!,
          ],
          topCollections: [
            for (final item in jsonList(
              home['topCollections'],
              'topCollections',
            ))
              _promotion(jsonObject(item, 'collection')),
          ],
          categoryPromos: [
            for (final item in jsonList(
              home['categoryPromos'],
              'categoryPromos',
            ))
              _promotion(jsonObject(item, 'promotion')),
          ],
        ),
        favoriteIds: favorites,
        profile: ProfileDto.fromJson(
          jsonObject(response['profile'] ?? <String, dynamic>{}, 'profile'),
        ).entity,
        cart: cart,
        orders: [
          for (final item in jsonList(response['orders'], 'orders'))
            OrderDto.fromJson(jsonObject(item, 'order')).entity,
        ],
        reviewsByProduct: {
          for (final product in products.values)
            product.id: reviews.containsKey(product.id)
                ? [
                    for (final item in jsonList(
                      reviews[product.id],
                      'productReviews',
                    ))
                      ReviewDto.fromJson(jsonObject(item, 'review')).entity,
                  ]
                : product.reviews,
        },
      ),
    );
  }

  static CategoryModel _category(Map<String, dynamic> value) => CategoryModel(
    id: jsonString(value['id'], 'category.id', required: true),
    label: jsonString(
      value['name'] ?? value['label'],
      'category.name',
      required: true,
    ),
    iconType: jsonString(value['iconType'] ?? value['id'], 'iconType'),
    isSelected: jsonBool(value['selected'] ?? value['isSelected'], 'selected'),
  );
  static Promotion _promotion(Map<String, dynamic> value) => Promotion(
    id: jsonString(value['id'], 'promotion.id'),
    title: jsonString(value['title'], 'title'),
    label: jsonString(value['label'] ?? value['category'], 'label'),
    imageUrl: jsonString(value['imageUrl'], 'promotion.imageUrl'),
    action: jsonString(value['action'], 'action'),
  );
}
