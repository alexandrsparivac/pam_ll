import 'package:flutter/material.dart';

class ProductImageWidget extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  const ProductImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => SizedBox(
      width: width,
      height: height,
      child: const Center(child: Icon(Icons.image_not_supported_outlined)),
    );
    if (imageUrl.isEmpty) return placeholder();

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            _buildAnimatedImage(child, frame != null || wasSynchronouslyLoaded),
        errorBuilder: (_, _, _) => placeholder(),
      );
    }
    return Image.asset(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          _buildAnimatedImage(child, frame != null || wasSynchronouslyLoaded),
      errorBuilder: (_, _, _) => placeholder(),
    );
  }

  Widget _buildAnimatedImage(Widget child, bool loaded) {
    return AnimatedOpacity(
      opacity: loaded ? 1 : 0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: child,
    );
  }
}
