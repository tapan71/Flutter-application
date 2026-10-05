import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A universal image viewer component that supports:
/// 1. Base64 data URIs ('data:image/...')
/// 2. Network URLs ('http://' and 'https://')
/// 3. Local file paths ('/storage/...', 'C:\...', 'file://...')
/// 4. Graceful error and loading fallbacks
class AppImageView extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;

  const AppImageView({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
    this.loadingBuilder,
  });

  static bool isBase64String(String path) {
    final clean = path.trim();
    return clean.startsWith('data:image') ||
        (!clean.startsWith('http://') &&
            !clean.startsWith('https://') &&
            !clean.startsWith('/') &&
            !clean.startsWith('file:') &&
            clean.length > 50 &&
            (clean.contains('base64,') || !clean.contains(' ')));
  }

  static bool isNetworkUrl(String path) {
    final clean = path.trim();
    return clean.startsWith('http://') || clean.startsWith('https://');
  }

  static ImageProvider? getProvider(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final clean = path.trim();
    if (isBase64String(clean)) {
      try {
        final commaIdx = clean.indexOf(',');
        final data = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
        return MemoryImage(base64Decode(data.replaceAll('\n', '').replaceAll('\r', '')));
      } catch (_) {
        return null;
      }
    }
    if (isNetworkUrl(clean)) {
      return NetworkImage(clean);
    }
    if (!kIsWeb) {
      try {
        final cleanFile = clean.replaceFirst('file://', '');
        final file = io.File(cleanFile);
        if (file.existsSync()) {
          return FileImage(file);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cleanPath = imageUrl.trim();
    if (cleanPath.isEmpty) {
      return _defaultError(context, 'Empty image source', null);
    }

    // 1. Base64 Image
    if (isBase64String(cleanPath)) {
      try {
        final commaIdx = cleanPath.indexOf(',');
        final data = commaIdx != -1 ? cleanPath.substring(commaIdx + 1) : cleanPath;
        final bytes = base64Decode(data);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder ?? (c, err, st) => _defaultError(c, err, st),
        );
      } catch (err, st) {
        return _defaultError(context, err, st);
      }
    }

    // 2. Network Image
    if (isNetworkUrl(cleanPath)) {
      return Image.network(
        cleanPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder ?? (c, err, st) => _defaultError(c, err, st),
        loadingBuilder: loadingBuilder ??
            (ctx, child, progress) {
              if (progress == null) return child;
              return Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
      );
    }

    // 3. Local File Image
    if (!kIsWeb) {
      try {
        final rawPath = cleanPath.replaceFirst('file://', '');
        final file = io.File(rawPath);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: errorBuilder ?? (c, err, st) => _defaultError(c, err, st),
          );
        }
      } catch (err, st) {
        return _defaultError(context, err, st);
      }
    }

    return _defaultError(context, 'Unsupported image source', null);
  }

  Widget _defaultError(BuildContext context, Object? error, StackTrace? stack) {
    if (errorBuilder != null) {
      return errorBuilder!(context, error ?? 'Image error', stack);
    }
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 28),
      ),
    );
  }
}
