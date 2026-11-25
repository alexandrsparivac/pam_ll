import 'product_display.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/gem_store_cubit.dart';
import '../cubit/gem_store_state.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/home_data.dart';
import '../../domain/entities/category.dart';
import '../screens/product_detail_page.dart';
import '../screens/account_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/favorites_screen.dart';
import 'empty_state_widget.dart';
import 'sort_dropdown_widget.dart';
import 'product_image_widget.dart';

Future<void> _showStoreMenu(BuildContext context) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reload from server'),
                onTap: () {
                  context.read<GemStoreCubit>().loadData();
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('All products'),
                onTap: () {
                  context.read<GemStoreCubit>().clearFilters();
                  Navigator.pop(sheetContext, 'all');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('My account'),
                onTap: () {
                  Navigator.pop(sheetContext, 'account');
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite_border),
                title: const Text('Favorites'),
                onTap: () {
                  Navigator.pop(sheetContext, 'favorites');
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('My orders'),
                onTap: () => Navigator.pop(sheetContext, 'orders'),
              ),
              ListTile(
                leading: const Icon(Icons.shopping_bag_outlined),
                title: const Text('My cart'),
                onTap: () {
                  Navigator.pop(sheetContext, 'cart');
                },
              ),
            ],
          ),
        ),
      );
    },
  );

  if (!context.mounted || action == null || action == 'all') return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => action == 'account'
          ? const AccountScreen()
          : action == 'orders'
          ? const OrdersScreen()
          : action == 'cart'
          ? const CartScreen()
          : const FavoritesScreen(),
    ),
  );
}

/* ============================================================================
 * 1. HEADER SECTION
 * ============================================================================ */
class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GemStoreCubit>().state;
    final favCount = (state is GemStoreSuccess) ? state.favoriteIds.length : 0;
    final cartCount = state is GemStoreSuccess
        ? state.cartQuantities.values.fold<int>(0, (sum, count) => sum + count)
        : 0;

    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 24,
            child: GestureDetector(
              onTap: () => _showStoreMenu(context),
              child: const CustomHamburgerIcon(),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Text(
              state is GemStoreSuccess ? state.homeData.storeName : '',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF101010),
                letterSpacing: -0.3,
              ),
            ),
          ),
          Positioned(
            right: 18,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  ),
                  child: _CartHeaderIcon(itemCount: cartCount),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                  ),
                  child: BellNotificationIcon(favoriteCount: favCount),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartHeaderIcon extends StatelessWidget {
  final int itemCount;

  const _CartHeaderIcon({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(
          Icons.shopping_bag_outlined,
          size: 23,
          color: Color(0xFF101010),
        ),
        if (itemCount > 0)
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF147C83),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$itemCount',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class CustomHamburgerIcon extends StatelessWidget {
  const CustomHamburgerIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 18, height: 1.8, color: const Color(0xFF101010)),
          const SizedBox(height: 4),
          Container(width: 13, height: 1.8, color: const Color(0xFF101010)),
          const SizedBox(height: 4),
          Container(width: 18, height: 1.8, color: const Color(0xFF101010)),
        ],
      ),
    );
  }
}

class BellNotificationIcon extends StatelessWidget {
  final int favoriteCount;

