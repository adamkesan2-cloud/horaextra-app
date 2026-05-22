import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LogoWidget extends StatelessWidget {
  final double size;
  final bool showText;

  const LogoWidget({
    super.key,
    this.size = 40,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Relógio minimalista
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade800, width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Centro
              Container(
                width: size * 0.15,
                height: size * 0.15,
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
              ),
              // Ponteiro das horas
              Positioned(
                top: size * 0.2,
                child: Container(
                  width: 2,
                  height: size * 0.25,
                  color: Colors.black87,
                ),
              ),
              // Ponteiro dos minutos
              Positioned(
                right: size * 0.25,
                child: Transform.rotate(
                  angle: 0.5,
                  child: Container(
                    width: 2,
                    height: size * 0.2,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        if (showText) ...[
          const SizedBox(width: 8),
          // Texto HoraExtra
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Hora',
                  style: TextStyle(
                    fontSize: size * 0.8,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: 'Extra',
                  style: TextStyle(
                    fontSize: size * 0.8,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}