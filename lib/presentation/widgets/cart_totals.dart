import 'package:flutter/material.dart';

import 'product_display.dart';

class CartTotals extends StatelessWidget {
  final Map<String, double> totals;
  const CartTotals({super.key, required this.totals});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final total in totals.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                formatPrice(total.value, total.key),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
