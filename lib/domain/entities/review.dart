class ReviewModel {
  final String id;
  final String name;
  final String time;
  final int rating;
  final String avatarUrl;
  final String content;
  final bool isMine;
  const ReviewModel({
    required this.id,
    required this.name,
    required this.time,
    required this.rating,
    required this.avatarUrl,
    required this.content,
    this.isMine = false,
  });
}

class NewReview {
  final String productId;
  final String author;
  final String content;
  final int rating;
  final String avatarUrl;
  const NewReview({
    required this.productId,
    required this.author,
    required this.content,
    required this.rating,
    this.avatarUrl = '',
  });
}
