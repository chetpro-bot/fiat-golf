import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class DownloadService {
  /// RepaintBoundary key로 지정된 위젯을 PNG로 캡처하여 다운로드합니다.
  /// [repaintKey] : GlobalKey<RepaintBoundaryState> 또는 GlobalKey 가 연결된 RepaintBoundary
  /// [filename]   : 저장될 파일명 (확장자 포함)
  /// [pixelRatio] : 해상도 배율 (기본 2.0 = Retina급)
  static Future<void> captureAndDownload({
    required GlobalKey repaintKey,
    required String filename,
    double pixelRatio = 2.0,
    BuildContext? context,
  }) async {
    try {
      final RenderRepaintBoundary boundary =
          repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        _showSnack(context, '이미지 변환에 실패했습니다.');
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      _downloadBytes(pngBytes, filename);
    } catch (e) {
      debugPrint('Download error: $e');
      _showSnack(context, '다운로드 중 오류가 발생했습니다: $e');
    }
  }

  static void _downloadBytes(Uint8List bytes, String filename) {
    final blob = html.Blob([bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static void _showSnack(BuildContext? context, String message) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  /// 브라우저 캐시를 무시하고 강제로 새로고침합니다.
  static void forceWebReload() {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final currentPath = html.window.location.pathname;
      html.window.location.href = '$currentPath?v=$now';
    } catch (e) {
      debugPrint('Force reload failed: $e');
    }
  }
}