  const BellNotificationIcon({super.key, this.favoriteCount = 0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        children: [
          const Center(
            child: Icon(
              Icons.favorite_border,
              size: 22,
              color: Color(0xFF101010),
            ),
          ),
          if (favoriteCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF646B),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(
                  '$favoriteCount',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* ============================================================================
 * 2. CATEGORIES SECTION
 * ============================================================================ */
class CategoriesSection extends StatelessWidget {
  final List<CategoryModel> categories;
  final String selectedCategory;

  const CategoriesSection({
    super.key,
    required this.categories,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: categories.map((cat) {
          final label = cat.label;
          final isSelected = label == selectedCategory;
          final iconType = _parseIconType(cat.iconType);

          return CategoryItemWidget(
            label: label,
            isSelected: isSelected,
            iconType: iconType,
            onTap: () {
              context.read<GemStoreCubit>().selectCategory(label);
            },
          );
        }).toList(),
      ),
    );
  }

  CategoryIconType _parseIconType(String type) {
    switch (type) {
      case 'men':
        return CategoryIconType.men;
      case 'accessories':
        return CategoryIconType.accessories;
      case 'beauty':
        return CategoryIconType.beauty;
      case 'women':
      default:
        return CategoryIconType.women;
    }
  }
}

enum CategoryIconType { women, men, accessories, beauty }

class CategoryItemWidget extends StatelessWidget {
  final String label;
  final bool isSelected;
  final CategoryIconType iconType;
  final VoidCallback onTap;

  const CategoryItemWidget({
    super.key,
    required this.label,
    required this.isSelected,
    required this.iconType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          if (isSelected)
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF382A27), width: 1.2),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF382A27),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CustomCategoryPainterWidget(
                    iconType: iconType,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F3F4),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CustomCategoryPainterWidget(
                  iconType: iconType,
                  color: const Color(0xFF9A9AA0),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? const Color(0xFF101010)
                  : const Color(0xFF9A9AA0),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomCategoryPainterWidget extends StatelessWidget {
  final CategoryIconType iconType;
  final Color color;

  const CustomCategoryPainterWidget({
    super.key,
    required this.iconType,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _LineIconPainter(iconType: iconType, color: color),
      ),
    );
  }
}

class _LineIconPainter extends CustomPainter {
  final CategoryIconType iconType;
  final Color color;

  _LineIconPainter({required this.iconType, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (iconType) {
      case CategoryIconType.women:
        canvas.drawCircle(Offset(cx, cy - 2.5), size.width * 0.28, paint);
        canvas.drawLine(Offset(cx, cy + 3), Offset(cx, cy + 8.5), paint);
        canvas.drawLine(
          Offset(cx - 3.5, cy + 5.5),
          Offset(cx + 3.5, cy + 5.5),
          paint,
        );
        break;

      case CategoryIconType.men:
        canvas.drawCircle(Offset(cx - 2, cy + 2), size.width * 0.28, paint);
        canvas.drawLine(
          Offset(cx + 1, cy - 1),
          Offset(cx + 6.5, cy - 6.5),
          paint,
        );
        canvas.drawLine(
          Offset(cx + 6.5, cy - 6.5),
          Offset(cx + 2.5, cy - 6.5),
          paint,
        );
        canvas.drawLine(
          Offset(cx + 6.5, cy - 6.5),
          Offset(cx + 6.5, cy - 2.5),
          paint,
        );
        break;

      case CategoryIconType.accessories:
        canvas.drawCircle(Offset(cx - 4.2, cy + 0.5), 3.2, paint);
        canvas.drawCircle(Offset(cx + 4.2, cy + 0.5), 3.2, paint);
        canvas.drawLine(Offset(cx - 1, cy), Offset(cx + 1, cy), paint);
        canvas.drawLine(
          Offset(cx - 7.2, cy - 1),
          Offset(cx - 9, cy - 4),
          paint,
        );
        canvas.drawLine(
          Offset(cx + 7.2, cy - 1),
          Offset(cx + 9, cy - 4),
          paint,
        );
        break;

      case CategoryIconType.beauty:
        final fillPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 2.5, cy + 1, 5, 7.5),
            const Radius.circular(1),
          ),
          fillPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 1.5, cy - 6, 3, 6),
            const Radius.circular(1),
          ),
          paint,
        );
        canvas.drawLine(Offset(cx - 3, cy + 1), Offset(cx + 3, cy + 1), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _LineIconPainter oldDelegate) =>
      oldDelegate.iconType != iconType || oldDelegate.color != color;
}

/* ============================================================================
 * 3. HERO AUTUMN COLLECTION BANNER
 * ============================================================================ */
class FeatureProductsSection extends StatelessWidget {
  final List<Product> products;
  final Set<String> favoriteIds;
  final String currentSort;

  const FeatureProductsSection({
    super.key,
    required this.products,
    required this.favoriteIds,
    required this.currentSort,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Feature Products',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF101010),
                  ),
                ),
              ),
              Flexible(
                child: SortDropdownWidget(
                  currentSort: currentSort,
                  onSortChanged: (sort) {
                    context.read<GemStoreCubit>().sortProducts(sort);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: EmptyStateWidget(
              message: 'Try another search or clear the filters.',
              onReset: () => context.read<GemStoreCubit>().clearFilters(),
            ),
          )
        else
          SizedBox(
            height: 235,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final product = products[index];
                final isFav = favoriteIds.contains(product.id);

                return FeatureProductCard(
                  product: product,
                  isFavorite: isFav,
                  onFavoriteToggle: () {
                    context.read<GemStoreCubit>().toggleFavorite(product.id);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class FeatureProductCard extends StatelessWidget {
  final Product product;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const FeatureProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ),
        );
      },
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 130,
                  height: 175,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF8F8FA),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ProductImageWidget(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: onFavoriteToggle,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 15,
                          color: isFavorite
                              ? const Color(0xFFFF646B)
                              : const Color(0xFF8A8A91),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF202020),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              product.formattedPrice,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF25252B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================================
 * 5. BANNER HANG OUT & PARTY
 * ============================================================================ */
class RecommendedSection extends StatelessWidget {
  final List<Product> products;

  const RecommendedSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GemStoreCubit>().state;
    final favoriteIds = (state is GemStoreSuccess)
        ? state.favoriteIds
        : <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: SectionHeader(title: 'Recommended'),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 65,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final product = products[index];
              final isFav = favoriteIds.contains(product.id);

              return CompactRecommendationTile(
                product: product,
                isFavorite: isFav,
                onFavoriteToggle: () {
                  context.read<GemStoreCubit>().toggleFavorite(product.id);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F2)),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onShowAll;

  const SectionHeader({super.key, required this.title, this.onShowAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF101010),
            ),
          ),
        ),
        GestureDetector(
          onTap:
              onShowAll ??
              () => context.read<GemStoreCubit>().selectCategory('All'),
          child: Text(
            'Show all',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF9A9A9F),
            ),
          ),
        ),
      ],
    );
  }
}

