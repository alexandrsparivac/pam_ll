import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/commerce.dart';
import '../cubit/gem_store_cubit.dart';
import '../cubit/gem_store_state.dart';
import '../widgets/cart_totals.dart';
import 'orders_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  late final String _requestId;
  bool _submitting = false;
  @override
  void initState() {
    super.initState();
    final state = context.read<GemStoreCubit>().state;
    _name = TextEditingController(
      text: state is GemStoreSuccess ? state.profileName : '',
    );
    _email = TextEditingController(
      text: state is GemStoreSuccess ? state.profileEmail : '',
    );
    final random = Random.secure();
    _requestId = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone, _address, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    final order = await context.read<GemStoreCubit>().placeOrder(
      OrderDraft(
        requestId: _requestId,
        customerName: _name.text,
        email: _email.text,
        phone: _phone.text,
        address: _address.text,
        notes: _notes.text,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (order != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrdersScreen(highlightId: order.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Checkout')),
    body: BlocBuilder<GemStoreCubit, GemStoreState>(
      builder: (context, state) {
        if (state is! GemStoreSuccess) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.cart.items.isEmpty && !_submitting) {
          return const Center(child: Text('Your cart is empty.'));
        }
        return Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _name,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter your name.' : null,
              ),
              TextFormField(
                controller: _email,
                maxLength: 254,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Enter a valid email.',
              ),
              TextFormField(
                controller: _phone,
                maxLength: 20,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (v) =>
                    RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(v?.trim() ?? '') &&
                        (v ?? '').replaceAll(RegExp(r'\D'), '').length >= 7
                    ? null
                    : 'Enter a valid phone number.',
              ),
              TextFormField(
                controller: _address,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Delivery address',
                ),
                validator: (v) => (v?.trim().length ?? 0) < 10
                    ? 'Enter the complete delivery address.'
                    : null,
              ),
              TextFormField(
                controller: _notes,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
              const SizedBox(height: 16),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.payments_outlined),
                title: Text('Payment on delivery'),
              ),
              CartTotals(totals: state.cart.totals),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: state.isUpdating || _submitting ? null : _submit,
                child: Text(_submitting ? 'Placing order...' : 'Place order'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
