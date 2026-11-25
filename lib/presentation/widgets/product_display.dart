import '../../domain/entities/product.dart';

String formatPrice(double amount, String currency) {
  final prefix = currency == 'USD'
      ? r'$ '
      : (currency.isEmpty ? '' : '$currency ');
  return '$prefix${amount.toStringAsFixed(2)}';
}

extension ProductDisplay on Product {
  String get formattedPrice => formatPrice(price, currency);
}
