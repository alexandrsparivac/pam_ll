import '../../domain/entities/review.dart';
import 'json_fields.dart';

class ReviewDto {
  final ReviewModel entity;
  const ReviewDto(this.entity);
  factory ReviewDto.fromJson(Map<String, dynamic> json) {
    final rating = jsonInteger(json['rating'], 'review.rating');
    if (rating < 1 || rating > 5) {
      throw const FormatException('Invalid review rating');
    }
    return ReviewDto(
      ReviewModel(
        id: jsonString(json['id'], 'review.id', required: true),
        name: jsonString(
          json['author'] ?? json['name'],
          'review.author',
          required: true,
        ),
        time: jsonString(json['createdAtLabel'] ?? json['time'], 'review.time'),
        rating: rating,
        avatarUrl: jsonString(json['avatarUrl'], 'review.avatarUrl'),
        content: jsonString(
          json['text'] ?? json['content'],
          'review.content',
          required: true,
        ),
        isMine: jsonBool(json['isMine'], 'review.isMine'),
      ),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': entity.id,
    'author': entity.name,
    'createdAtLabel': entity.time,
    'rating': entity.rating,
    'avatarUrl': entity.avatarUrl,
    'text': entity.content,
    'isMine': entity.isMine,
  };
}

class NewReviewDto {
  final NewReview entity;
  const NewReviewDto(this.entity);
  Map<String, dynamic> toJson() => {
    'author': entity.author,
    'text': entity.content,
    'rating': entity.rating,
    'avatarUrl': entity.avatarUrl,
  };
}
