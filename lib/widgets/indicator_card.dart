// lib/widgets/indicator_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';

class IndicatorCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Widget? actionButton;
  final bool isLoading;

  const IndicatorCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.actionButton,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActionCard = title == 'CARTEIRA (R\$)';

    return Card(
      color: accentColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      // Adiciona uma elevação maior para o card de ação, destacando-o
      elevation: isActionCard ? 8 : 4,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white.withAlpha((255 * 0.9).round()), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.rajdhani(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (isLoading)
              const Center(child: SpinKitFadingCircle(color: Colors.white, size: 30))
            else if (isActionCard)
              // Layout de AÇÃO para o card "Comprar Moedas"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      value, // "Comprar Moedas"
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900, // Extra negrito para destaque máximo
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios, // Ícone de navegação
                    color: Colors.white,
                    size: 18,
                  )
                ],
              )
            else
              // Layout de DADOS para os outros indicadores
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      const Shadow(
                        blurRadius: 4.0,
                        color: Color.fromARGB(128, 0, 0, 0),
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                  maxLines: 1,
                ),
              ),
            if (actionButton != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: actionButton!,
              )
            ] else
              const Spacer(),
          ],
        ),
      ),
    );
  }
}