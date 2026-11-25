import '../../domain/entities/commerce.dart';
import 'json_fields.dart';

class ProfileDto {
  final CustomerProfile entity;
  const ProfileDto(this.entity);
  factory ProfileDto.fromJson(Map<String, dynamic> json) => ProfileDto(
    CustomerProfile(
      name: jsonString(json['name'], 'profile.name'),
      email: jsonString(json['email'], 'profile.email'),
    ),
  );
  Map<String, dynamic> toJson() => {'name': entity.name, 'email': entity.email};
}

class CartDto {
  final ShoppingCart entity;
  const CartDto(this.entity);
  factory CartDto.fromJson(Map<String, dynamic> json) {
    final totals = jsonObject(
      json['totals'] ?? <String, dynamic>{},
      'cart.totals',
    );
    return CartDto(
      ShoppingCart(
        items: [
          for (final raw in jsonList(json['items'], 'cart.items'))
            _line(jsonObject(raw, 'cart.item')),
        ],
        totals: {
          for (final entry in totals.entries)
            entry.key: jsonNumber(entry.value, 'cart.total'),
        },
      ),
    );
  }
  static CartLine _line(Map<String, dynamic> json) {
    final quantity = jsonInteger(json['quantity'], 'quantity');
    if (quantity < 1 || quantity > 99) {
      throw const FormatException('Invalid cart quantity');
    }
    return CartLine(
      id: jsonString(json['id'], 'cart.id', required: true),
      productId: jsonString(json['productId'], 'productId', required: true),
      quantity: quantity,
      colorId: jsonString(json['colorId'], 'colorId'),
      size: jsonString(json['size'], 'size'),
    );
  }
}

class OrderDto {
  final StoreOrder entity;
  const OrderDto(this.entity);
  factory OrderDto.fromJson(Map<String, dynamic> json) => OrderDto(
    StoreOrder(
      id: jsonString(json['id'], 'order.id', required: true),
      status: jsonString(json['status'], 'order.status', required: true),
      createdAt: jsonString(
        json['createdAt'],
        'order.createdAt',
        required: true,
      ),
      currency: jsonString(json['currency'], 'order.currency'),
      total: jsonNumber(json['total'], 'order.total'),
      customerName: jsonString(json['customerName'], 'customerName'),
      email: jsonString(json['email'], 'email'),
      phone: jsonString(json['phone'], 'phone'),
      address: jsonString(json['address'], 'address'),
      notes: jsonString(json['notes'], 'notes'),
      items: [
        for (final raw in jsonList(json['items'], 'order.items'))
          _item(jsonObject(raw, 'order.item')),
      ],
    ),
  );
  static OrderItem _item(Map<String, dynamic> json) => OrderItem(
    productId: jsonString(json['productId'], 'productId', required: true),
    name: jsonString(json['name'], 'name', required: true),
    unitPrice: jsonNumber(json['unitPrice'], 'unitPrice'),
    quantity: jsonInteger(json['quantity'], 'quantity'),
    colorName: jsonString(json['colorName'], 'colorName'),
    size: jsonString(json['size'], 'size'),
  );
}

class OrderDraftDto {
  final OrderDraft entity;
  const OrderDraftDto(this.entity);
  Map<String, dynamic> toJson() => {
    'requestId': entity.requestId,
    'customerName': entity.customerName.trim(),
    'email': entity.email.trim(),
    'phone': entity.phone.trim(),
    'address': entity.address.trim(),
    'notes': entity.notes.trim(),
  };
}
