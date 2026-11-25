import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/gem_store_cubit.dart';
import '../cubit/gem_store_state.dart';
import '../widgets/product_display.dart';

class OrdersScreen extends StatelessWidget {
  final String? highlightId;
  const OrdersScreen({super.key, this.highlightId});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My orders'),
      actions: [
        IconButton(
          tooltip: 'Reload orders',
          onPressed: () => context.read<GemStoreCubit>().loadData(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: BlocBuilder<GemStoreCubit, GemStoreState>(
      builder: (context, state) {
        if (state is GemStoreError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.message),
                TextButton(
                  onPressed: () => context.read<GemStoreCubit>().loadData(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state is! GemStoreSuccess) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.orders.isEmpty) {
          return const Center(child: Text('You have no orders yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: state.orders.length,
          itemBuilder: (context, index) {
            final order = state.orders[index];
            final date = DateTime.tryParse(order.createdAt)?.toLocal();
            final dateLabel = date == null
                ? order.createdAt
                : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
            return Card(
              child: ExpansionTile(
                key: ValueKey(order.id),
                initiallyExpanded: order.id == highlightId,
                title: Text(
                  'Order ${order.id.substring(0, order.id.length < 8 ? order.id.length : 8)}',
                ),
                subtitle: Text(
                  '$dateLabel · ${order.status == 'cancelled' ? 'Cancelled' : 'Placed'}\n${formatPrice(order.total, order.currency)}',
                ),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  for (final item in order.items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item.quantity} × ${item.name}'),
                      subtitle: Text(
                        [
                          item.colorName,
                          item.size,
                        ].where((v) => v.isNotEmpty).join(' · '),
                      ),
                      trailing: Text(
                        formatPrice(
                          item.unitPrice * item.quantity,
                          order.currency,
                        ),
                      ),
                    ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${order.customerName}\n${order.email}\n${order.phone}\n${order.address}',
                    ),
                  ),
                  if (order.notes.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(order.notes),
                    ),
                  if (order.status == 'placed')
                    TextButton.icon(
                      onPressed: state.isUpdating
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialog) => AlertDialog(
                                  title: const Text('Cancel order?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, false),
                                      child: const Text('Keep order'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, true),
                                      child: const Text('Cancel order'),
                                    ),
                                  ],
                                ),
                              );
                              if (context.mounted && confirmed == true) {
                                await context.read<GemStoreCubit>().cancelOrder(
                                  order.id,
                                );
                              }
                            },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel order'),
                    ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
