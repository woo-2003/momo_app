import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 택시팟 지도용 말풍선 비트맵 마커 (시안: 골드 말풍 + 흰 글씨/아이콘).
///
/// theme surface/primary를 쓰지 않음 — 지도 핀은 시안 골드를 따름.
/// [BitmapDescriptor.bytes]의 [imagePixelRatio] 필수 (미지정 시 마커 거대화).
class TaxiMarkerIcon {
  TaxiMarkerIcon._();

  static const _assetPath = 'assets/images/taxi_marker_icon.png';
  static ui.Image? _cachedTaxiImage;

  static Future<BitmapDescriptor> create({
    required String routeLabel,
    required int currentMembers,
    required int maxMembers,
    double pixelRatio = 3,
  }) async {
    final taxi = await _loadTaxiImage();

    // 시안 골드 / 흰 텍스트
    const bubbleGold = Color(0xFFF0C24B);
    const bubbleGoldDark = Color(0xFFE0A820);
    const onBubble = Color(0xFFFFFFFF);

    // 시안처럼 컴팩트한 말풍 (너무 크면 지도가 가려짐)
    const double padH = 6;
    const double padV = 5;
    const double iconSize = 26;
    const double gap = 5;
    const double tailH = 6;
    const double radius = 12;
    const double maxTextWidth = 88;

    final routeStyle = const TextStyle(
      color: onBubble,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    final countStyle = TextStyle(
      color: onBubble.withValues(alpha: 0.92),
      fontSize: 9,
      fontWeight: FontWeight.w600,
      height: 1.1,
    );

    final routePainter = TextPainter(
      text: TextSpan(text: _ellipsis(routeLabel, 12), style: routeStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxTextWidth);

    final countPainter = TextPainter(
      text: TextSpan(
        text: '$currentMembers/$maxMembers명',
        style: countStyle,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final textBlockW = routePainter.width > countPainter.width
        ? routePainter.width
        : countPainter.width;
    final textBlockH = routePainter.height + 1 + countPainter.height;

    final bubbleW = padH + iconSize + gap + textBlockW + padH;
    final bubbleH =
        padV + (textBlockH > iconSize ? textBlockH : iconSize) + padV;
    final totalW = bubbleW + 4; // 그림자 여유
    final totalH = bubbleH + tailH + 4;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);
    canvas.translate(2, 1); // 그림자용 살짝 안쪽

    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, bubbleW, bubbleH),
      const Radius.circular(radius),
    );

    // 약한 그림자
    canvas.drawRRect(
      bubbleRect.shift(const Offset(0, 1.5)),
      Paint()..color = const Color(0x40000000),
    );

    canvas.drawRRect(bubbleRect, Paint()..color = bubbleGold);

    // 하단만 살짝 어두운 라인 (시안처럼 입체감)
    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..color = bubbleGoldDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final tipX = bubbleW / 2;
    final tipPath = Path()
      ..moveTo(tipX - 7, bubbleH - 0.5)
      ..lineTo(tipX, bubbleH + tailH)
      ..lineTo(tipX + 7, bubbleH - 0.5)
      ..close();
    canvas.drawPath(
      tipPath.shift(const Offset(0, 1)),
      Paint()..color = const Color(0x40000000),
    );
    canvas.drawPath(tipPath, Paint()..color = bubbleGold);

    final iconTop = (bubbleH - iconSize) / 2;
    // 흰 택시 실루엣 — 골드 위에서는 대비 OK. 원형 배경 없음(시안).
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(padH, iconTop, iconSize, iconSize),
      image: taxi,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    final textLeft = padH + iconSize + gap;
    final textTop = (bubbleH - textBlockH) / 2;
    routePainter.paint(canvas, Offset(textLeft, textTop));
    countPainter.paint(
      canvas,
      Offset(textLeft, textTop + routePainter.height + 1),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (totalW * pixelRatio).ceil(),
      (totalH * pixelRatio).ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }

  static Future<ui.Image> _loadTaxiImage() async {
    if (_cachedTaxiImage != null) return _cachedTaxiImage!;
    final data = await rootBundle.load(_assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _cachedTaxiImage = frame.image;
    return _cachedTaxiImage!;
  }

  static String _ellipsis(String text, int maxChars) {
    final t = text.trim();
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars - 1)}…';
  }
}
