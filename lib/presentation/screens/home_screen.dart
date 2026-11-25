import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/gem_store_cubit.dart';
import '../cubit/gem_store_state.dart';
import '../widgets/home_sections.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/error_state_widget.dart';
import '../widgets/loading_state_widget.dart';
import '../widgets/search_bar_widget.dart';

class GemStoreHomePage extends StatelessWidget {
  const GemStoreHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<GemStoreCubit, GemStoreState>(
          builder: (context, state) {
            if (state is GemStoreLoading || state is GemStoreInitial) {
              return const LoadingStateWidget();
            }

            if (state is GemStoreError) {
              return ErrorStateWidget(
                message: state.message,
                onRetry: () => context.read<GemStoreCubit>().loadData(),
              );
            }

            if (state is GemStoreSuccess) {
              if (state.allProducts.isEmpty) {
                return Column(
                  children: [
                    const HeaderSection(),
                    Expanded(
                      child: EmptyStateWidget(
                        message: 'The catalog is empty. Try loading it again.',
                        resetLabel: 'Reload catalog',
                        onReset: () => context.read<GemStoreCubit>().loadData(),
                      ),
                    ),
                  ],
                );
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // 1. Header
                    const HeaderSection(),
                    const SizedBox(height: 16),

                    // Search Bar
                    SearchBarWidget(
                      currentQuery: state.searchQuery,
                      onChanged: (query) =>
                          context.read<GemStoreCubit>().searchProducts(query),
                    ),
                    const SizedBox(height: 20),

                    // 2. Categories
                    CategoriesSection(
                      categories: state.categories,
                      selectedCategory: state.selectedCategory,
                    ),
                    const SizedBox(height: 28),

                    // 3. Hero Autumn Collection Banner
                    JsonPromotionCard(
                      data: state.homeData.heroBanner,
                      hero: true,
                    ),
                    const SizedBox(height: 32),

                    // 4. Feature Products
                    FeatureProductsSection(
                      products: state.searchQuery.isNotEmpty
                          ? state.displayedProducts
                          : state.displayedProducts
                                .where(
                                  (product) =>
                                      state.homeData.featureProducts.any(
                                        (featured) => featured.id == product.id,
                                      ),
                                )
                                .toList(),
                      favoriteIds: state.favoriteIds,
                      currentSort: state.sortOption,
                    ),
                    const SizedBox(height: 32),

                    // 5. Banner HANG OUT & PARTY
                    JsonPromotionCard(data: state.homeData.newCollection),
                    const SizedBox(height: 32),

                    // 6. Recommended Section
                    RecommendedSection(
                      products: state.homeData.recommendedProducts,
                    ),
                    const SizedBox(height: 32),

                    // 7. Top Collection Section
                    ...state.homeData.topCollections.map(
                      (data) => JsonPromotionCard(data: data),
                    ),
                    const SizedBox(height: 24),

                    // 8. Category Cards (T-Shirts / Dresses)
                    ...state.homeData.categoryPromos.map(
                      (data) => JsonPromotionCard(data: data),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
