class CategoryModel {
  final String id;
  final String label;
  final String iconType;
  final bool isSelected;
  const CategoryModel({
    required this.id,
    required this.label,
    required this.iconType,
    this.isSelected = false,
  });

  CategoryModel copyWith({bool? isSelected}) => CategoryModel(
    id: id,
    label: label,
    iconType: iconType,
    isSelected: isSelected ?? this.isSelected,
  );
}
