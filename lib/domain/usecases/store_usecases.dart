import '../entities/home_data.dart';
import '../entities/review.dart';
import '../entities/store_failure.dart';
import '../repositories/store_repository.dart';

class GetStore {
  final StoreRepository _repository;
  const GetStore(this._repository);
  Future<StoreSnapshot> call() => _repository.loadStore();
}

class SetFavorite {
  final StoreRepository _repository;
  const SetFavorite(this._repository);
  Future<Set<String>> call(String productId, bool selected) {
    if (productId.trim().isEmpty) throw const StoreFailure('Invalid product.');
    return _repository.setFavorite(productId, selected);
  }
}

class AddReview {
  final StoreRepository _repository;
  const AddReview(this._repository);
  Future<ReviewModel> call(NewReview review) {
    if (review.productId.isEmpty ||
        review.author.trim().isEmpty ||
        review.content.trim().isEmpty ||
        review.content.length > 2000 ||
        review.rating < 1 ||
        review.rating > 5) {
      throw const StoreFailure(
        'Enter your name, a review of up to 2000 characters and a rating from 1 to 5.',
      );
    }
    return _repository.addReview(
      NewReview(
        productId: review.productId,
        author: review.author.trim(),
        content: review.content.trim(),
        rating: review.rating,
        avatarUrl: review.avatarUrl,
      ),
    );
  }
}

class DeleteReview {
  final StoreRepository _repository;
  const DeleteReview(this._repository);
  Future<void> call(String productId, String reviewId) {
    if (productId.isEmpty || reviewId.isEmpty) {
      throw const StoreFailure('Invalid review.');
    }
    return _repository.deleteReview(productId, reviewId);
  }
}
