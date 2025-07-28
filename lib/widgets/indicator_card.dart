// lib/widgets/indicator_card.dart (COM CORES CORRIGIDAS)

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';

class IndicatorCard extends StatelessWidget {
  final String title;
  final Widget valueWidget;
  final IconData icon;
  final Color accentColor;
  final Widget? actionButton;
  final bool isLoading;

  const IndicatorCard({
    super.key,
    required this.title,
    required this.valueWidget,
    required this.icon,
    required this.accentColor,
    this.actionButton,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // MUDANÇA: O Card agora tem um Container com gradiente para o fundo
    return Card(
      color: Colors.transparent, // Cor do Card fica transparente
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          // O gradiente usa a accentColor para o preenchimento
          gradient: LinearGradient(
            colors: [
              accentColor.withOpacity(0.4),
              accentColor.withOpacity(0.1),
              Colors.grey[900]!.withOpacity(0.3)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: accentColor.withOpacity(0.8), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: accentColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.rajdhani(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: isLoading
                      ? const Center(child: SpinKitFadingCircle(color: Colors.white, size: 30))
                      : valueWidget,
                ),
              ),
              if (actionButton != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.center,
                  child: actionButton!,
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}