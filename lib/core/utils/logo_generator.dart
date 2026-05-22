import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LogoGenerator {
  static Future<ui.Image> generateLogoImage(double size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    final paint = Paint()
      ..style = PaintingStyle.fill;
    
    // Fundo circular com gradiente
    final gradient = RadialGradient(
      colors: [
        const Color(0xFF1a237e),
        const Color(0xFF0d47a1),
        const Color(0xFF01579b),
      ],
    );
    
    final rect = Rect.fromLTWH(0, 0, size, size);
    paint.shader = gradient.createShader(rect);
    canvas.drawCircle(Offset(size/2, size/2), size * 0.475, paint);
    
    // Borda dourada
    paint
      ..shader = null
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.015;
    canvas.drawCircle(Offset(size/2, size/2), size * 0.475, paint);
    
    // Relógio interior
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(Offset(size/2, size/2), size * 0.35, paint);
    
    paint
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = size * 0.02;
    canvas.drawCircle(Offset(size/2, size/2), size * 0.35, paint);
    
    // Centro dourado
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFD700);
    canvas.drawCircle(Offset(size/2, size/2), size * 0.04, paint);
    
    // Ponteiros (H)
    paint
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = size * 0.04
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(
      Offset(size/2, size * 0.2),
      Offset(size/2, size * 0.8),
      paint,
    );
    
    canvas.drawLine(
      Offset(size * 0.2, size/2),
      Offset(size * 0.8, size/2),
      paint,
    );
    
    // Textos dos números
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    void drawNumber(String text, Offset position, double fontSize) {
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFFFFD700),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'Arial',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          position.dx - textPainter.width / 2,
          position.dy - textPainter.height / 2,
        ),
      );
    }
    
    drawNumber('3', Offset(size * 0.675, size * 0.35), size * 0.12);
    drawNumber('9', Offset(size * 0.3, size * 0.35), size * 0.12);
    drawNumber('6', Offset(size/2, size * 0.75), size * 0.12);
    drawNumber('12', Offset(size * 0.725, size * 0.65), size * 0.09);
    
    // Detalhes decorativos
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFD700).withOpacity(0.3);
    canvas.drawCircle(Offset(size * 0.7, size * 0.3), size * 0.03, paint);
    canvas.drawCircle(Offset(size * 0.3, size * 0.7), size * 0.03, paint);
    
    final picture = recorder.endRecording();
    return picture.toImage(size.toInt(), size.toInt());
  }
}