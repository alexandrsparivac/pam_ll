import '../widgets/product_display.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cubit/gem_store_cubit.dart';
import '../cubit/gem_store_state.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/review.dart';
import '../widgets/product_image_widget.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Product get _product {
    final state = context.read<GemStoreCubit>().state;
    return state is GemStoreSuccess
        ? state.allProducts.firstWhere(
            (product) => product.id == widget.product.id,
            orElse: () => widget.product,
          )
        : widget.product;
  }

  int selectedColorIndex = -1;
  String selectedSize = '';
  bool isDescriptionExpanded = true;
  bool isReviewsExpanded = true;
  bool isSimilarProductsExpanded = true;

  @override
  void initState() {
    super.initState();
    final colors = _product.colors;
    selectedColorIndex = colors.indexWhere(
      (color) => color.id == _product.selectedColorId,
    );
    selectedSize = _product.selectedSize;
    isDescriptionExpanded = _product.descriptionExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GemStoreCubit>().state;
    final isFav = (state is GemStoreSuccess)
        ? state.favoriteIds.contains(_product.id)
        : _product.isFavorite;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          // Scrollable main content
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Gallery Section
                _buildGallerySection(context, isFav),

                // 2. Product Sheet Overlapping Card
                _buildProductSheet(),
              ],
            ),
          ),

          // 8. Fixed Add To Cart CTA Bar
          _buildFixedCtaBar(context),
        ],
      ),
    );
  }

  /* ============================================================================
   * 1. GALLERY SECTION
   * ============================================================================ */
  Widget _buildGallerySection(BuildContext context, bool isFav) {
    final topInset = MediaQuery.paddingOf(context).top;
    final imageHeight = (MediaQuery.sizeOf(context).width * 1.05)
        .clamp(320.0, 480.0)
        .toDouble();
    final images = _product.galleryImages.isEmpty
        ? [_product.imageUrl]
        : _product.galleryImages;

    return SizedBox(
      height: topInset + imageHeight + 35,
      width: double.infinity,
      child: Stack(
        children: [
          // Fill the gallery so landscape photos also appear at product scale.
          Positioned.fill(
            top: topInset,
            bottom: 0,
            child: ColoredBox(
              color: const Color(0xFFF5F3F1),
              child: PageView(
                children: [
                  for (final image in images)
                    ProductImageWidget(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                ],
              ),
            ),
          ),

          // Top Navigation Bar (Back & Favorite Buttons)
          Positioned(
            top: topInset + 12,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 12,
                        color: Color(0xFF242424),
                      ),
                    ),
                  ),
                ),

                // Favorite Button
                GestureDetector(
                  onTap: () {
                    context.read<GemStoreCubit>().toggleFavorite(_product.id);
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isFav
                            ? const Color(0xFFFF646B)
                            : const Color(0xFF8A8A91),
                      ),
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

  /* ============================================================================
   * 2. PRODUCT SHEET (INFO, OPTIONS, REVIEWS, SIMILAR PRODUCTS)
   * ============================================================================ */
  Widget _buildProductSheet() {
    return Transform.translate(
      offset: const Offset(0, -35),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Price Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF242424),
                    ),
                  ),
                ),
                Text(
                  _product.formattedPrice,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF242424),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Rating Stars & Count
            if (_product.rating != null)
              Row(
                children: [
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < (_product.rating ?? 0).round()
                            ? Icons.star
                            : Icons.star_border,
                        size: 15,
                        color: Color(0xFF4D9183),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${_product.ratingCount})',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF8A8A91),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),

            // Divider
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 18),

            // 3. Category-specific product options
            _buildOptionsSection(),
            const SizedBox(height: 20),

            // Divider
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),

            // 4. Description Accordion
            _buildDescriptionAccordion(),
            const SizedBox(height: 12),

            // Divider
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),

            // 5. Reviews Accordion & Breakdown
            _buildReviewsAccordion(),
            const SizedBox(height: 24),

            // 6. Individual Reviews
            _buildIndividualReviews(),
            const SizedBox(height: 28),

            // Divider
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 20),

            // 7. Similar Products Section
            _buildSimilarProductsSection(),
          ],
        ),
      ),
    );
  }

  /* ============================================================================
   * 3. COLOR & SIZE OPTIONS
   * ============================================================================ */
  Widget _buildOptionsSection() {
    final colors = _product.colors;
    final sizes = _product.sizes;
    final availability = _product.sizeAvailability;
    if (colors.isEmpty && sizes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (colors.isNotEmpty) ...[
          const Text('Color'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (var index = 0; index < colors.length; index++)
                ChoiceChip(
                  label: Text(colors[index].name),
                  avatar: CircleAvatar(
                    radius: 9,
                    backgroundColor: _parseColor(colors[index].hexValue),
                  ),
                  selected: selectedColorIndex == index,
                  onSelected: (_) => setState(() => selectedColorIndex = index),
                ),
            ],
          ),
        ],
        if (sizes.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Size'),
          Wrap(
            spacing: 8,
            children: [
              for (final size in sizes)
                ChoiceChip(
                  label: Text(size),
                  selected: selectedSize == size,
                  onSelected: availability[size] == false
                      ? null
                      : (_) => setState(() => selectedSize = size),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Color? _parseColor(String value) {
    final hex = value.replaceFirst('#', '');
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null || (hex.length != 6 && hex.length != 8)) return null;
    return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
  }

  /* ============================================================================
   * 4. DESCRIPTION ACCORDION
   * ============================================================================ */
  Widget _buildDescriptionAccordion() {
    final desc = _product.description;
    if (desc.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              isDescriptionExpanded = !isDescriptionExpanded;
            });
          },
          child: SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Description',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF242424),
                  ),
                ),
                Icon(
                  isDescriptionExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: const Color(0xFF242424),
                ),
              ],
            ),
          ),
        ),
        if (isDescriptionExpanded) ...[
          const SizedBox(height: 8),
          Text(
            desc,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF777777),
              height: 1.55,
            ),
          ),
        ],
      ],
    );
  }

  /* ============================================================================
   * 5. REVIEWS ACCORDION & BREAKDOWN
   * ============================================================================ */
  Widget _buildReviewsAccordion() {
    final state = context.watch<GemStoreCubit>().state;
    final reviews = state is GemStoreSuccess
        ? (state.reviewsByProduct[_product.id] ?? const <ReviewModel>[])
        : const <ReviewModel>[];
    final localReviews = reviews.where((review) => review.isMine).toList();
    final ratingCount = _product.ratingCount + localReviews.length;
    final reviewAverage = ratingCount == 0
        ? (_product.rating ?? 0)
        : ((_product.rating ?? 0) * _product.ratingCount +
                  localReviews.fold<int>(
                    0,
                    (sum, review) => sum + review.rating,
                  )) /
              ratingCount;
    final reviewCount = _product.reviewCount + localReviews.length;
    final breakdown = _product.ratingBreakdown;
    final ratingPercentages = {
      for (var star = 5; star >= 1; star--)
        star: ratingCount == 0
            ? 0.0
            : (((breakdown[star] ?? 0) * _product.ratingCount +
                          localReviews
                              .where((review) => review.rating == star)
                              .length) /
                      ratingCount)
                  .clamp(0.0, 1.0),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              isReviewsExpanded = !isReviewsExpanded;
            });
          },
          child: SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reviews',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF242424),
                  ),
                ),
                Icon(
                  isReviewsExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: const Color(0xFF242424),
                ),
              ],
            ),
          ),
        ),
        if (isReviewsExpanded) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    reviewAverage.toStringAsFixed(1),
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF242424),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'OUT OF 5',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF8A8A91),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < reviewAverage.round()
                            ? Icons.star
                            : Icons.star_border,
                        size: 14,
                        color: Color(0xFF4D9183),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$ratingCount ratings',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF8A8A91),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (breakdown.isNotEmpty ||
              (_product.ratingCount == 0 && localReviews.isNotEmpty)) ...[
            _buildRatingBar(
              star: '5',
              factor: ratingPercentages[5]!,
              percent: '${(ratingPercentages[5]! * 100).round()}%',
            ),
            const SizedBox(height: 6),
            _buildRatingBar(
              star: '4',
              factor: ratingPercentages[4]!,
              percent: '${(ratingPercentages[4]! * 100).round()}%',
            ),
            const SizedBox(height: 6),
            _buildRatingBar(
              star: '3',
              factor: ratingPercentages[3]!,
              percent: '${(ratingPercentages[3]! * 100).round()}%',
            ),
            const SizedBox(height: 6),
            _buildRatingBar(
              star: '2',
              factor: ratingPercentages[2]!,
              percent: '${(ratingPercentages[2]! * 100).round()}%',
            ),
            const SizedBox(height: 6),
            _buildRatingBar(
              star: '1',
              factor: ratingPercentages[1]!,
              percent: '${(ratingPercentages[1]! * 100).round()}%',
            ),
          ],
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$reviewCount Reviews',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF8A8A91),
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: _showReviewDialog,
                    child: Text(
                      'WRITE A REVIEW',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4D9183),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.edit_outlined,
                    size: 12,
                    color: Color(0xFF8A8A91),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRatingBar({
    required String star,
    required double factor,
    required String percent,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Row(
            children: [
              Text(
                star,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF8A8A91),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.star, size: 9, color: Color(0xFF4D9183)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 3,
              color: const Color(0xFFEAEAEF),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: factor,
                child: Container(color: const Color(0xFF4D9183)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 28,
          child: Text(
            percent,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8A8A91),
            ),
          ),
        ),
      ],
    );
  }

  /* ============================================================================
   * 6. INDIVIDUAL REVIEWS
   * ============================================================================ */
  Widget _buildIndividualReviews() {
    final state = context.watch<GemStoreCubit>().state;
    final reviews = state is GemStoreSuccess
        ? (state.reviewsByProduct[_product.id] ?? const <ReviewModel>[])
        : const <ReviewModel>[];
    return Column(
      children: reviews
          .map(
            (review) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildReviewTile(
                review: review,
                onDelete: review.isMine
                    ? () => _confirmDeleteReview(review)
                    : null,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildReviewTile({
    required ReviewModel review,
    VoidCallback? onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 31,
              height: 31,
              child: ProductImageWidget(
                imageUrl: review.avatarUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        review.name,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF242424),
                        ),
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        onPressed: onDelete,
                        tooltip: 'Delete review',
                        icon: const Icon(Icons.delete_outline, size: 17),
                        color: const Color(0xFF9A9A9F),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      review.time,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF8A8A91),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < review.rating ? Icons.star : Icons.star_border,
                      size: 10,
                      color: const Color(0xFF4D9183),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  review.content,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF555555),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteReview(ReviewModel review) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This review will be removed from this product.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || shouldDelete != true) return;
    try {
      await context.read<GemStoreCubit>().deleteReview(
        productId: _product.id,
        reviewId: review.id,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete review. Try again.')),
      );
    }
  }

  Future<void> _showReviewDialog() async {
    final state = context.read<GemStoreCubit>().state;
    final profileName = state is GemStoreSuccess
        ? state.profileName
        : 'Your account';
    if (profileName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter your name in My account before writing a review.',
          ),
        ),
      );
      return;
    }
    final profileAvatarUrl = state is GemStoreSuccess
        ? state.profileAvatarUrl
        : '';

    final result = await showDialog<ReviewDraft>(
      context: context,
      builder: (_) => ReviewDialog(
        profileName: profileName,
        profileAvatarUrl: profileAvatarUrl,
      ),
    );
    if (!mounted || result == null) return;
    try {
      await context.read<GemStoreCubit>().addReview(
        productId: _product.id,
        content: result.content,
        rating: result.rating,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save review. Try again.')),
      );
    }
  }

  /* ============================================================================
   * 7. SIMILAR PRODUCTS SECTION
   * ============================================================================ */
  Widget _buildSimilarProductsSection() {
    final state = context.read<GemStoreCubit>().state;
    final ids = _product.similarProductIds;
    final products = state is GemStoreSuccess
        ? [
            for (final id in ids)
              ...state.allProducts.where((product) => product.id == id),
          ]
        : <Product>[];
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              isSimilarProductsExpanded = !isSimilarProductsExpanded;
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Similar Products',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF242424),
                ),
              ),
              Icon(
                isSimilarProductsExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 18,
                color: Color(0xFF242424),
              ),
            ],
          ),
        ),
        if (isSimilarProductsExpanded) const SizedBox(height: 16),
        if (isSimilarProductsExpanded && products.isNotEmpty)
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 17),
              itemBuilder: (context, index) {
                final p = products[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailPage(product: p),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 106,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 106,
                            height: 146,
                            color: const Color(0xFFF8F8FA),
                            child: ProductImageWidget(
                              imageUrl: p.imageUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF242424),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.formattedPrice,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF242424),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        else if (isSimilarProductsExpanded)
          Text(
            'No similar products in this category.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF8A8A91),
            ),
          ),
      ],
    );
  }

  /* ============================================================================
   * 8. FIXED CTA BAR (ADD TO CART)
   * ============================================================================ */
  Widget _buildFixedCtaBar(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 78,
        decoration: const BoxDecoration(
          color: Color(0xFF333333),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: InkWell(
            onTap:
                !_product.canAddToCart ||
                    (context.watch<GemStoreCubit>().state is GemStoreSuccess &&
                        (context.watch<GemStoreCubit>().state
                                as GemStoreSuccess)
                            .isUpdating)
                ? null
                : () async {
                    final sizes = _product.sizes;
                    final availability = _product.sizeAvailability;
                    if (sizes.isNotEmpty &&
                        (selectedSize.isEmpty ||
                            availability[selectedSize] == false)) {
                      return;
                    }
                    final saved = await context.read<GemStoreCubit>().addToCart(
                      _product.id,
                      colorId: selectedColorIndex < 0
                          ? ''
                          : _product.colors[selectedColorIndex].id,
                      size: selectedSize,
                    );
                    if (!context.mounted || !saved) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            '${_product.name} added to cart',
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                  },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      _product.addToCartLabel.isEmpty
                          ? 'Add to cart'
                          : _product.addToCartLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(200),
                    borderRadius: BorderRadius.circular(1.5),
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

class ReviewDraft {
  final String content;
  final int rating;

  const ReviewDraft({required this.content, required this.rating});
}

class ReviewDialog extends StatefulWidget {
  final String profileName;
  final String profileAvatarUrl;

  const ReviewDialog({
    super.key,
    required this.profileName,
    required this.profileAvatarUrl,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  late final TextEditingController _reviewController;
  var _rating = 5;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _reviewController = TextEditingController();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _publish() {
    final content = _reviewController.text.trim();
    if (content.isEmpty || content.length > 2000) {
      setState(
        () => _validationMessage = 'Enter a review of 1–2000 characters.',
      );
      return;
    }
    Navigator.pop(context, ReviewDraft(content: content, rating: _rating));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Write a review',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      size: 21,
                      color: Color(0xFF777777),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: const Color(0xFFF0F0F2),
                    foregroundColor: const Color(0xFF555555),
                    backgroundImage: widget.profileAvatarUrl.isEmpty
                        ? null
                        : AssetImage(widget.profileAvatarUrl),
                    child: widget.profileAvatarUrl.isEmpty
                        ? const Icon(Icons.person_outline, size: 22)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Posting as ${widget.profileName}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF777777),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Your rating',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(
                  5,
                  (index) => Expanded(
                    child: IconButton(
                      tooltip: '${index + 1} stars',
                      onPressed: () => setState(() => _rating = index + 1),
                      icon: Icon(
                        index < _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 30,
                        color: const Color(0xFFE3A93B),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _reviewController,
                minLines: 4,
                maxLines: 6,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Your review',
                  hintText: 'Share your experience with this product...',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: const Color(0xFFF8F8FA),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E5E8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E5E8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF333333)),
                  ),
                  errorText: _validationMessage,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF333333),
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: Color(0xFFDDDDDF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _publish,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF333333),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Publish'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
