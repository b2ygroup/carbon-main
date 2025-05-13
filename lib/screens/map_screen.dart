// lib/screens/map_screen.dart (SIMULADO com Ícones Fixos e Ad)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carbon/widgets/ad_banner_placeholder.dart'; // Importa o placeholder de Ad

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Coordenadas x/y percentuais (0.0 a 1.0) para posicionar os ícones
    // Ajuste ou adicione mais conforme necessário para simular sua região
    final List<Map<String, double>> stationPositions = [
      {'x': 0.3, 'y': 0.3},
      {'x': 0.7, 'y': 0.25},
      {'x': 0.5, 'y': 0.6},
      {'x': 0.8, 'y': 0.75},
      {'x': 0.2, 'y': 0.8},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Eletropostos Próximos (Mockup)', style: GoogleFonts.rajdhani()),
        backgroundColor: const Color(0xFF011A27), // Cor de fundo da AppBar
      ),
      body: Column( // Column para ter o mapa e o Ad embaixo
        children: [
          Expanded( // Stack ocupa o espaço restante
            child: Stack(
              children: [
                // Fundo simulando mapa escuro
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ const Color(0xFF011A27), const Color(0xFF002233), theme.scaffoldBackgroundColor ],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.0, 0.6, 1.0]
                    ),
                  ),
                ),

                // Ícones simulando eletropostos
                LayoutBuilder( // Usa LayoutBuilder para obter o tamanho do Stack
                  builder: (context, constraints) {
                    return Stack( // Stack interna para os ícones
                      children: stationPositions.map((pos) {
                        return Positioned(
                          left: constraints.maxWidth * (pos['x'] ?? 0.0) - 15, // Centraliza o ícone (ajuste -15)
                          top: constraints.maxHeight * (pos['y'] ?? 0.0) - 15, // Centraliza o ícone (ajuste -15)
                          child: Icon(
                            Icons.ev_station,
                            color: Colors.lightGreenAccent[400],
                            size: 30,
                            shadows: [ Shadow( color: Colors.black.withOpacity(0.5), blurRadius: 5, offset: const Offset(2, 2)) ]
                          ),
                        );
                      }).toList(),
                    );
                  }
                ),

                // Você pode adicionar um ícone para a localização do usuário também
                // Ex: Positioned( bottom: 20, left: constraints.maxWidth * 0.5 - 15, child: Icon(Icons.my_location, color: Colors.blueAccent)),

              ],
            ),
          ),
          // Placeholder do Anúncio na parte inferior
          const AdBannerPlaceholder(),
        ],
      ),
    );
  }
}