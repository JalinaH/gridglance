import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

class ShareCardException implements Exception {
  final String message;

  const ShareCardException(this.message);

  @override
  String toString() => message;
}

class ShareCardService {
  static Future<void> shareRepaintBoundary({
    required GlobalKey repaintBoundaryKey,
    required double devicePixelRatio,
    required String fileName,
    required String text,
    String? subject,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = repaintBoundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw const ShareCardException('Share card is not ready yet.');
    }

    final pixelRatio = (devicePixelRatio * 1.5).clamp(1.0, 3.0).toDouble();
    final image = await _captureImageWithRetries(
      renderObject,
      pixelRatio: pixelRatio,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw const ShareCardException('Could not generate image.');
    }
    final pngBytes = byteData.buffer.asUint8List();

    final sanitized = _sanitizeFileName(fileName);
    final tempDirectory = await Directory.systemTemp.createTemp(
      'gridglance_share_',
    );
    final imageFile = File('${tempDirectory.path}/$sanitized.png');
    await imageFile.writeAsBytes(pngBytes, flush: true);

    final shareRect = _sharePositionRect(renderObject);
    try {
      await Share.shareXFiles(
        [XFile(imageFile.path, mimeType: 'image/png')],
        text: text,
        subject: subject,
        sharePositionOrigin: shareRect,
      );
    } on MissingPluginException {
      throw const ShareCardException(
        'Share module unavailable. Please fully restart the app.',
      );
    } on PlatformException catch (error) {
      final message = error.message?.trim();
      throw ShareCardException(
        message == null || message.isEmpty
            ? 'Share failed (${error.code}).'
            : message,
      );
    } catch (_) {
      throw const ShareCardException('Unable to share image card right now.');
    }
  }

  static String _sanitizeFileName(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return 'gridglance-card';
    }
    return trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static Future<ui.Image> _captureImageWithRetries(
    RenderRepaintBoundary boundary, {
    required double pixelRatio,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await boundary.toImage(pixelRatio: pixelRatio);
      } catch (error) {
        lastError = error;
        await Future<void>.delayed(Duration(milliseconds: 16));
        await WidgetsBinding.instance.endOfFrame;
      }
    }
    throw ShareCardException(
      'Unable to render share image${lastError == null ? '' : ': $lastError'}',
    );
  }

  static Rect _sharePositionRect(RenderRepaintBoundary boundary) {
    final renderBox = boundary as RenderBox;
    final origin = renderBox.localToGlobal(Offset.zero);
    return origin & renderBox.size;
  }
}
