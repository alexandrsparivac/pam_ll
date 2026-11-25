import '../entities/commerce.dart';
import '../entities/store_failure.dart';
import '../repositories/store_repository.dart';

class ManageCart {
  final StoreRepository _repository;
  const ManageCart(this._repository);
  Future<ShoppingCart> add(
    String productId, {
    int quantity = 1,
    String colorId = '',
    String size = '',
  }) {
    if (productId.isEmpty || quantity < 1 || quantity > 99) {
      throw const StoreFailure('Invalid cart item.');
    }
    return _repository.addCartItem(productId, quantity, colorId, size);
  }

  Future<ShoppingCart> change(String lineId, int quantity) {
    if (lineId.isEmpty || quantity < 0 || quantity > 99) {
      throw const StoreFailure('Quantity must be between 0 and 99.');
    }
    return _repository.changeCartQuantity(lineId, quantity);
  }

  Future<ShoppingCart> clear() => _repository.clearCart();
}

class SaveProfile {
  final StoreRepository _repository;
  const SaveProfile(this._repository);
  Future<CustomerProfile> call(CustomerProfile profile) {
    if (profile.name.trim().isEmpty ||
        profile.name.length > 120 ||
        profile.email.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(profile.email.trim())) {
      throw const StoreFailure('Enter a name and a valid email address.');
    }
    return _repository.saveProfile(
      CustomerProfile(name: profile.name.trim(), email: profile.email.trim()),
    );
  }
}

class PlaceOrder {
  final StoreRepository _repository;
  const PlaceOrder(this._repository);
  Future<StoreOrder> call(OrderDraft draft) {
    if (draft.requestId.length < 8 ||
        draft.customerName.trim().isEmpty ||
        draft.customerName.length > 120 ||
        draft.email.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(draft.email.trim()) ||
        !RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(draft.phone.trim()) ||
        draft.phone.replaceAll(RegExp(r'\D'), '').length < 7 ||
        draft.address.trim().length < 10 ||
        draft.address.length > 500 ||
        draft.notes.length > 1000) {
      throw const StoreFailure(
        'Enter a name, valid email and phone, and a delivery address of at least 10 characters.',
      );
    }
    return _repository.placeOrder(draft);
  }
}

class CancelOrder {
  final StoreRepository _repository;
  const CancelOrder(this._repository);
  Future<StoreOrder> call(String id) => _repository.cancelOrder(id);
}
