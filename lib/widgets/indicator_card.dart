// lib/widgets/indicator_card.dart (COMPLETO E CORRIGIDO)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

class IndicatorCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final bool isLoading;
  final bool hasError;
  final Widget? actionButton; // Parâmetro para o botão, como "Compensar"

  const IndicatorCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.isLoading = false,
    this.hasError = false,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    final cardBgColor = Colors.black.withAlpha((255 * 0.3).round());
    final borderColor = accentColor.withAlpha((255 * 0.8).round());
    final glowColor = accentColor.withAlpha((255 * 0.5).round());
    final primaryTextColor = Colors.white.withAlpha((255 * 0.95).round());
    final secondaryTextColor = Colors.white.withAlpha((255 * 0.7).round());
    final errorColor = Colors.redAccent.withAlpha((255 * 0.8).round());

    const double iconSize = 20.0;
    const double titleFontSize = 10.0;
    const double valueFontSize = 16.0;

    Widget content;

    if (isLoading) {
      content = Shimmer.fromColors(
        baseColor: Colors.grey[850]!,
        highlightColor: Colors.grey[700]!,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(height: 20, width: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(height: 14, width: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
          ],
        ),
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            hasError ? Icons.error_outline : icon,
            size: iconSize,
            color: hasError ? errorColor : accentColor,
          ),
          const SizedBox(height: 4),
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: secondaryTextColor,
              letterSpacing: 0.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              hasError ? "Erro" : value,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: valueFontSize,
                fontWeight: FontWeight.w600,
                color: hasError ? errorColor.withAlpha(204) : primaryTextColor,
              ),
              maxLines: 1,
            ),
          ),
          // Se o botão de ação for fornecido, ele é adicionado aqui
          if (actionButton != null) ...[
            const SizedBox(height: 6),
            actionButton!,
          ]
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasError ? errorColor.withAlpha(127) : borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(color: hasError ? errorColor.withAlpha(51) : glowColor.withAlpha(76), blurRadius: 8, spreadRadius: 0),
        ],
      ),
      child: content,
    );
  }
}