class CompactRecommendationTile extends StatelessWidget {
  final Product product;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const CompactRecommendationTile({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ),
        );
      },
      child: Container(
        width: 210,
        height: 65,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 65,
                height: 65,
                child: ProductImageWidget(
                  imageUrl: product.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF202020),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.formattedPrice,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF25252B),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite
                    ? const Color(0xFFFF646B)
                    : const Color(0xFF8A8A91),
              ),
              onPressed: onFavoriteToggle,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/* ============================================================================
 * 7. TOP COLLECTION SECTION
 * ============================================================================ */
class JsonPromotionCard extends StatelessWidget {
  final Promotion? data;
  final bool hero;
  const JsonPromotionCard({super.key, required this.data, this.hero = false});

  Widget _content(BuildContext context, Promotion promotion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (promotion.label.isNotEmpty) ...[
          Text(
            promotion.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 10,
              letterSpacing: 0.7,
              color: hero ? Colors.white70 : const Color(0xFF777777),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Flexible(
          child: Text(
            promotion.title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: hero ? 22 : 18,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: hero ? Colors.white : const Color(0xFF333743),
            ),
          ),
        ),
        if (promotion.action.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: hero ? Colors.white : const Color(0xFF333333),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(promotion.title),
                content: SizedBox(
                  height: 260,
                  width: 300,
                  child: ProductImageWidget(
                    imageUrl: promotion.imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            child: Text(promotion.action),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final promotion = data;
    if (promotion == null) return const SizedBox.shrink();
    final cardHeight = MediaQuery.textScalerOf(context)
        .scale(hero ? 210 : 180)
        .clamp(180.0, 280.0)
        .toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: cardHeight,
          child: hero
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImageWidget(
                      imageUrl: promotion.imageUrl,
                      fit: BoxFit.cover,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xB3000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.65,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: _content(context, promotion),
                        ),
                      ),
                    ),
                  ],
                )
              : ColoredBox(
                  color: const Color(0xFFF8F8FA),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          child: _content(context, promotion),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: ProductImageWidget(
                          imageUrl: promotion.imageUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
