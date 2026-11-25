import '../../domain/entities/commerce.dart';
import '../models/commerce_dto.dart';
import '../../domain/entities/home_data.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/store_failure.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/store_remote_data_source.dart';
import '../models/store_snapshot_dto.dart';
import '../models/review_dto.dart';
import '../models/json_fields.dart';

class StoreRepositoryImpl implements StoreRepository {
  final StoreRemoteDataSource _remote;
  const StoreRepositoryImpl(this._remote);

  Future<T> _decode<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FormatException {
      throw const StoreFailure(
        'The server returned data in an unexpected format.',
      );
    } on TypeError {
      throw const StoreFailure(
        'The server returned data in an unexpected format.',
      );
    }
  }

  @override
  Future<StoreSnapshot> loadStore() => _decode(
    () async => StoreSnapshotDto.fromJson(await _remote.getCatalog()).entity,
  );
  @override
  Future<Set<String>> setFavorite(String productId, bool isFavorite) =>
      _decode(() async {
        final response = await _remote.setFavorite(productId, isFavorite);
        if (!response.containsKey('favoriteIds')) {
          throw const FormatException('Missing favoriteIds');
        }
        return {
          for (final id in jsonList(response['favoriteIds'], 'favoriteIds'))
            jsonString(id, 'favoriteId', required: true),
        };
      });
  @override
  Future<ReviewModel> addReview(NewReview review) => _decode(() async {
    final response = await _remote.addReview(
      review.productId,
      NewReviewDto(review).toJson(),
    );
    return ReviewDto.fromJson(jsonObject(response['review'], 'review')).entity;
  });
  @override
  Future<void> deleteReview(String productId, String reviewId) =>
      _remote.deleteReview(productId, reviewId);
  @override
  Future<ShoppingCart> addCartItem(
    String productId,
    int quantity,
    String colorId,
    String size,
  ) => _decode(
    () async => CartDto.fromJson(
      jsonObject(
        (await _remote.addCartItem({
          'productId': productId,
          'quantity': quantity,
          'colorId': colorId,
          'size': size,
        }))['cart'],
        'cart',
      ),
    ).entity,
  );
  @override
  Future<ShoppingCart> changeCartQuantity(String lineId, int quantity) =>
      _decode(
        () async => CartDto.fromJson(
          jsonObject(
            (await _remote.changeCartQuantity(lineId, quantity))['cart'],
            'cart',
          ),
        ).entity,
      );
  @override
  Future<ShoppingCart> clearCart() => _decode(
    () async => CartDto.fromJson(
      jsonObject((await _remote.clearCart())['cart'], 'cart'),
    ).entity,
  );
  @override
  Future<CustomerProfile> saveProfile(CustomerProfile profile) => _decode(
    () async => ProfileDto.fromJson(
      jsonObject(
        (await _remote.saveProfile(ProfileDto(profile).toJson()))['profile'],
        'profile',
      ),
    ).entity,
  );
  @override
  Future<StoreOrder> placeOrder(OrderDraft draft) => _decode(
    () async => OrderDto.fromJson(
      jsonObject(
        (await _remote.placeOrder(OrderDraftDto(draft).toJson()))['order'],
        'order',
      ),
    ).entity,
  );
  @override
  Future<StoreOrder> cancelOrder(String orderId) => _decode(
    () async => OrderDto.fromJson(
      jsonObject((await _remote.cancelOrder(orderId))['order'], 'order'),
    ).entity,
  );
}
