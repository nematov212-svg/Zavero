import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/image_cache_service.dart';

/// Har safar HTTP so'rov bajarmasdan, disk/memory keshidan rasm ko'rsatuvchi
/// unumdor vidjet. Internet sekin/yo'q bo'lsa ham zudlik bilan ishlaydi.
class OptimizedImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData? fallbackIcon;
  final double iconSize;
  final Color? iconColor;
  final BorderRadius? borderRadius;
  final Widget Function()? fallbackBuilder;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon,
    this.iconSize = 28,
    this.iconColor,
    this.borderRadius,
    this.fallbackBuilder,
  });

  @override
  State<OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<OptimizedImage> {
  Uint8List? _bytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant OptimizedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    final bytes = await ImageCacheService().getImageBytes(widget.imageUrl);
    if (mounted) {
      setState(() {
        _bytes = bytes;
        _isLoading = false;
        _hasError = bytes == null || bytes.isEmpty;
      });
    }
  }

  Widget _buildFallback() {
    if (widget.fallbackBuilder != null) {
      return widget.fallbackBuilder!();
    }

    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: widget.fallbackIcon != null
          ? Icon(
              widget.fallbackIcon,
              size: widget.iconSize,
              color: widget.iconColor ?? Colors.orange.shade800,
            )
          : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: _buildFallback(),
      );
    } else if (_bytes != null && _bytes!.isNotEmpty) {
      content = Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (ctx, err, stack) => _buildFallback(),
      );
    } else if (kIsWeb && widget.imageUrl.isNotEmpty && !_hasError) {
      content = Image.network(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (ctx, err, stack) => _buildFallback(),
      );
    } else {
      content = _buildFallback();
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
