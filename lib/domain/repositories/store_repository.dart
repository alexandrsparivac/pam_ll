import '../entities/commerce.dart';
import '../entities/home_data.dart';
import '../entities/review.dart';

abstract interface class StoreRepository {
  Future<StoreSnapshot> loadStore();
  Future<Set<String>> setFavorite(String productId, bool isFavorite);
  Future<ReviewModel> addReview(NewReview review);
  Future<void> deleteReview(String productId, String reviewId);
  Future<ShoppingCart> addCartItem(
    String productId,
    int quantity,
    String colorId,
    String size,
  );
  Future<ShoppingCart> changeCartQuantity(String lineId, int quantity);
  Future<ShoppingCart> clearCart();
  Future<CustomerProfile> saveProfile(CustomerProfile profile);
  Future<StoreOrder> placeOrder(OrderDraft draft);
  Future<StoreOrder> cancelOrder(String orderId);
}
