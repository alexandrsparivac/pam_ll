class CustomerProfile {
  final String name;
  final String email;
  const CustomerProfile({this.name = '', this.email = ''});
}

class CartLine {
  final String id;
  final String productId;
  final int quantity;
  final String colorId;
  final String size;
  const CartLine({
    required this.id,
    required this.productId,
    required this.quantity,
    this.colorId = '',
    this.size = '',
  });
}

class ShoppingCart {
  final List<CartLine> items;
  final Map<String, double> totals;
  const ShoppingCart({this.items = const [], this.totals = const {}});
}

class OrderDraft {
  final String requestId;
  final String customerName;
  final String email;
  final String phone;
  final String address;
  final String notes;
  const OrderDraft({
    required this.requestId,
    required this.customerName,
    required this.email,
    required this.phone,
    required this.address,
    this.notes = '',
  });
}

class OrderItem {
  final String productId;
  final String name;
  final double unitPrice;
  final int quantity;
  final String colorName;
  final String size;
  const OrderItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.colorName = '',
    this.size = '',
  });
}

class StoreOrder {
  final String id;
  final String status;
  final String createdAt;
  final String currency;
  final double total;
  final List<OrderItem> items;
  final String customerName;
  final String email;
  final String phone;
  final String address;
  final String notes;
  const StoreOrder({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.currency,
    required this.total,
    required this.items,
    required this.customerName,
    required this.email,
    required this.phone,
    required this.address,
    this.notes = '',
  });
}
