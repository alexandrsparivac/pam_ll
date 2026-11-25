import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pam_ll2_http/presentation/widgets/product_image_widget.dart';

void main() {
  testWidgets('missing image shows a neutral icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProductImageWidget(imageUrl: '')),
    );
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
