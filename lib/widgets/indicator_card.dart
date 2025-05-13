// lib/widgets/indicator_card.dart (Estilo Mockup - TAMANHO ORIGINAL INTERNO)
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

  const IndicatorCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.isLoading = false,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardBgColor = Colors.black.withOpacity(0.3);
    final borderColor = accentColor.withOpacity(0.8);
    final glowColor = accentColor.withOpacity(0.5);
    final primaryTextColor = Colors.white.withOpacity(0.95);
    final secondaryTextColor = Colors.white.withOpacity(0.7);
    final errorColor = Colors.redAccent.withOpacity(0.8);

    Widget content;

    if (isLoading) {
      content = Shimmer.fromColors(
        baseColor: Colors.grey[800]!, highlightColor: Colors.grey[700]!,
        child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
            Container( height: 24, width: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container( height: 10, width: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 6),
            Container( height: 16, width: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
          ],),);
    } else {
      content = Column( mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon( hasError ? Icons.error_outline : icon, size: 24, color: hasError ? errorColor : accentColor,), // Tamanho original
          const SizedBox(height: 8), // Espaçamento original
          Text( title.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.rajdhani( fontSize: 11, fontWeight: FontWeight.bold, color: secondaryTextColor, letterSpacing: 0.5, ), maxLines: 1, overflow: TextOverflow.ellipsis,), // Tamanho original
          const SizedBox(height: 4), // Espaçamento original
          FittedBox( fit: BoxFit.scaleDown,
            child: Text( value, textAlign: TextAlign.center, style: GoogleFonts.poppins( fontSize: 20, fontWeight: FontWeight.w600, color: hasError? errorColor.withOpacity(0.8) : primaryTextColor, ), maxLines: 1,), // Tamanho original
          ),],);
    }

    return Container(
      padding: const EdgeInsets.all(12), // Padding original
      decoration: BoxDecoration( color: cardBgColor, borderRadius: BorderRadius.circular(16),
        border: Border.all( color: hasError ? errorColor.withOpacity(0.5) : borderColor, width: 1.5), // Borda original
        boxShadow: [ BoxShadow( color: hasError ? errorColor.withOpacity(0.3) : glowColor, blurRadius: 12, spreadRadius: 1, ), BoxShadow( color: Colors.black.withOpacity(0.5), blurRadius: 4, spreadRadius: -2,), ],
      ),
      child: Center(child: content),
    );
  }
}