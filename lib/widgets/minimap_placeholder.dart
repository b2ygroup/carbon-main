// lib/widgets/minimap_placeholder.dart (Simulado com Marcadores)
import 'package:flutter/material.dart';
import 'dart:math' show Random; // Para posições aleatórias

class MinimapPlaceholder extends StatelessWidget {
  const MinimapPlaceholder({super.key});

  // Função para gerar uma lista de posições relativas aleatórias (Alignment)
  List<Alignment> _generateRandomAlignments(int count) {
    final random = Random(123); // Usa seed fixa para posições consistentes
    return List.generate(count, (index) {
      // Gera valores entre -0.9 e 0.9 para x e y
      final dx = (random.nextDouble() * 1.8) - 0.9;
      final dy = (random.nextDouble() * 1.8) - 0.9;
      return Alignment(dx, dy);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = Colors.cyanAccent[400]!; // Cor dos marcadores
    final stationPositions = _generateRandomAlignments(8); // Gera 8 posições aleatórias

    return AspectRatio(
      aspectRatio: 16 / 10, // Proporção um pouco mais alta
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ Colors.grey[850]!, Colors.grey[900]!, Colors.black87 ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blueGrey[800]!.withOpacity(0.7)),
          boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3)) ]
        ),
        clipBehavior: Clip.antiAlias, // Garante que filhos fiquem dentro das bordas
        child: Stack( // Usa Stack para sobrepor marcadores no fundo
          children: [
            // Camada de "ruas" simuladas (opcional, visual)
            // Poderia ser um CustomPaint ou Containers posicionados
            // Container(color: Colors.white10, width: double.infinity, height: 1), // Exemplo linha
            // Positioned(left: 50, top: 0, bottom: 0, child: Container(color: Colors.white10, width: 1)), // Exemplo linha

            // Marcadores dos Eletropostos
            ...stationPositions.map((alignment) {
              return Align(
                alignment: alignment,
                child: Icon(
                  Icons.ev_station,
                  color: accentColor,
                  size: 22, // Tamanho do marcador
                  shadows: [ Shadow( color: Colors.black.withOpacity(0.6), blurRadius: 4, offset: const Offset(1, 1)) ],
                ),
              );
            }),

             // Ícone opcional da localização atual (exemplo)
             // Align(
             //   alignment: Alignment.center,
             //   child: Icon(Icons.my_location, color: Colors.redAccent, size: 24),
             // ),
          ],
        ),
      ),
    );
  }
}