import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cubit/gem_store_cubit.dart';
import '../cubit/gem_store_state.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final state = context.read<GemStoreCubit>().state;
    _nameController = TextEditingController(
      text: state is GemStoreSuccess ? state.profileName : '',
    );
    _emailController = TextEditingController(
      text: state is GemStoreSuccess ? state.profileEmail : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) return;
    final saved = await context.read<GemStoreCubit>().updateProfile(
      name: name,
      email: email,
    );
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Account updated')));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GemStoreCubit>().state;
    if (state is! GemStoreSuccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        title: Text(
          'My account',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDEDEF)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFFECECEF),
                  foregroundColor: const Color(0xFF333333),
                  backgroundImage: state.profileAvatarUrl.isEmpty
                      ? null
                      : AssetImage(state.profileAvatarUrl),
                  child: state.profileAvatarUrl.isEmpty
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.profileName.isEmpty
                            ? 'Your profile'
                            : state.profileName,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF333333),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.profileEmail,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF777777),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Account details',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _nameController,
            label: 'Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: state.isUpdating ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save changes'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.rate_review_outlined,
                  color: Color(0xFF777777),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your name and profile photo appear automatically on your reviews.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF777777),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF777777)),
        filled: true,
        fillColor: const Color(0xFFF7F7F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEDEDEF)),
        ),
      ),
    );
  }
}
