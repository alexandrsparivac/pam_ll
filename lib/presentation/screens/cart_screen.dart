import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/gem_store_cubit.dart';
import '../cubit/gem_store_state.dart';
import '../widgets/cart_totals.dart';
import '../widgets/product_display.dart';
import '../widgets/product_image_widget.dart';
import 'checkout_screen.dart';
import 'product_detail_page.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My cart'),
      actions: [
        IconButton(
          tooltip: 'Clear cart',
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialog) => AlertDialog(
                title: const Text('Clear cart?'),
                content: const Text('All items will be removed.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            );
            if (context.mounted && confirmed == true) {
              await context.read<GemStoreCubit>().clearCart();
            }
          },
        ),
      ],
    ),
    body: BlocBuilder<GemStoreCubit, GemStoreState>(
      builder: (context, state) {
        if (state is GemStoreError) return Center(child: Text(state.message));
        if (state is! GemStoreSuccess) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.cart.items.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 64),
                SizedBox(height: 16),
                Text('Your cart is empty'),
              ],
            ),
          );
        }
        final cubit = context.read<GemStoreCubit>();
        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: state.cart.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final line = state.cart.items[index];
                  final product = state.allProducts.firstWhere(
                    (p) => p.id == line.productId,
                  );
                  final color =
                      product.colors
                          .where((c) => c.id == line.colorId)
                          .map((c) => c.name)
                          .firstOrNull ??
                      '';
                  final options = [
                    color,
                    line.size,
                  ].where((v) => v.isNotEmpty).join(' · ');
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailPage(product: product),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ProductImageWidget(
                                imageUrl: product.imageUrl,
                                width: 72,
                                height: 104,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (options.isNotEmpty)
                                  Text(
                                    options,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                Text(product.formattedPrice),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    IconButton(
                                      tooltip: 'Decrease quantity',
                                      onPressed: state.isUpdating
                                          ? null
                                          : () => cubit.changeCartQuantity(
                                              line.id,
                                              line.quantity - 1,
                                            ),
                                      icon: const Icon(Icons.remove),
                                    ),
                                    Text('${line.quantity}'),
                                    IconButton(
                                      tooltip: 'Increase quantity',
                                      onPressed:
                                          state.isUpdating ||
                                              line.quantity >= 99
                                          ? null
                                          : () => cubit.changeCartQuantity(
                                              line.id,
                                              line.quantity + 1,
                                            ),
                                      icon: const Icon(Icons.add),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove item',
                                      onPressed: state.isUpdating
                                          ? null
                                          : () => cubit.removeFromCart(line.id),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CartTotals(totals: state.cart.totals),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: state.isUpdating
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CheckoutScreen(),
                                ),
                              ),
                        child: const Text('Continue to checkout'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
