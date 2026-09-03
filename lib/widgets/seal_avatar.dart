import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Avatar circular con un anillo dorado, al estilo de un sello o
/// insignia académica. Si hay foto (guardada como base64), la
/// muestra; si no, muestra la primera letra del nombre. Es el
/// elemento visual que identifica a cada grupo en toda la app.
class SealAvatar extends StatelessWidget {
  final String? fotoBase64;
  final String? sigla;
  final String letra;
  final double radius;
  final Widget? overlay;

  const SealAvatar({
    super.key,
    this.fotoBase64,
    this.sigla,
    required this.letra,
    this.radius = 32,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold, width: 2.5),
          ),
          child: ClipOval(
            child: (fotoBase64 != null && fotoBase64!.isNotEmpty)
                ? Image.memory(
                    base64Decode(fotoBase64!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => _texto(),
                  )
                : _texto(),
          ),
        ),
        if (overlay != null) overlay!,
      ],
    );
  }

  Widget _texto() {
    // Si hay una sigla (ej: "10A"), se usa esa. Si no, solo la
    // primera letra del nombre del grupo.
    final mostrar = (sigla != null && sigla!.isNotEmpty)
        ? sigla!
        : (letra.isEmpty ? '?' : letra[0].toUpperCase());
    final tamanoLetra = mostrar.length > 1 ? radius * 0.6 : radius * 0.85;

    return Container(
      color: AppColors.navy,
      alignment: Alignment.center,
      child: Text(
        mostrar,
        style: GoogleFonts.lora(
          fontSize: tamanoLetra,
          fontWeight: FontWeight.w700,
          color: AppColors.goldLight,
        ),
      ),
    );
  }
}
